---@class FileWatcher
---File watching module that provides a common interface for watching file changes
---and reloading buffers across different terminal backends
local FileWatcher = {}

-- Storage for active watchers by terminal name
local _file_watchers = {}

-- Guard: tracks files we intentionally write so fs_event callbacks ignore them
local _internal_writes = {}
local INTERNAL_WRITE_TTL_MS = 800

local function _mark_internal_write(path)
	if not path or path == "" then
		return
	end
	_internal_writes[path] = true
	-- Clear the mark shortly after to allow future external edits to be seen
	vim.defer_fn(function()
		_internal_writes[path] = nil
	end, INTERNAL_WRITE_TTL_MS)
end

local function _is_internal_write(path)
	return path and _internal_writes[path] == true
end

-- Save the buffer owning `path`, firing BufWritePre/Post as usual
local function _save_buffer_for(path, force)
	if not path or path == "" then
		return
	end
	local bufnr = vim.fn.bufnr(path)
	if bufnr == -1 then
		return
	end
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		pcall(vim.fn.bufload, bufnr)
	end
	vim.api.nvim_buf_call(bufnr, function()
		_mark_internal_write(path)
		local ok, err
		if force then
			ok, err = pcall(vim.cmd, "silent keepalt write")
		else
			ok, err = pcall(vim.cmd, "silent keepalt update")
		end
		if not ok and err then
			vim.notify("ai-terminals: write failed for " .. path .. "\n" .. tostring(err), vim.log.levels.WARN)
		end
	end)
end

---Initialize watchers storage for a terminal
---@param terminal_name string The name of the terminal
function FileWatcher.init_watchers(terminal_name)
	if not _file_watchers then
		_file_watchers = {}
	end
	_file_watchers[terminal_name] = {}
end

---Clean up existing watchers for a terminal
---@param terminal_name string The name of the terminal
function FileWatcher.cleanup_watchers(terminal_name)
	if _file_watchers and _file_watchers[terminal_name] then
		for _, watcher in pairs(_file_watchers[terminal_name]) do
			if watcher then
				watcher:stop()
			end
		end
		_file_watchers[terminal_name] = {}
	end
end

---Set up file watchers for all files in the current tabpage
---@param terminal_name string The name of the terminal
---@param reload_callback function Function to call when files change
function FileWatcher.setup_watchers(terminal_name, reload_callback)
	-- Clean up old watchers before setting up new ones
	FileWatcher.cleanup_watchers(terminal_name)
	FileWatcher.init_watchers(terminal_name)

	-- Get all windows in the current tab and set up file watchers for their buffers
	local current_tabpage = vim.api.nvim_get_current_tabpage()
	local windows = vim.api.nvim_tabpage_list_wins(current_tabpage)
	local watched_files = {}

	for _, win in ipairs(windows) do
		local buf = vim.api.nvim_win_get_buf(win)
		local file_path = vim.api.nvim_buf_get_name(buf)

		-- Only set up file watcher if we have a valid file
		if file_path and file_path ~= "" and vim.fn.filereadable(file_path) == 1 then
			local w = vim.uv.new_fs_event()

			-- Store the watcher to prevent garbage collection
			table.insert(_file_watchers[terminal_name], w)
			table.insert(watched_files, "- " .. file_path)

			-- Watch the file for changes
			w:start(file_path, {}, function(err, fname, events)
				if err then
					return
				end

				-- Ignore events caused by our own writes
				if _is_internal_write(file_path) or _is_internal_write(fname) then
					return
				end

				vim.schedule(function()
					vim.notify("Calling realod for: " .. (fname or file_path), vim.log.levels.INFO)
					reload_callback(file_path)
				end)
			end)
		end
	end

	-- Single notification with all watched files
	if #watched_files > 0 then
		local message = "Setting up file watchers for:\n" .. table.concat(watched_files, "\n")
		vim.notify(message)
	end
end

---Create cleanup autocmd for when vim exits
---@param terminal_name string The name of the terminal
---@param group_name string The autocmd group name
function FileWatcher.setup_cleanup_autocmd(terminal_name, group_name)
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group_name,
		callback = function()
			FileWatcher.cleanup_watchers(terminal_name)
		end,
		desc = "Clean up file watchers for terminal: " .. terminal_name,
	})
end

---Unified setup for file watching with optional diffing callback
---@param terminal_name string The name of the terminal
---@param diff_callback function? Optional callback to trigger when files change (for diffing)
function FileWatcher.setup_unified_watching(terminal_name, diff_callback)
	-- Set up file watching for immediate reload
	FileWatcher.setup_watchers(terminal_name, function(path)
		FileWatcher.reload_changes()

		-- Save the actual buffer to trigger BufWritePre/Post and format-on-save
		_save_buffer_for(path, true)
		-- Trigger optional diff callback if provided
		if diff_callback then
			diff_callback()
		end
	end)

	-- Set up cleanup
	local group_name = "AITerminal_" .. terminal_name
	vim.api.nvim_create_augroup(group_name, { clear = true })
	FileWatcher.setup_cleanup_autocmd(terminal_name, group_name)
end

---Reload changes for all open buffers
function FileWatcher.reload_changes()
	vim.schedule(function()
		local reloaded_files = {}

		-- Loop through all open buffers and trigger checktime for each
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
				local file_path = vim.api.nvim_buf_get_name(buf)
				if file_path and file_path ~= "" and vim.fn.filereadable(file_path) == 1 then
					table.insert(reloaded_files, "- " .. file_path)
					vim.api.nvim_buf_call(buf, function()
						vim.cmd.checktime()
					end)
				end
			end
		end

		-- Single notification with all reloaded files
		-- if #reloaded_files > 0 then
		-- 	local message = string.format(
		-- 		"Reloaded %d file%s:\n%s",
		-- 		#reloaded_files,
		-- 		#reloaded_files > 1 and "s" or "",
		-- 		table.concat(reloaded_files, "\n")
		-- 	)
		-- 	vim.notify(message, vim.log.levels.INFO)
		-- end
	end)
end

return FileWatcher
