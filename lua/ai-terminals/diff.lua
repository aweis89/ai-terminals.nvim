local M = {}

------------------------------------------
-- Ignore Patterns for Diff
------------------------------------------
M.DIFF_IGNORE_PATTERNS = {
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

M.BASE_COPY_DIR = vim.fn.stdpath("cache") .. "/ai_terminals_diff/"

---Compare current directory with its backup in ~/tmp and open differing files
---@return nil
function M.diff_changes()
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local tmp_dir = M.BASE_COPY_DIR .. cwd_name

	-- Build exclude patterns for diff command
	local exclude_patterns = {}
	for _, pattern in ipairs(M.DIFF_IGNORE_PATTERNS) do
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
	local base_copy_dir_abs = vim.fn.fnamemodify(M.BASE_COPY_DIR, ":p") -- Get absolute path
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

---Run rsync to create/update a backup of the current project directory.
---This is typically called when an AI terminal window is opened.
---@return nil
function M.pre_sync_code_base()
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local backup_dir = M.BASE_COPY_DIR .. cwd_name

	-- Ensure the base directory exists
	vim.fn.mkdir(M.BASE_COPY_DIR, "p")

	local rsync_args = { "rsync", "-av", "--delete" }
	for _, pattern in ipairs(M.DIFF_IGNORE_PATTERNS) do
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

return M
