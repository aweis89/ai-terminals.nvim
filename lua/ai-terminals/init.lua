local M = {}

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
local function _setup_terminal_autocmds(buf_id)
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

	-- Autocommand to reload buffers when focus leaves the terminal buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		buffer = buf_id,
		desc = "Reload buffers when AI terminal loses focus",
		callback = check_files,
	})

	-- Autocommand to clean up the group when the terminal closes
	vim.api.nvim_create_autocmd("TermClose", {
		group = augroup,
		buffer = buf_id,
		once = true, -- Only need to clean up once
		desc = "Clean up AI terminal autocommands",
		callback = function()
			pcall(vim.api.nvim_del_augroup_by_name, group_name)
			vim.notify("AI terminal closed & autocommands cleaned up.", vim.log.levels.INFO)
			-- Optional: Run check_files one last time on close?
			check_files()
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

---Create a terminal with specified position and command
---@param cmd string
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.ai_terminal(cmd, position)
	position = position or "float"
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }

	if not valid_positions[position] then
		vim.notify("Invalid terminal position: " .. tostring(position), vim.log.levels.ERROR)
		return nil
	end

	-- Build rsync exclude patterns
	local rsync_args = { "rsync", "-av", "--delete" }
	for _, pattern in ipairs(DIFF_IGNORE_PATTERNS) do
		table.insert(rsync_args, "--exclude")
		table.insert(rsync_args, pattern)
	end
	table.insert(rsync_args, vim.fn.getcwd())
	table.insert(rsync_args, BASE_COPY_DIR)

	vim.system(rsync_args)

	local dimensions = WINDOW_DIMENSIONS[position]

	local term = Snacks.terminal.toggle(cmd, {
		env = { id = cmd },
		win = {
			position = position,
			height = dimensions.height,
			width = dimensions.width,
		},
	})

	_setup_terminal_autocmds(term.buf)

	return term
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

	-- Open each differing file in a split view
	for i, files in ipairs(diff_files) do
		vim.notify(string.format("Diffing %s and %s", files.orig, files.tmp), vim.log.levels.INFO)

		if i > 1 then
			-- Create a new tab for each additional file pair
			vim.cmd("tabnew")
		end

		vim.cmd("edit " .. vim.fn.fnameescape(files.orig))
		vim.cmd("diffthis")
		vim.cmd("vsplit " .. vim.fn.fnameescape(files.tmp))
		vim.cmd("diffthis")
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
		vim.notify(string.format("Wiped out %d buffer(s) from the diff directory.", wiped_count), vim.log.levels.INFO)
	else
		vim.notify("No diff buffers found to close.", vim.log.levels.INFO)
	end
end

---Send text to a terminal
---@param text string The text to send
---@return nil
function M.send(text, opts)
	local ok, err = pcall(vim.fn.chansend, vim.b.terminal_job_id, text)
	if not ok then
		vim.notify("Failed to send selection: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
end

function M.scratch_prompt()
	local bufnr = vim.api.nvim_get_current_buf()
	local selection = M.get_visual_selection_with_header(bufnr)
	Snacks.scratch()
	local scratch_bufnr = vim.api.nvim_get_current_buf()
	if not selection then
		return
	end
	local lines = vim.split(selection, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(scratch_bufnr, 0, 2, false, lines)

	vim.defer_fn(function()
		vim.cmd("normal! GA") -- Go to last line and enter Insert mode at the end
	end, 500)
	vim.api.nvim_create_autocmd({ "BufLeave" }, {
		buffer = scratch_bufnr,
		once = true, -- Ensure it only runs once for this buffer instance
		desc = "Log closure of AI terminal scratch buffer",
		callback = function(args)
			local result = vim.api.nvim_buf_get_lines(scratch_bufnr, 0, -1, false)
			vim.api.nvim_del_autocmd(args.id) -- Clean up the autocommand
			vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, {})
			vim.defer_fn(function()
				M.aider_terminal()
				M.send("\n{EOL\n")
				M.send(table.concat(result, "\n"))
				M.send("\nEOL}\n")
			end, 500)
		end,
	})
end

------------------------------------------
-- Terminal Instances
------------------------------------------

---Create a Goose terminal
---@return snacks.win|nil
function M.goose_terminal()
	return M.ai_terminal(string.format("GOOSE_CLI_THEME=%s goose", vim.o.background))
end

---Create a Claude terminal
---@return snacks.win|nil
function M.claude_terminal()
	local theme = vim.o.background
	return M.ai_terminal(string.format("claude config set -g theme %s && claude", theme))
end

---Create a Claude terminal
---@return snacks.win|nil
function M.aider_terminal()
	return M.ai_terminal(string.format("aider --watch-files --%s-mode", vim.o.background))
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

---@return string
function M.diagnostics()
	local diagnostics = {}
	local bufnr = 0 -- Use current buffer
	local mode = vim.api.nvim_get_mode().mode

	if mode:match("^[vV\22]") then -- visual, visual-line, or visual-block mode
		local start_mark = vim.api.nvim_buf_get_mark(bufnr, "<")
		local end_mark = vim.api.nvim_buf_get_mark(bufnr, ">")
		-- Ensure marks are valid and start <= end
		if start_mark and end_mark and start_mark[1] > 0 and end_mark[1] > 0 then
			local start_line = math.min(start_mark[1], end_mark[1])
			local end_line = math.max(start_mark[1], end_mark[1])
			-- vim.diagnostic.get uses 0-based line numbers, marks are 1-based
			for line_num = start_line - 1, end_line - 1 do
				local line_diags = vim.diagnostic.get(bufnr, { lnum = line_num })
				vim.list_extend(diagnostics, line_diags)
			end
		else
			-- Fallback or handle error if visual selection is invalid
			diagnostics = vim.diagnostic.get(bufnr)
		end
	else
		diagnostics = vim.diagnostic.get(bufnr)
	end

	local file = vim.api.nvim_buf_get_name(bufnr)
	local formatted_output = {}

	if #diagnostics == 0 then
		return string.format("No diagnostics found for file: %q", file)
	end

	-- Sort diagnostics by line number, then column
	table.sort(diagnostics, function(a, b)
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		return a.col < b.col
	end)

	for _, diag in ipairs(diagnostics) do
		-- Neovim diagnostics use 0-based indexing for line (lnum) and column (col)
		local line_nr = diag.lnum + 1 -- Convert to 1-based for display
		local col_nr = diag.col + 1 -- Convert to 1-based for display
		local severity_str = get_severity_str(diag.severity)
		local message = diag.message or ""
		-- Remove potential newlines from the message itself
		message = message:gsub("\n", "")

		-- Fetch the source code line (0-based index)
		local source_line = vim.api.nvim_buf_get_lines(bufnr, diag.lnum, diag.lnum + 1, false)[1]
		if source_line == nil then
			source_line = "[Could not fetch source line]"
		end

		-- Format the output for this diagnostic
		table.insert(formatted_output, string.format("[%s] L%d:%d: %s", severity_str, line_nr, col_nr, message))
		table.insert(formatted_output, string.format("  > %s", source_line))
	end

	return string.format("Diagnostics for file: %q\n\n%s\n", file, table.concat(formatted_output, "\n\n"))
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
	-- toggle aider terminal
	M.aider_terminal()
	M.aider_terminal()
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
	vim.api.nvim_buf_set_lines(0, current_line - 1, current_line - 1, false, { formatted_comment })
	vim.cmd.write() -- Save the file
	vim.cmd.stopinsert() -- Exit insert mode
end

-- Helper function to send commands to aider terminal
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

	local term = require("ai-terminals")
	-- Check if the aider terminal is already open
	if not vim.b.term_title then
		term.aider_terminal()
	end
	term.send(command .. " " .. files_str .. "\n")
end

function M.aider_multiline(text)
	local aider_prefix = "\n{EOL\n"
	local aider_postfix = "\nEOL}\n"
	return aider_prefix .. text .. aider_postfix
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param cmd string The shell command to execute.
---@return nil
function M.run_command_and_send_output(cmd)
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
