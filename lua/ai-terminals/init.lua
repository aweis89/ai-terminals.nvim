local M = {}

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
-- Ignore Patterns for Diff
------------------------------------------
local DIFF_IGNORE_PATTERNS = {
	"*.log",
	"*.swp",
	"*.swo",
	"*.pyc",
	"__pycache__",
	"node_modules",
	".git",
	".DS_Store",
	"vendor",
	"*.tmp",
	"tmp",
	".cache",
	"dist",
	"build",
	".vscode",
	".aider*",
	"cache.db*",
}

------------------------------------------
-- Constants
------------------------------------------
local WINDOW_DIMENSIONS = {
	float = { width = 0.97, height = 0.97 },
	bottom = { width = 0.5, height = 0.5 },
	top = { width = 0.5, height = 0.5 },
	left = { width = 0.5, height = 0.5 },
	right = { width = 0.5, height = 0.5 },
}

local BASE_COPY_DIR = vim.fn.stdpath("cache") .. "/ai_terminals_diff/"

---Setup autocommands for a terminal buffer to reload files on focus loss and cleanup on close.
---@param buf_id number The buffer ID of the terminal.
function _setup_terminal_autocmds()
	local group_name = "AiTermReload_" .. buf_id
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
			local backup_dir = BASE_COPY_DIR .. cwd_name

			-- Ensure the base directory exists
			vim.fn.mkdir(BASE_COPY_DIR, "p")

			local rsync_args = { "rsync", "-av", "--delete" }
			for _, pattern in ipairs(DIFF_IGNORE_PATTERNS) do
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

	return term
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
	-- Use the command string as the identifier for Snacks.terminal.get
	return Snacks.terminal.get(cmd, {
		env = { id = cmd }, -- Use cmd as the identifier
		win = {
			position = position, -- Pass position for potential window matching/creation logic in Snacks
			height = dimensions.height,
			width = dimensions.width,
		},
	})
end

---Compare current directory with its backup in ~/tmp and open differing files
---@return nil
function M.diff_changes()
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local tmp_dir = BASE_COPY_DIR .. cwd_name

	-- Build exclude patterns for diff command
	local exclude_patterns = {}
	for _, pattern in ipairs(DIFF_IGNORE_PATTERNS) do
		table.insert(exclude_patterns, string.format("--exclude='%s'", pattern))
	end
	local exclude_str = table.concat(exclude_patterns, " ")

	-- Get list of files that differ
	local diff_cmd = string.format("diff -rq %s %s %s", exclude_str, cwd, tmp_dir)
	local diff_output = vim.fn.system(diff_cmd)

	if vim.v.shell_error == 0 then
		vim.notify("No differences found", vim.log.levels.INFO)
		return
	end

	-- Process diff output and extract file paths
	local diff_files = {}
	for line in vim.gsplit(diff_output, "\n") do
		if line:match("^Files .* and .* differ$") then
			local orig_file = line:match("Files (.-) and")
			local tmp_file = line:match("and (.-) differ")
			table.insert(diff_files, { orig = orig_file, tmp = tmp_file })
		end
	end

	-- Close all current windows
	vim.cmd("tabonly")
	vim.cmd("only")

	local orig_files_to_notify = {}
	-- Open each differing file in a split view
	for i, files in ipairs(diff_files) do
		table.insert(orig_files_to_notify, vim.fn.fnamemodify(files.orig, ":t")) -- Add only the filename

		if i > 1 then
			-- Create a new tab for each additional file pair
			vim.cmd("tabnew")
		end

		vim.cmd("edit " .. vim.fn.fnameescape(files.orig))
		vim.cmd("diffthis")
		vim.cmd("vsplit " .. vim.fn.fnameescape(files.tmp))
		vim.cmd("diffthis")
	end

	-- Notify about all diffed files at once
	if #orig_files_to_notify > 0 then
		local notification_lines = { "Opened diffs for:" }
		for _, filename in ipairs(orig_files_to_notify) do
			table.insert(notification_lines, "- " .. filename)
		end
		vim.notify(table.concat(notification_lines, "\n"), vim.log.levels.INFO)
	end
end

