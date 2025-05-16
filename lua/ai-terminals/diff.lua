local Diff = {}

-- Add a variable to store the last sync time
local last_sync_time = 0
local sync_debounce_ms = 1000 -- Only allow sync once per second (adjust as needed)

------------------------------------------
-- Ignore Patterns for Diff
------------------------------------------
Diff.DIFF_IGNORE_PATTERNS = {
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

Diff.BASE_COPY_DIR = vim.fn.stdpath("cache") .. "/ai_terminals_diff/"

---Compare current directory with its backup and open differing files or show delta.
---@param opts? { diff_func?: function, delta?: boolean, pre_diff_hook?: fun(cwd_file_path:string|nil, tmp_file_path:string|nil):void } Options table:
---  `diff_func`: A custom function to handle the diff (receives cwd, tmp_dir).
---  `delta`: If true, use `diff -ur | delta` in a terminal instead of vimdiff.
---  `pre_diff_hook`: An optional function called for each file pair before diffing.
---                   `cwd_file_path` is the path in the current working directory (nil if file is only in backup).
---                   `tmp_file_path` is the path in the backup directory (nil if file is only in cwd).
---@return nil
function Diff.diff_changes(opts)
	opts = opts or {}
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local tmp_dir = Diff.BASE_COPY_DIR .. cwd_name

	-- Build exclude patterns for diff/delta command
	local exclude_patterns = {}
	for _, pattern in ipairs(Diff.DIFF_IGNORE_PATTERNS) do
		table.insert(exclude_patterns, string.format("--exclude='%s'", pattern))
	end
	local exclude_str = table.concat(exclude_patterns, " ")

	-- Handle custom diff function
	if opts.diff_func then
		opts.diff_func(cwd, tmp_dir)
		return
	end

	-- Handle delta mode
	if opts.delta then
		-- Check if delta is available
		if vim.fn.executable("delta") == 0 then
			vim.notify("delta executable not found. Please install delta.", vim.log.levels.ERROR)
			return
		end
		-- First, run diff without delta to check if there are changes
		local check_diff_cmd = string.format("diff -ur %s %s %s", exclude_str, tmp_dir, cwd)
		local diff_output = vim.fn.systemlist(check_diff_cmd) -- Use systemlist to capture output lines
		local exit_code = vim.v.shell_error

		if exit_code == 0 then
			-- vim.notify("No differences found (delta mode).", vim.log.levels.INFO)
			return -- Exit the function, no need to open terminal
		elseif exit_code > 1 then
			-- Handle potential errors from the diff command itself
			local error_message = table.concat(diff_output, "\n") -- Output might contain error details
			vim.notify(
				string.format("Error running diff command (exit code %d): %s", exit_code, error_message),
				vim.log.levels.ERROR
			)
			return -- Exit on error
		end

		-- Differences found (exit_code == 1), proceed with delta terminal
		local delta_cmd = string.format("%s | delta --paging=never -s", check_diff_cmd) -- Reuse the diff command
		vim.notify("Differences found. Running: " .. delta_cmd, vim.log.levels.INFO)
		vim.cmd("tabnew")
		vim.cmd("terminal " .. delta_cmd)

		-- *** Mark the buffer and add mapping ***
		local term_bufnr = vim.api.nvim_get_current_buf()
		if term_bufnr and term_bufnr ~= 0 then
			vim.b[term_bufnr].is_ai_terminals_delta_diff = true -- Set a unique marker variable
			-- Add buffer-local mapping for 'q' to close the diff
			vim.api.nvim_buf_set_keymap(
				term_bufnr,
				"n",
				"q",
				"<Cmd>lua require('ai-terminals.diff').close_diff()<CR>",
				{ noremap = true, silent = true, desc = "Close AI Terminals Diff" }
			)
		else
			vim.notify("Could not get buffer number for delta terminal to mark it.", vim.log.levels.WARN)
		end
		-- *** End of added section ***

		-- Wait a moment for terminal to open then scroll to top
		vim.defer_fn(function()
			-- Optional: Check if buffer still exists and is the marked one before sending keys
			if vim.api.nvim_buf_is_valid(term_bufnr) and vim.b[term_bufnr].is_ai_terminals_delta_diff then
				vim.api.nvim_feedkeys("gg", "n", false)
			end
		end, 100) -- Adjust delay if needed
		return
	end

	-- Default behavior: Use diff -rq and vimdiff

	-- Get list of files that differ using diff -rq
	local diff_cmd = string.format("diff -rq %s %s %s", exclude_str, cwd, tmp_dir)
	local diff_output = vim.fn.system(diff_cmd)

	if vim.v.shell_error == 0 then
		-- vim.notify("No differences found", vim.log.levels.INFO)
		return
	end

	-- Process diff output and extract file paths
	local diff_files = {}
	for line in vim.gsplit(diff_output, "\n") do
		-- Match only text file differences, ignore binary file differences
		if line:match("^Files .* and .* differ$") then
			local orig_file = line:match("^Files (.-) and")
			local tmp_file = line:match(" and (.-) differ$")
			-- Ensure we captured both file paths correctly
			if orig_file and tmp_file then
				table.insert(diff_files, { orig = orig_file, tmp = tmp_file })
			else
				vim.notify("Could not parse diff line: " .. line, vim.log.levels.WARN)
			end
		elseif line:match("^Binary files .* and .* differ$") then
			-- Explicitly ignore binary file differences
			local binary_file1 = line:match("^Binary files (.-) and")
			vim.notify(
				"Ignoring binary file difference: " .. vim.fn.fnamemodify(binary_file1, ":t"),
				vim.log.levels.DEBUG
			)
		end
	end

	if #diff_files == 0 then
		vim.notify("No text file differences found.", vim.log.levels.INFO)
		return
	end

	-- Close all current windows
	vim.cmd("tabonly")
	vim.cmd("only")

	local orig_files_to_notify = {}
	-- Open each differing file in a split view
	for i, files in ipairs(diff_files) do
		-- Call pre_diff_hook if provided
		if opts.pre_diff_hook then
			opts.pre_diff_hook(files.orig, files.tmp) -- files.orig is cwd, files.tmp is backup
		end

		table.insert(orig_files_to_notify, vim.fn.fnamemodify(files.orig, ":t")) -- Add only the filename

		if i > 1 then
			-- Create a new tab for each additional file pair
			vim.cmd("tabnew")
		end

		-- Edit the temporary backup file first (left side)
		vim.cmd("edit " .. vim.fn.fnameescape(files.tmp))
		vim.cmd("diffthis")
		-- Vertically split to open the original file (right side)
		vim.cmd("vsplit " .. vim.fn.fnameescape(files.orig))
		vim.cmd("diffthis")

		-- Enable wrap in both diff windows
		vim.cmd("setlocal wrap") -- Set wrap for the current window (original file)
		local orig_bufnr = vim.api.nvim_get_current_buf() -- Get buffer number for original file

		vim.cmd("wincmd p") -- Move cursor to the previous window (tmp file)
		vim.cmd("setlocal wrap") -- Set wrap for the tmp file window
		local tmp_bufnr = vim.api.nvim_get_current_buf() -- Get buffer number for tmp file

		-- Add buffer-local mapping for 'q' to close the diff for both buffers
		local map_opts = { noremap = true, silent = true, desc = "Close AI Terminals Diff" }
		local map_cmd = "<Cmd>lua require('ai-terminals.diff').close_diff()<CR>"

		-- Apply mapping to original file buffer (now on the right)
		if vim.api.nvim_buf_is_valid(orig_bufnr) then
			vim.api.nvim_buf_set_keymap(orig_bufnr, "n", "q", map_cmd, map_opts)
		end
		-- Apply mapping to tmp file buffer (now on the left)
		if vim.api.nvim_buf_is_valid(tmp_bufnr) then
			vim.api.nvim_buf_set_keymap(tmp_bufnr, "n", "q", map_cmd, map_opts)
		end
		-- Optional: Move focus back to the right window (original file) if desired
		-- vim.cmd("wincmd p")
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

---Close and wipe out any buffers whose file path is inside the BASE_COPY_DIR,
---and close any tabs dedicated to the delta diff view.
---@return nil
function Diff.close_diff()
	local base_copy_dir_abs = vim.fn.fnamemodify(Diff.BASE_COPY_DIR, ":p") -- Get absolute path
	local file_buffers_to_wipe = {}
	local delta_tabs_to_close = {}
	local delta_buffers_to_wipe = {} -- Keep track separately

	-- 1. Find regular diff file buffers
	for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		local bufname = bufinfo.name
		if bufname and bufname ~= "" then
			-- Check for standard diff buffers in the cache directory
			local bufname_abs = vim.fn.fnamemodify(bufname, ":p") -- Get absolute path of buffer
			if bufname_abs:find(base_copy_dir_abs, 1, true) == 1 then
				table.insert(file_buffers_to_wipe, bufinfo.bufnr)
			end
		end
	end

	-- 2. Find dedicated delta diff tabs/terminals using the marker variable
	for _, tabid in ipairs(vim.api.nvim_list_tabpages()) do
		if vim.api.nvim_tabpage_is_valid(tabid) then
			local windows = vim.api.nvim_tabpage_list_wins(tabid)
			-- Check if the tab contains exactly one window (good heuristic for our dedicated tab)
			if #windows == 1 then
				local winid = windows[1]
				if vim.api.nvim_win_is_valid(winid) then
					local bufnr = vim.api.nvim_win_get_buf(winid)
					if vim.api.nvim_buf_is_valid(bufnr) then
						-- *** Check for our specific marker variable ***
						if vim.b[bufnr].is_ai_terminals_delta_diff == true then
							table.insert(delta_tabs_to_close, tabid)
							table.insert(delta_buffers_to_wipe, bufnr)
							vim.notify(
								"Found marked delta diff buffer " .. bufnr .. " in tab " .. tabid,
								vim.log.levels.DEBUG
							)
						end
					end
				end
			end
		end
	end

	-- Optional: Add a safety check for any marked buffers not found in dedicated tabs
	-- This might happen if the user manually moved the terminal window
	for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		local bufnr = bufinfo.bufnr
		if vim.b[bufnr].is_ai_terminals_delta_diff == true then
			local already_found = false
			for _, b in ipairs(delta_buffers_to_wipe) do
				if b == bufnr then
					already_found = true
					break
				end
			end
			if not already_found then
				vim.notify(
					"Found marked delta diff buffer " .. bufnr .. " outside a dedicated tab.",
					vim.log.levels.DEBUG
				)
				table.insert(delta_buffers_to_wipe, bufnr) -- Ensure it gets wiped
			end
		end
	end

	local closed_tab_count = #delta_tabs_to_close -- Count how many tabs we intend to close
	local wiped_buffer_count = 0

	-- 3. Wipe out all identified buffers (combine file and delta buffers)
	local all_buffers_to_wipe = {}
	for _, bufnr in ipairs(file_buffers_to_wipe) do
		all_buffers_to_wipe[bufnr] = true
	end
	for _, bufnr in ipairs(delta_buffers_to_wipe) do
		all_buffers_to_wipe[bufnr] = true
	end

	for bufnr, _ in pairs(all_buffers_to_wipe) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			-- Important: Unset the variable before wiping to prevent potential issues
			-- if the buffer somehow persists or during autocmds triggered by wipeout.
			vim.b[bufnr].is_ai_terminals_delta_diff = nil
			vim.cmd(bufnr .. "bwipeout!")
			wiped_buffer_count = wiped_buffer_count + 1
		end
	end

	-- 4. Provide feedback (same logic as before)
	local messages = {}
	if closed_tab_count > 0 then
		table.insert(messages, string.format("Closed %d delta diff tab(s).", closed_tab_count))
	end
	if wiped_buffer_count > 0 then
		table.insert(
			messages,
			string.format("Wiped out %d buffer(s) (including diff files and/or delta terminals).", wiped_buffer_count)
		)
	end

	if #messages > 0 then
		vim.notify(table.concat(messages, "\n"), vim.log.levels.INFO)
	else
		vim.notify("No diff buffers or delta tabs found to close.", vim.log.levels.DEBUG)
	end
end

---Run rsync to create/update a backup of the current project directory.
---This is typically called when an AI terminal window is opened or entered.
---Includes debouncing to prevent rapid successive calls.
---@return nil
function Diff.pre_sync_code_base()
	local current_time = vim.fn.reltimefloat(vim.fn.reltime()) * 1000 -- Time in milliseconds

	if current_time - last_sync_time < sync_debounce_ms then
		return -- Exit early if called within the debounce period
	end
	last_sync_time = current_time -- Update the last sync time

	-- vim.notify("Syncing code-base", vim.log.levels.DEBUG)
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local backup_dir = Diff.BASE_COPY_DIR .. cwd_name

	-- Ensure the base directory exists
	vim.fn.mkdir(Diff.BASE_COPY_DIR, "p")

	local rsync_args = { "rsync", "-av", "--delete" }
	for _, pattern in ipairs(Diff.DIFF_IGNORE_PATTERNS) do
		table.insert(rsync_args, "--exclude")
		table.insert(rsync_args, pattern)
	end
	table.insert(rsync_args, cwd .. "/") -- Add trailing slash to source for rsync behavior
	table.insert(rsync_args, backup_dir)

	local job_id = vim.fn.jobstart(rsync_args, {
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				vim.schedule(function()
					vim.notify(string.format("Backup sync failed with exit code %d.", exit_code), vim.log.levels.ERROR)
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
end

---Revert the current working directory to the state stored in the backup directory.
---Uses rsync to overwrite local changes with the backup content.
---Prompts the user for confirmation before proceeding.
---@return nil
function Diff.revert_changes()
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local backup_dir = Diff.BASE_COPY_DIR .. cwd_name

	-- Check if the backup directory exists
	if vim.fn.isdirectory(backup_dir) == 0 then
		vim.notify("Backup directory not found: " .. backup_dir, vim.log.levels.ERROR)
		vim.notify("Cannot revert changes. Run an AI terminal first to create a backup.", vim.log.levels.WARN)
		return
	end

	-- *** Confirmation Step ***
	local confirmation_message = string.format("Revert changes?", cwd, backup_dir)
	local choice = vim.fn.confirm(confirmation_message, "&Yes\n&No", 2, "Warning")

	if choice ~= 1 then
		vim.notify("Revert cancelled by user.", vim.log.levels.INFO)
		return
	end

	vim.notify("Reverting changes from backup...", vim.log.levels.INFO)

	-- Build rsync command arguments
	local rsync_args = { "rsync", "-av", "--delete" } -- -a: archive, -v: verbose, --delete: delete files in dest not in src
	for _, pattern in ipairs(Diff.DIFF_IGNORE_PATTERNS) do
		table.insert(rsync_args, "--exclude")
		table.insert(rsync_args, pattern)
	end
	-- Source: backup directory (contents)
	table.insert(rsync_args, backup_dir .. "/") -- Trailing slash is important!
	-- Destination: current working directory
	table.insert(rsync_args, cwd)

	local job_id = vim.fn.jobstart(rsync_args, {
		on_exit = function(_, exit_code)
			vim.schedule(function() -- Ensure notification runs on the main thread
				if exit_code == 0 then
					vim.notify("Successfully reverted changes from backup.", vim.log.levels.INFO)
					-- Optional: Reload buffers or notify user to do so if needed
					vim.cmd("checktime") -- Force Neovim to check for file changes on disk
				else
					vim.notify(
						string.format("Revert failed with exit code %d. Check rsync output/errors.", exit_code),
						vim.log.levels.ERROR
					)
				end
			end)
		end,
		stdout_buffered = true, -- Capture stdout for potential debugging
		stderr_buffered = true, -- Capture stderr for errors
		on_stderr = function(_, data)
			if data and #data > 0 and data[1] ~= "" then -- Check for actual error messages
				local err_msg = table.concat(data, "\n")
				vim.schedule(function()
					vim.notify("Revert error (rsync stderr): " .. err_msg, vim.log.levels.ERROR)
				end)
			end
		end,
	})

	if not job_id or job_id == 0 or job_id == -1 then
		vim.notify("Failed to start revert job (rsync).", vim.log.levels.ERROR)
	end
end

return {
	DIFF_IGNORE_PATTERNS = Diff.DIFF_IGNORE_PATTERNS,
	BASE_COPY_DIR = Diff.BASE_COPY_DIR,
	diff_changes = Diff.diff_changes,
	close_diff = Diff.close_diff,
	pre_sync_code_base = Diff.pre_sync_code_base,
	revert_changes = Diff.revert_changes,
}
