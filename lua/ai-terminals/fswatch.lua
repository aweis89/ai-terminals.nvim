---@class FileWatcher
---File watching module that provides a common interface for watching file changes
---and reloading buffers across different terminal backends
local FileWatcher = {}

local Config = require("ai-terminals.config")

-- Storage for active watchers by terminal name
local _file_watchers = {}

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

				vim.schedule(function()
					reload_callback()
				end)
			end)
		end
	end

	-- Single notification with all watched files
	-- if #watched_files > 0 then
	-- 	local message = "Setting up file watchers for:\n" .. table.concat(watched_files, "\n")
	-- 	vim.notify(message)
	-- end
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
	FileWatcher.setup_watchers(terminal_name, function()
		FileWatcher.reload_changes()

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
		if #reloaded_files > 0 then
			local message = string.format(
				"Reloaded %d file%s:\n%s",
				#reloaded_files,
				#reloaded_files > 1 and "s" or "",
				table.concat(reloaded_files, "\n")
			)
			vim.notify(message, vim.log.levels.DEBUG)
		end
	end)
end

local function has_client(bufnr, names)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	local set = {}
	for _, n in ipairs(names) do
		set[n] = true
	end
	for _, c in ipairs(clients) do
		if set[c.name] then
			return true
		end
	end
	return false
end

local function format_on_external_change(args)
	local cfg = Config.config.trigger_formatting
	if not cfg.enabled then
		return
	end

	local bufnr = args.buf
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
		return
	end

	local timeout = cfg.timeout_ms or 5000

	local log = function(msg)
		local file = vim.api.nvim_buf_get_name(bufnr)
		file = vim.fn.fnamemodify(file, ":t")
		vim.notify(msg .. ": " .. file, vim.log.levels.INFO, { title = "FormatOnExternalChange" })
	end

	-- Always asynchronous: Conform → none/null-ls → any LSP
	local ok, conform = pcall(require, "conform")
	if ok then
		log("formatting with conform")
		conform.format({ bufnr = bufnr, async = true, timeout_ms = timeout, lsp_format = "never" })
		return
	end
	if has_client(bufnr, { "none-ls", "null-ls" }) then
		log("formatting with null-ls/none-ls")
		vim.lsp.buf.format({
			bufnr = bufnr,
			async = true,
			timeout_ms = timeout,
			filter = function(c)
				return c.name == "none-ls" or c.name == "null-ls"
			end,
		})
		return
	end
	vim.lsp.buf.format({ bufnr = bufnr, async = true, timeout_ms = timeout })
end

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = vim.api.nvim_create_augroup("FormatOnExternalChange", { clear = true }),
	callback = format_on_external_change,
})

return FileWatcher