---Close and wipe out any buffers whose file path is inside the BASE_COPY_DIR.
---@return nil
function M.close_diff()
	local base_copy_dir_abs = vim.fn.fnamemodify(BASE_COPY_DIR, ":p") -- Get absolute path
	local buffers_to_wipe = {}

	for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		local bufname = bufinfo.name
		if bufname and bufname ~= "" then
			local bufname_abs = vim.fn.fnamemodify(bufname, ":p") -- Get absolute path of buffer
			-- Check if the buffer's absolute path starts with the base copy directory's absolute path
			if bufname_abs:find(base_copy_dir_abs, 1, true) == 1 then
				table.insert(buffers_to_wipe, bufinfo.bufnr)
			end
		end
	end

	if #buffers_to_wipe > 0 then
		local wiped_count = 0
		for _, bufnr in ipairs(buffers_to_wipe) do
			-- Check if buffer still exists before trying to wipe
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.cmd(bufnr .. "bwipeout!")
				wiped_count = wiped_count + 1
			end
		end
		vim.notify(string.format("Wiped out %d buffer(s) from the diff directory.", wiped_count), vim.log.levels.DEBUG)
	else
		vim.notify("No diff buffers found to close.", vim.log.levels.DEBUG)
	end
end

---Send text to a terminal
---@param text string The text to send
---@param opts {term: snacks.win?}|nil
---@return nil
function M.send(text, opts)
	local job_id = vim.b.terminal_job_id
	if opts and opts.term then
		job_id = vim.b[opts.term.buf].terminal_job_id
	end
	if not job_id then
		vim.notify("No terminal job id found", vim.log.levels.ERROR)
	end
	if text:find("\n") then
		text = M.multiline(text)
	end
	local ok, err = pcall(vim.fn.chansend, job_id, text)
	if not ok then
		vim.notify("Failed to send selection: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.api.nvim_feedkeys("i", "n", false)
end

-- Helper function to map severity enum to string
local function get_severity_str(severity)
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}
	return severity_map[severity] or "UNKNOWN"
end

