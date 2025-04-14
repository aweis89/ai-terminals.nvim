local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")
local ConfigLib = require("ai-terminals.config")
local SelectionLib = require("ai-terminals.selection")

---Setup function to merge user configuration with defaults.
---@param user_config table User-provided configuration table.
function M.setup(user_config)
	ConfigLib.config = vim.tbl_deep_extend("force", ConfigLib.config, user_config or {})
	_setup_terminal_autocmds() -- Setup autocommands for the aider terminal
end

---Setup autocommands for a terminal buffer to reload files on focus loss and cleanup on close.
---@param buf_id number The buffer ID of the terminal.
function _setup_terminal_autocmds(buf_id) -- Added buf_id parameter based on usage below
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

---Create or toggle a terminal by name with specified position
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil
	end

	position = position or "float"
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }

	if not valid_positions[position] then
		vim.notify("Invalid terminal position: " .. tostring(position), vim.log.levels.ERROR)
		position = "float" -- Default to float on invalid input
	end

	local dimensions = ConfigLib.WINDOW_DIMENSIONS[position]
	return TerminalLib.toggle(term_config.cmd, position, dimensions)
end

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.get(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, false
	end

	position = position or "float" -- Default position if not provided
	local dimensions = ConfigLib.WINDOW_DIMENSIONS[position]
	return TerminalLib.get(term_config.cmd, position, dimensions)
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

---Get the current visual selection (delegates to SelectionLib)
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[] lines Selected lines
---@return string filepath Filepath of the buffer
---@return number start_line Starting line number
---@return number end_line Ending line number
function M.get_visual_selection(bufnr)
	return SelectionLib.get_visual_selection(bufnr)
end

---Format visual selection with markdown code block and file path (delegates to SelectionLib)
---@param bufnr integer|nil
---@param opts table|nil Options for formatting (preserve_whitespace, etc.)
---@return string|nil
function M.get_visual_selection_with_header(bufnr, opts)
	return SelectionLib.get_visual_selection_with_header(bufnr, opts)
end

return M
