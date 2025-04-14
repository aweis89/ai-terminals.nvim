local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")

------------------------------------------
-- Configuration
------------------------------------------
M.config = {
	terminals = {
		goose = {
			cmd = function()
				return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)
			end,
		},
		aichat = {
			cmd = function()
				return string.format(
					"AICHAT_LIGHT_THEME=%s GEMINI_API_BASE=http://localhost:8080/v1beta aichat -r %%functions%% --session",
					tostring(vim.o.background == "light") -- Convert boolean to string "true" or "false"
				)
			end,
		},
		claude = {
			cmd = function()
				return string.format("claude config set -g theme %s && claude", vim.o.background)
			end,
		},
		aider = {
			cmd = function()
				return string.format("aider --watch-files --%s-mode", vim.o.background)
			end,
		},
	},
}

---Setup function to merge user configuration with defaults.
---@param user_config table User-provided configuration table.
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	_setup_terminal_autocmds() -- Setup autocommands for the aider terminal
end

------------------------------------------
-- Constants (kept here as they relate to config interpretation)
------------------------------------------
local WINDOW_DIMENSIONS = {
	float = { width = 0.97, height = 0.97 },
	bottom = { width = 0.5, height = 0.5 },
	top = { width = 0.5, height = 0.5 },
	left = { width = 0.5, height = 0.5 },
	right = { width = 0.5, height = 0.5 },
}

---Setup autocommands for a terminal buffer to reload files on focus loss and cleanup on close.
---@param buf_id number The buffer ID of the terminal.
function _setup_terminal_autocmds()
	local group_name = "AiTermReload"
	local augroup = vim.api.nvim_create_augroup(group_name, { clear = true })

	local function check_files()
		vim.schedule(function() -- Defer execution slightly
			vim.notify("Checking files for changes...", vim.log.levels.INFO)
			for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
				local bnr = bufinfo.bufnr
				-- Check if buffer is valid, loaded, modifiable, and not the terminal buffer itself
				if vim.api.nvim_buf_is_valid(bnr) and bufinfo.loaded and vim.bo[bnr].modifiable and bnr ~= buf_id then
					-- Use pcall to handle potential errors during checktime
					pcall(vim.cmd, bnr .. "checktime")
				end
			end
		end)
	end

	local pattern = "term://*ai-terminals.nvim*"

	-- Autocommand to reload buffers when focus leaves the terminal buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		pattern = pattern,
		desc = "Reload buffers when AI terminal loses focus",
		callback = check_files,
	})

	-- Autocommand to run backup when entering the terminal window
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = augroup,
		pattern = pattern,
		desc = "Run backup sync when entering AI terminal window",
		callback = function()
			local cwd = vim.fn.getcwd()
			local cwd_name = vim.fn.fnamemodify(cwd, ":t")
			local backup_dir = DiffLib.BASE_COPY_DIR .. cwd_name

			-- Ensure the base directory exists
			vim.fn.mkdir(DiffLib.BASE_COPY_DIR, "p")

			local rsync_args = { "rsync", "-av", "--delete" }
			for _, pattern in ipairs(DiffLib.DIFF_IGNORE_PATTERNS) do
				table.insert(rsync_args, "--exclude")
				table.insert(rsync_args, pattern)
			end
			table.insert(rsync_args, cwd .. "/") -- Add trailing slash to source for rsync behavior
			table.insert(rsync_args, backup_dir)

			vim.notify("Running backup sync...", vim.log.levels.INFO)
			local job_id = vim.fn.jobstart(rsync_args, {
				on_exit = function(_, exit_code)
					if exit_code == 0 then
						vim.schedule(function()
							vim.notify("Backup sync completed successfully.", vim.log.levels.INFO)
						end)
					else
						vim.schedule(function()
							vim.notify(
								string.format("Backup sync failed with exit code %d.", exit_code),
								vim.log.levels.ERROR
							)
						end)
					end
				end,
				stdout_buffered = true, -- Capture stdout if needed for debugging
				stderr_buffered = true, -- Capture stderr
				on_stderr = function(_, data)
					if data and #data > 0 and data[1] ~= "" then -- Check for actual error messages
						local err_msg = table.concat(data, "\n")
						vim.schedule(function()
							vim.notify("Backup sync error: " .. err_msg, vim.log.levels.ERROR)
						end)
					end
				end,
			})

			if not job_id or job_id == 0 or job_id == -1 then
				vim.notify("Failed to start backup sync job.", vim.log.levels.ERROR)
			end
		end,
	})
end