---@return string|nil
-- Enhance diagnostics output for better LLM clarity.
-- Shows full visual selection context if run in visual mode, otherwise shows fixed context.
function M.diagnostics()
	local diagnostics = {}
	local bufnr = vim.api.nvim_get_current_buf() -- Use current buffer explicitly
	local file = vim.api.nvim_buf_get_name(bufnr)
	local filetype = vim.bo[bufnr].filetype or "" -- Get filetype for code blocks

	local mode = vim.api.nvim_get_mode().mode
	local is_visual_selection = false
	local selection_start_line = 1 -- 1-based
	local selection_end_line = vim.api.nvim_buf_line_count(bufnr) -- 1-based, inclusive

	if mode:match("^[vV\22]") then -- visual, visual-line, or visual-block mode
		local start_mark = vim.api.nvim_buf_get_mark(bufnr, "<")
		local end_mark = vim.api.nvim_buf_get_mark(bufnr, ">")
		-- Ensure marks are valid and start <= end
		if start_mark and end_mark and start_mark[1] > 0 and end_mark[1] > 0 then
			selection_start_line = math.min(start_mark[1], end_mark[1])
			selection_end_line = math.max(start_mark[1], end_mark[1])
			is_visual_selection = true
			-- vim.diagnostic.get uses 0-based line numbers, marks are 1-based
			-- Filter diagnostics to only include those within the visual selection
			local all_diags = vim.diagnostic.get(bufnr)
			for _, diag in ipairs(all_diags) do
				if diag.lnum >= selection_start_line - 1 and diag.lnum < selection_end_line then
					table.insert(diagnostics, diag)
				end
			end
		else
			-- Fallback if visual selection is invalid (e.g., just entered visual mode)
			diagnostics = vim.diagnostic.get(bufnr)
		end
	else
		diagnostics = vim.diagnostic.get(bufnr)
	end

	local formatted_output = {}
	local header_message

	if is_visual_selection then
		header_message = string.format(
			"Diagnostics for selection (Lines %d-%d) in file: %q\n",
			selection_start_line,
			selection_end_line,
			file
		)
	else
		header_message = string.format("Diagnostics for file: %q\n", file)
	end

	if #diagnostics == 0 then
		return nil
	end

	-- Sort diagnostics by line number, then column
	table.sort(diagnostics, function(a, b)
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		return a.col < b.col
	end)

	local context_before = 3 -- Fixed context lines (if not visual selection)
	local context_after = 3 -- Fixed context lines (if not visual selection)

	for i, diag in ipairs(diagnostics) do
		table.insert(formatted_output, string.format("--- DIAGNOSTIC %d ---", i))

		-- Neovim diagnostics use 0-based indexing
		local line_nr_1based = diag.lnum + 1
		local col_nr_1based = diag.col + 1
		local severity_str = get_severity_str(diag.severity)
		local message = diag.message:gsub("\n", " ") -- Ensure message is single line
		local source = diag.source or "unknown"

		-- Add diagnostic details
		table.insert(formatted_output, string.format("Severity: %s", severity_str))
		table.insert(formatted_output, string.format("Source:   %s", source))
		table.insert(formatted_output, string.format("Line:     %d", line_nr_1based))
		table.insert(formatted_output, string.format("Column:   %d", col_nr_1based))
		table.insert(formatted_output, string.format("Message:  %s", message))

		-- Fetch context lines based on mode
		local start_context_lnum_0based
		local end_context_lnum_exclusive -- nvim_buf_get_lines end index is exclusive

		if is_visual_selection then
			-- Use the entire visual selection range as context
			start_context_lnum_0based = selection_start_line - 1
			end_context_lnum_exclusive = selection_end_line -- Use the 1-based end line directly
		else
			-- Use fixed context around the diagnostic line
			start_context_lnum_0based = math.max(0, diag.lnum - context_before)
			end_context_lnum_exclusive = math.min(vim.api.nvim_buf_line_count(bufnr), diag.lnum + 1 + context_after)
		end

		-- Check if context range is valid before fetching
		if start_context_lnum_0based >= end_context_lnum_exclusive then
			table.insert(formatted_output, "\nCode Context:\n[Could not fetch context lines for this range]")
		else
			local context_lines =
				vim.api.nvim_buf_get_lines(bufnr, start_context_lnum_0based, end_context_lnum_exclusive, false)

			if context_lines and #context_lines > 0 then
				local context_header = string.format(
					"\nCode Context (Lines %d-%d):",
					start_context_lnum_0based + 1,
					end_context_lnum_exclusive -- Display the correct inclusive end line number
				)
				table.insert(formatted_output, context_header)
				table.insert(formatted_output, "```" .. filetype) -- Start code block

				for line_idx, line_content in ipairs(context_lines) do
					local current_line_nr_0based = start_context_lnum_0based + line_idx - 1
					local current_line_nr_1based = current_line_nr_0based + 1

					local prefix = "  " -- Default prefix
					if current_line_nr_0based == diag.lnum then
						prefix = ">>" -- Highlight diagnostic line
					end
					local line_num_str = string.format("%-4d", current_line_nr_1based) -- Pad line number
					table.insert(formatted_output, string.format("%s %s | %s", prefix, line_num_str, line_content))

					-- Add column marker on the next line if it's the diagnostic line
					if current_line_nr_0based == diag.lnum and col_nr_1based > 0 then
						-- Create a marker string with spaces and then '^'
						local marker_padding = string.rep(" ", col_nr_1based - 1)
						-- Adjust marker position based on prefix and line number width ("prefix Lnum | ")
						-- Length of prefix (2) + space (1) + length of line_num_str + space (1) + pipe (1) + space (1) = #prefix + #line_num_str + 5
						local marker_prefix_padding = string.rep(" ", #prefix + #line_num_str + 5)
						table.insert(formatted_output, marker_prefix_padding .. marker_padding .. "^")
					end
				end
				table.insert(formatted_output, "```") -- End code block
			else
				table.insert(formatted_output, "\nCode Context:\n[Could not fetch context lines]")
			end
		end
		table.insert(formatted_output, "--- END DIAGNOSTIC ---\n") -- Add separator
	end

	return header_message .. "\n" .. table.concat(formatted_output, "\n")
end

---@return string[]
function M.diag_format(diagnostics)
	local output = {}
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}
	for _, diag in ipairs(diagnostics) do
		local line = string.format(
			"Line %d, Col %d: [%s] %s (%s)",
			diag.lnum + 1, -- Convert from 0-based to 1-based line numbers
			diag.col + 1, -- Convert from 0-based to 1-based column numbers
			severity_map[diag.severity] or "UNKNOWN",
			diag.message,
			diag.source or "unknown"
		)
		table.insert(output, line)
	end
	return output
