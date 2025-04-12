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
---@return snacks.win
function M.toggle(cmd, position)
	position = position or "float"
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }

	if not valid_positions[position] then
		vim.notify("Invalid terminal position: " .. tostring(position), vim.log.levels.ERROR)
		position = "float"
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

---@param cmd string
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win?, boolean?
function M.get(cmd, position)
	position = position or "float"
	local dimensions = WINDOW_DIMENSIONS[position]
	return Snacks.terminal.get(cmd, {
		env = { id = cmd },
		win = {
			position = position,
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

------------------------------------------
-- Terminal Instances
------------------------------------------
local GOOSE_CMD = string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)

local AICHAT_CMD = string.format(
	"AICHAT_LIGHT_THEME=%s GEMINI_API_BASE=http://localhost:8080/v1beta aichat -r %%functions%% --session",
	tostring(vim.o.background == "light") -- Convert boolean to string "true" or "false"
)
local CLAUDE_CMD = string.format("claude config set -g theme %s && claude", vim.o.background)
local AIDER_CMD = string.format("aider --watch-files --%s-mode", vim.o.background)

---Create or toggle a Goose terminal
---@return snacks.win
function M.goose_toggle()
	return M.toggle(GOOSE_CMD)
end

---Get an existing Goose terminal instance
---@return snacks.win?, boolean?
function M.goose_get()
	return M.get(GOOSE_CMD)
end

---Create or toggle a Claude terminal
---@return snacks.win
function M.claude_toggle()
	return M.toggle(CLAUDE_CMD)
end

---Get an existing Claude terminal instance
---@return snacks.win?, boolean?
function M.claude_get()
	return M.get(CLAUDE_CMD)
end

---Create or toggle an Aider terminal
---@return snacks.win
function M.aider_toggle()
	return M.toggle(AIDER_CMD)
end

---Get an existing Aider terminal instance
---@return snacks.win?, boolean?
function M.aider_get()
	return M.get(AIDER_CMD)
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

		-- Format the output for this diagnostic
		table.insert(formatted_output, string.format("[%s] L%d:%d: %s", severity_str, line_nr, col_nr, message))

		-- Fetch context lines (1 line before and 1 line after)
		local context_before = 1
		local context_after = 1
		local start_context_lnum_0based = math.max(0, diag.lnum - context_before)
		-- End index for get_lines is exclusive. Fetch up to line diag.lnum + context_after.
		local end_context_lnum_exclusive = diag.lnum + 1 + context_after
		local context_lines =
			vim.api.nvim_buf_get_lines(bufnr, start_context_lnum_0based, end_context_lnum_exclusive, false)

		-- Add context lines to the output
		if context_lines and #context_lines > 0 then
			for i, line_content in ipairs(context_lines) do
				local current_line_nr_0based = start_context_lnum_0based + i - 1 -- Calculate the 0-based index
				local current_line_nr_1based = current_line_nr_0based + 1 -- 1-based line number for display

				local prefix = "  " -- Default prefix for context lines
				if current_line_nr_0based == diag.lnum then -- Highlight the actual diagnostic line
					prefix = ">>" -- Highlight prefix
				end
				local line_num_str = string.format("%4d", current_line_nr_1based) -- Pad line number for alignment
				table.insert(formatted_output, string.format(" %s %s | %s", prefix, line_num_str, line_content))
			end
		else
			-- Fallback if context lines couldn't be fetched (e.g., empty buffer)
			local source_line = vim.api.nvim_buf_get_lines(bufnr, diag.lnum, diag.lnum + 1, false)[1]
			if source_line == nil then
				source_line = "[Could not fetch source line]"
			end
			table.insert(formatted_output, string.format("  > %s", source_line))
		end
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
	local bufnr = vim.api.nvim_get_current_buf()
	-- toggle aider terminal so we know it's running
	M.aider_toggle()
	M.aider_toggle()
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
	M.aider_toggle()
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

	-- Check if the aider terminal is already open
	if not vim.b.term_title then
		M.aider_toggle()
	end
	local term = M.aider_get()
	M.send(command .. " " .. files_str .. "\n", { term = term })
end

function M.multiline(text)
	local esc = "\27"
	local aider_prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local aider_postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	-- Concatenate prefix, text, and postfix
	return aider_prefix .. text .. aider_postfix
end

-- Example Usage:
local my_text = "hello\nworld" -- Example multi-line text
local wrapped_text = M.multiline(my_text)

-- Printing the result:
-- Note: When you print this directly to a terminal that *understands* these sequences,
-- you might not see the sequences themselves. The terminal might interpret them.
-- To see the raw characters (often represented visually), you might need specific tools
-- or print in a context where escape codes are displayed literally.
print("--- Raw Wrapped Text (may be interpreted by terminal) ---")
print(wrapped_text)

-- To better visualize the raw bytes/characters including the escape codes,
-- you could print their byte values:
print("\n--- Byte values of wrapped text ---")
for i = 1, #wrapped_text do
	io.write(string.format("%d ", string.byte(wrapped_text, i)))
end
print()
-- Expected byte sequence start: 27 91 50 48 48 126 ... (ESC [ 2 0 0 ~)
-- Expected byte sequence end: ... 27 91 50 48 49 126 (ESC [ 2 0 1 ~)

------------------------------------------
-- Aider Specific Helpers
------------------------------------------

---Send text specifically to the Aider terminal.
---Ensures the terminal is open before sending.
---@param text string The text to send.
---@return nil
function M.send_to_aider(text)
	local term = M.aider_get()
	if not term then
		term = M.aider_toggle() -- Open if not found
		-- Small delay to allow terminal to initialize (adjust if needed)
		vim.defer_fn(function()
			M.send(text, { term = term })
		end, 100)
		return
	end
	M.send(text, { term = term })
end

---Ask Aider a question, optionally including visual selection.
---@param prompt string|nil The question prompt. If nil, user will be prompted.
---@param range? table { line1: number, line2: number } Range info from command.
---@return nil
function M.aider_ask(prompt, range)
	local final_prompt = prompt or vim.fn.input("Ask Aider: ")
	if final_prompt == "" then
		vim.notify("Aider Ask cancelled.", vim.log.levels.INFO)
		return
	end

	local selection_text = ""
	if range and range.line1 ~= range.line2 then -- Check if a visual range exists
		-- We need to temporarily set the visual marks to get the selection
		local current_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_mark(current_buf, "<", range.line1, 0, {})
		vim.api.nvim_buf_set_mark(current_buf, ">", range.line2, -1, {}) -- Use -1 for end of line
		selection_text = M.get_visual_selection_with_header(current_buf) or ""
		-- Clear the marks afterwards if necessary, though get_visual_selection might do this
		-- vim.api.nvim_buf_del_mark(current_buf, "<")
		-- vim.api.nvim_buf_del_mark(current_buf, ">")
	end

	local command_to_send = "/ask " .. final_prompt
	if selection_text ~= "" then
		command_to_send = command_to_send .. "\n" .. selection_text
	end

	M.send_to_aider(command_to_send .. "\n") -- Add newline to execute command
end

---Send diagnostics (current buffer or visual selection) to Aider for fixing.
---@param range? table { line1: number, line2: number } Range info from command.
---@return nil
function M.aider_fix_diagnostics(range)
	local diagnostics_text
	if range and range.line1 ~= range.line2 then
		-- Temporarily set marks for visual selection range diagnostics
		local current_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_mark(current_buf, "<", range.line1, 0, {})
		vim.api.nvim_buf_set_mark(current_buf, ">", range.line2, -1, {})
		diagnostics_text = M.diagnostics() -- M.diagnostics already handles visual mode based on marks
		-- Clear marks if needed
	else
		-- No range, get diagnostics for the whole buffer
		diagnostics_text = M.diagnostics()
	end

	if diagnostics_text:match("No diagnostics found") then
		vim.notify(diagnostics_text, vim.log.levels.INFO)
		return
	end

	-- Format for Aider (consider if a specific format is better)
	local command_to_send = "/edit --diagnostics\n" .. diagnostics_text

	M.send_to_aider(command_to_send .. "\n")
	vim.notify("Sent diagnostics to Aider.", vim.log.levels.INFO)
end

---Execute a shell command and send its stdout/stderr and exit code to the Aider terminal.
---@param cmd string The shell command to execute.
---@return nil
function M.run_command_and_send_output_to_aider(cmd)
	vim.notify("Running command for Aider: " .. cmd, vim.log.levels.INFO)
	-- Use vim.systemlist to capture output line-by-line, potentially better for terminals
	local output_lines = vim.systemlist(cmd)
	local exit_code = vim.v.shell_error
	local output = table.concat(output_lines, "\n")

	local message_to_send = string.format(
		"Command `%s` exited with code: %d\nOutput:\n```\n%s\n```\n",
		cmd,
		exit_code,
		output
	)

	if exit_code ~= 0 then
		vim.notify(string.format("Command failed with exit code %d: %s", exit_code, cmd), vim.log.levels.WARN)
	end

	if output == "" and exit_code == 0 then
		vim.notify("Command succeeded but produced no output: " .. cmd, vim.log.levels.INFO)
	elseif output == "" and exit_code ~= 0 then
		vim.notify("Command failed and produced no output: " .. cmd, vim.log.levels.WARN)
	end

	M.send_to_aider(message_to_send)
	vim.notify("Command exit code and output sent to Aider.", vim.log.levels.INFO)
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

------------------------------------------
-- Neovim Commands
------------------------------------------
local function setup_commands()
	-- Helper to get files from args or current buffer
	local function get_files_from_args(args)
		if #args > 0 then
			return args
		else
			local current_file = vim.fn.expand("%:p")
			if current_file == "" then
				vim.notify("No file specified and no current buffer name.", vim.log.levels.ERROR)
				return nil
			end
			return { current_file }
		end
	end

	-- AiderComment: Add AI comment
	vim.api.nvim_create_user_command("AiderComment", function(opts)
		local prefix = opts.bang and "AI!" or "AI"
		M.aider_comment(prefix)
	end, {
		bang = true,
		desc = "Add AI comment (AI or AI!) above current line",
	})

	-- AiderCommentAsk: Add AI? comment
	vim.api.nvim_create_user_command("AiderCommentAsk", function()
		M.aider_comment("AI?")
	end, {
		desc = "Add AI? comment above current line to ask Aider a question",
	})

	-- AiderToggle: Toggle Aider terminal
	vim.api.nvim_create_user_command("AiderToggle", function()
		M.aider_toggle()
	end, {
		desc = "Toggle the Aider terminal window",
		-- Add nargs/complete later if direction support is added
	})

	-- AiderAdd: Add files to Aider
	vim.api.nvim_create_user_command("AiderAdd", function(opts)
		local files = get_files_from_args(opts.fargs)
		if files then
			M.add_files_to_aider(files, { read_only = false })
		end
	end, {
		nargs = "*",
		complete = "file",
		desc = "Add specified files (or current file) to Aider",
	})

	-- AiderReadOnly: Add files as read-only
	vim.api.nvim_create_user_command("AiderReadOnly", function(opts)
		local files = get_files_from_args(opts.fargs)
		if files then
			M.add_files_to_aider(files, { read_only = true })
		end
	end, {
		nargs = "*",
		complete = "file",
		desc = "Add specified files (or current file) to Aider as read-only",
	})

	-- AiderAsk: Ask Aider a question
	vim.api.nvim_create_user_command("AiderAsk", function(opts)
		local range = { line1 = opts.line1, line2 = opts.line2 }
		M.aider_ask(opts.args, range)
	end, {
		nargs = "?", -- Optional prompt argument
		range = true, -- Allow visual selection range
		desc = "Ask Aider a question (uses visual selection if present)",
	})

	-- AiderSend: Send text/command to Aider
	vim.api.nvim_create_user_command("AiderSend", function(opts)
		local text_to_send = opts.args
		if opts.line1 ~= opts.line2 then -- Visual selection exists
			local current_buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_mark(current_buf, "<", opts.line1, 0, {})
			vim.api.nvim_buf_set_mark(current_buf, ">", opts.line2, -1, {})
			local selection = M.get_visual_selection_with_header(current_buf) or ""
			if text_to_send and text_to_send ~= "" then
				text_to_send = text_to_send .. "\n" .. selection
			else
				text_to_send = selection
			end
		end

		if not text_to_send or text_to_send == "" then
			vim.notify("Nothing to send to Aider.", vim.log.levels.WARN)
			return
		end
		M.send_to_aider(text_to_send .. "\n") -- Add newline to execute
	end, {
		nargs = "?", -- Command text is optional if using visual selection
		range = true, -- Allow visual selection range
		desc = "Send text/command to Aider (uses visual selection if present)",
	})

	-- AiderFixDiagnostics: Send diagnostics to Aider
	vim.api.nvim_create_user_command("AiderFixDiagnostics", function(opts)
		local range = { line1 = opts.line1, line2 = opts.line2 }
		M.aider_fix_diagnostics(range)
	end, {
		range = true, -- Allow visual selection range
		desc = "Send diagnostics (visual selection or buffer) to Aider",
	})

	-- Command to run shell command and send output to Aider
	vim.api.nvim_create_user_command("AiderRunCommand", function(opts)
		if not opts.args or opts.args == "" then
			vim.notify("No command provided to run.", vim.log.levels.ERROR)
			return
		end
		M.run_command_and_send_output_to_aider(opts.args)
	end, {
		nargs = 1,
		complete = "shellcmd",
		desc = "Run shell command and send output to Aider",
	})
end

-- Call setup function immediately when the module is loaded
setup_commands()

return M