------------------------------------------
-- Terminal Core Functions
------------------------------------------
---Get the current visual selection
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[] lines Selected lines
---@return string filepath Filepath of the buffer
---@return number start_line Starting line number
---@return number end_line Ending line number
function M.get_visual_selection(bufnr)
	local api = vim.api
	local esc_feedkey = api.nvim_replace_termcodes("<ESC>", true, false, true)
	bufnr = bufnr or 0

	api.nvim_feedkeys(esc_feedkey, "n", true)
	api.nvim_feedkeys("gv", "x", false)
	api.nvim_feedkeys(esc_feedkey, "n", true)

	local end_line, end_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))
	local start_line, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
	local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	-- get whole buffer if there is no current/previous visual selection
	if start_line == 0 then
		lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
		start_line = 1
		start_col = 0
		end_line = #lines
		end_col = #lines[#lines]
	end

	-- use 1-based indexing and handle selections made in visual line mode
	start_col = start_col + 1
	end_col = math.min(end_col, #lines[#lines] - 1) + 1

	-- shorten first/last line according to start_col/end_col
	lines[#lines] = lines[#lines]:sub(1, end_col)
	lines[1] = lines[1]:sub(start_col)

	local filepath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")

	return lines, filepath, start_line, end_line
end

---Format visual selection with markdown code block and file path
---@param bufnr integer|nil
---@param opts table|nil Options for formatting (preserve_whitespace, etc.)
---@return string|nil
function M.get_visual_selection_with_header(bufnr, opts)
	opts = opts or {}
	bufnr = bufnr or 0
	local lines, path = M.get_visual_selection(bufnr)

	if not lines or #lines == 0 then
		vim.notify("No text selected", vim.log.levels.WARN)
		return nil
	end

	local slines = table.concat(lines, "\n")

	local filetype = vim.bo[bufnr].filetype or ""
	slines = "```" .. filetype .. "\n" .. slines .. "\n```\n"
	return string.format("\n# Path: %s\n%s\n", path, slines)
end

---Create or toggle a terminal by name with specified position
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	local term_config = M.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil
	end

	-- Resolve command: Execute if function, otherwise use as string
	local cmd
	if type(term_config.cmd) == "function" then
		cmd = term_config.cmd()
	elseif type(term_config.cmd) == "string" then
		cmd = term_config.cmd
	else
		vim.notify("Invalid 'cmd' type for terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end

	position = position or "float"
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }

	if not valid_positions[position] then
		vim.notify("Invalid terminal position: " .. tostring(position), vim.log.levels.ERROR)
		position = "float" -- Default to float on invalid input
	end

	local dimensions = WINDOW_DIMENSIONS[position]

	local term = Snacks.terminal.toggle(cmd, {
		env = { id = cmd },
		win = {
			position = position,
			height = dimensions.height,
			width = dimensions.width,
		},
	})

	return TerminalLib.toggle(cmd, position, dimensions)
end

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.get(terminal_name, position)
	local term_config = M.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, false
	end

	-- Resolve command: Execute if function, otherwise use as string
	local cmd
	if type(term_config.cmd) == "function" then
		cmd = term_config.cmd()
	elseif type(term_config.cmd) == "string" then
		cmd = term_config.cmd
	else
		vim.notify("Invalid 'cmd' type for terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil, false
	end

	position = position or "float" -- Default position if not provided
	local dimensions = WINDOW_DIMENSIONS[position]
	-- Delegate to TerminalLib
	return TerminalLib.get(cmd, position, dimensions)
end

---Compare current directory with its backup and open differing files (delegates to DiffLib)
---@return nil
function M.diff_changes()
	DiffLib.diff_changes()
end

---Close and wipe out any buffers from the diff directory (delegates to DiffLib)
---@return nil
function M.close_diff()
	DiffLib.close_diff()
end

---Send text to a terminal
---@param text string The text to send
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send(text, opts)
	TerminalLib.send(text, opts)
end

---Get formatted diagnostics (delegates to DiagnosticsLib)
---@return string|nil
function M.diagnostics()
	return DiagnosticsLib.get_formatted()
end

---Format diagnostics simply (delegates to DiagnosticsLib)
---@param diagnostics table A list of diagnostic items from vim.diagnostic.get()
---@return string[] A list of formatted diagnostic strings
function M.diag_format(diagnostics)
	return DiagnosticsLib.format_simple(diagnostics)
end

---Add a comment above the current line based on user input (delegates to AiderLib)
---@param prefix string The prefix to add before the user's comment text
---@return nil
function M.aider_comment(prefix)
	AiderLib.comment(M, prefix)
end

-- Helper function to send commands to the aider terminal (delegates to AiderLib)
---@param files string[] List of file paths to add to aider
---@param opts? { read_only?: boolean } Options for the command
function M.add_files_to_aider(files, opts)
	AiderLib.add_files(M, files, opts)
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param cmd string|nil The shell command to execute.
---@return nil
function M.run_command_and_send_output(cmd)
	TerminalLib.run_command_and_send_output(cmd)
end

return M