end

---Add a comment above the current line based on user input
---@param prefix string The prefix to add before the user's comment text
---@return nil
function M.aider_comment(prefix)
	prefix = prefix or "AI!" -- Default prefix if none provided
	local bufnr = vim.api.nvim_get_current_buf()
	-- toggle aider terminal so we know it's running
	M.toggle("aider") -- Open
	M.toggle("aider") -- Close (or focus if already open)
	local comment_text = vim.fn.input("Enter comment (" .. prefix .. "): ")
	if comment_text == "" then
		return -- Do nothing if the user entered nothing
	end
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local comment_string = vim.bo.commentstring or "# %s" -- Default to '#' if not set
	-- Format the comment string
	local formatted_prefix = " " .. prefix .. " " -- Add spaces around the prefix
	local formatted_comment
	if comment_string:find("%%s") then
		formatted_comment = comment_string:format(formatted_prefix .. comment_text)
	else
		-- Handle cases where commentstring might not have %s (less common)
		-- or just prepend if it's a simple prefix like '#'
		formatted_comment = comment_string .. formatted_prefix .. comment_text
	end
	-- Insert the comment above the current line
	vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line - 1, false, { formatted_comment })
	vim.cmd.write() -- Save the file
	vim.cmd.stopinsert() -- Exit insert mode
	M.toggle("aider") -- Ensure terminal is focused/open for potential follow-up
end

-- Helper function to send commands to the aider terminal
---@param files string[] List of file paths to add to aider
---@param opts? { read_only?: boolean } Options for the command
function M.add_files_to_aider(files, opts)
	opts = opts or {}
	local command = opts.read_only and "/read-only" or "/add"

	if #files == 0 then
		vim.notify("No files provided to add", vim.log.levels.WARN)
		return
	end

	local files_str = table.concat(files, " ")

	-- Ensure the aider terminal is open and get its instance
	local term, is_open = M.get("aider")
	if not is_open then
		term = M.toggle("aider") -- Open it if not already open
		if not term then
			vim.notify("Failed to open aider terminal.", vim.log.levels.ERROR)
			return
		end
		-- Need a slight delay or check to ensure the terminal is ready after toggling
		-- This might require adjustments based on how Snacks handles terminal readiness
		vim.defer_fn(function()
			local term_after_toggle = M.get("aider")
			if term_after_toggle then
				M.send(command .. " " .. files_str .. "\n", { term = term_after_toggle })
			else
				vim.notify("Aider terminal not found after toggle.", vim.log.levels.ERROR)
			end
		end, 100) -- Adjust delay as needed
	else
		M.send(command .. " " .. files_str .. "\n", { term = term })
	end
end

function M.multiline(text)
	local esc = "\27"
	local aider_prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local aider_postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	-- Concatenate prefix, text, and postfix
	return aider_prefix .. text .. aider_postfix
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param cmd string|nil The shell command to execute.
---@return nil
function M.run_command_and_send_output(cmd)
	if cmd == "" or cmd == nil then
		cmd = vim.fn.input("Enter command to run: ")
	end
	vim.notify("Running command: " .. cmd, vim.log.levels.INFO)
	local output = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	local message_to_send = string.format("Command exited with code: %d\nOutput:\n```\n%s\n```\n", exit_code, output)

	if exit_code ~= 0 then
		vim.notify(string.format("Command failed with exit code %d: %s", exit_code, cmd), vim.log.levels.WARN)
	end

	if output == "" and exit_code == 0 then
		vim.notify("Command succeeded but produced no output: " .. cmd, vim.log.levels.INFO)
		-- Still send the exit code message
	elseif output == "" and exit_code ~= 0 then
		vim.notify("Command failed and produced no output: " .. cmd, vim.log.levels.WARN)
		-- Still send the exit code message
	end

	-- Check if the current buffer is a terminal buffer managed by this plugin
	-- M.send relies on vim.b.terminal_job_id being set in the current buffer
	if vim.b.terminal_job_id then
		M.send(message_to_send)
		vim.notify("Command exit code and output sent to terminal.", vim.log.levels.INFO)
	else
		vim.notify(
			"Current buffer is not an active AI terminal. Cannot send command exit code and output.",
			vim.log.levels.ERROR
		)
	end
end

return M
