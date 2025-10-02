---@class FileWatcher
---File watching module that provides a common interface for watching file changes
---and reloading buffers across different terminal backends
local FileWatcher = {}

local Config = require("ai-terminals.config")

-- Storage for active watchers by terminal name
local _file_watchers = {}

-- Local logger for this module
-- Defaults to DEBUG level and sets a consistent title
local function log(msg, level, opts)
	local notify_opts = opts or {}
	if notify_opts.title == nil then
		notify_opts.title = "fswatch"
	end
	vim.notify(msg, level or vim.log.levels.DEBUG, notify_opts)
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
	local watch_cwd = (Config.config and Config.config.watch_cwd) or { enabled = false }

	-- Helper: only use directory watcher inside a git repository
	local function in_git_repo()
		local cwd = vim.fn.getcwd()
		local ok, _ = pcall(function()
			vim.fn.system({ "git", "-C", cwd, "rev-parse", "--is-inside-work-tree" })
		end)
		if not ok then
			return false
		end
		return vim.v.shell_error == 0
	end

	if watch_cwd.enabled then
		FileWatcher.setup_dir_watcher(terminal_name, reload_callback)
	else
		if watch_cwd.enabled then
			-- Fallback when not in a git repo to avoid noisy recursive watching
			log("Not a git repo; falling back to file watchers", vim.log.levels.DEBUG)
		end
		FileWatcher.file_watchers(terminal_name, reload_callback)
	end
end

---Set up file watchers for all files in the current tabpage
---@param terminal_name string The name of the terminal
---@param reload_callback function Function to call when files change
function FileWatcher.file_watchers(terminal_name, reload_callback)
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
end

---Unified setup for file watching with optional diffing callback
---@param terminal_name string The name of the terminal
function FileWatcher.setup_unified_watching(terminal_name)
	-- Set up file watching for immediate reload
	FileWatcher.setup_watchers(terminal_name, function()
		FileWatcher.reload_changes()
	end)
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
			local level = _notify_info and vim.log.levels.INFO or vim.log.levels.DEBUG
			log(message, level)
		end
	end)
end

-- Returns true if any attached client matches one of the given names
-- and (optionally) supports `textDocument/formatting`.
local function has_client(bufnr, names, require_format_capability)
	local method = require_format_capability and "textDocument/formatting" or nil
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
	if not names or #names == 0 then
		return #clients > 0
	end
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

	local log = function(msg, level)
		if Config.config.trigger_formatting and Config.config.trigger_formatting.notify == false then
			return
		end
		local file = vim.api.nvim_buf_get_name(bufnr)
		file = vim.fn.fnamemodify(file, ":t")
		vim.notify(msg .. ": " .. file, level or vim.log.levels.DEBUG, { title = "FormatOnExternalChange" })
	end

	-- Always asynchronous: conform.nvim → none-ls/null-ls → any LSP
	local ok, conform = pcall(require, "conform")
	if ok then
		log("formatting with conform.nvim")
		conform.format({ bufnr = bufnr, async = true, timeout_ms = timeout, lsp_format = "never" })
		return
	end
	if has_client(bufnr, { "none-ls", "null-ls" }, true) then
		log("formatting with none-ls/null-ls")
		vim.lsp.buf.format({
			bufnr = bufnr,
			async = true,
			timeout_ms = timeout,
			filter = function(c)
				return (c.name == "none-ls" or c.name == "null-ls")
			end,
		})
		return
	elseif has_client(bufnr, {}, true) then
		log("formatting with LSP")
		vim.lsp.buf.format({ bufnr = bufnr, async = true, timeout_ms = timeout })
		return
	else
		log("no formatter attached; skipping", vim.log.levels.DEBUG)
	end
end

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = vim.api.nvim_create_augroup("FormatOnExternalChange", { clear = true }),
	callback = function(args)
		local path = vim.api.nvim_buf_get_name(args.buf)
		local filename = vim.fn.fnamemodify(path, ":t")
		log("Updated: " .. filename, vim.log.levels.DEBUG, { title = "ai-terminal" })
		format_on_external_change(args)
	end,
})

---@param terminal_name string The name of the terminal
---@param reload_callback function Function to call when files change
function FileWatcher.setup_dir_watcher(terminal_name, reload_callback)
	-- Clean up old watchers before setting up new ones
	FileWatcher.cleanup_watchers(terminal_name)
	FileWatcher.init_watchers(terminal_name)

	local watch = vim.uv.new_fs_event()
	if not watch then
		log("Failed to create fs_event watcher", vim.log.levels.ERROR)
		return
	end
	-- Store the directory watcher to prevent garbage collection and allow cleanup
	table.insert(_file_watchers[terminal_name], watch)
	local dir = vim.fn.getcwd()

	-- Helper to get repo root (if any)
	local function get_git_root()
		local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
		if vim.v.shell_error == 0 and root ~= "" then
			return root
		end
		return nil
	end

	local git_root = get_git_root()

	local function relpath(base, path)
		if not base or base == "" or not path or path == "" then
			return path
		end
		-- Normalize: collapse repeated slashes and strip trailing slashes from base
		base = base:gsub("/+", "/"):gsub("/+$", "")
		path = path:gsub("/+", "/")
		if path:sub(1, #base) == base then
			local rest = path:sub(#base + 1)
			if rest:sub(1, 1) == "/" then
				rest = rest:sub(2)
			end
			return rest
		end
		return path
	end

	-- Prepare ignore patterns (globs -> vim regex) once
	local ignore_globs_user = {}
	local ignore_regex_user = {}
	local ignored_cache = {}
	local cfg = (Config.config and Config.config.watch_cwd) or {}
	if type(cfg.ignore) == "table" then
		for _, pat in ipairs(cfg.ignore) do
			if type(pat) == "string" and pat ~= "" then
				local p = tostring(pat)
				-- Trim whitespace
				p = p:gsub("^%s+", ""):gsub("%s+$", "")
				if p ~= "" then
					-- Treat leading "/" as CWD-anchored; `fname` is already relative,
					-- so strip it to avoid mismatches like "/.git/**".
					if p:sub(1, 1) == "/" then
						p = p:sub(2)
					end
					-- If user provided a directory pattern (trailing slash) without a
					-- recursive suffix, expand it to include all descendants.
					-- E.g., ".git/" -> ".git/**" (matches .git and everything under it).
					local also_dir_only = false
					if p:sub(-1) == "/" and p:sub(-2) ~= "**" then
						-- Directory pattern: match the directory itself and all descendants.
						-- Translate "foo/" -> { "foo", "foo/**" }
						p = p .. "**"
						also_dir_only = true
					elseif p:sub(-3) == "/**" then
						-- If user already provided a recursive pattern, also ignore the directory node itself.
						also_dir_only = true
					end

					local ok, reg = pcall(vim.fn.glob2regpat, p)
					if ok and type(reg) == "string" and reg ~= "" then
						table.insert(ignore_globs_user, reg)
						local ok_rx, rx = pcall(vim.regex, reg)
						if ok_rx and rx then
							table.insert(ignore_regex_user, rx)
						end
					end
					if also_dir_only then
						local dir_only = p:sub(1, -4) -- strip trailing "/**"
						local ok2, reg2 = pcall(vim.fn.glob2regpat, dir_only)
						if ok2 and type(reg2) == "string" and reg2 ~= "" then
							table.insert(ignore_globs_user, reg2)
							local ok_rx2, rx2 = pcall(vim.regex, reg2)
							if ok_rx2 and rx2 then
								table.insert(ignore_regex_user, rx2)
							end
						end
					end
				end
			end
		end
	end

	-- Note: We rely on `git check-ignore` as the source of truth
	-- for .gitignore semantics. If we ever need a non-git fallback,
	-- we can reintroduce parsing and use it only when git isn't available.

	local function git_check_ignore(fullpath)
		if not cfg.gitignore or not git_root or not fullpath or fullpath == "" then
			return nil
		end
		if ignored_cache[fullpath] ~= nil then
			return ignored_cache[fullpath]
		end
		-- Use git as the source of truth for .gitignore semantics (handles nested .gitignore, negations, etc.)
		local ok, _ = pcall(function()
			-- Use the list form to avoid shell escaping issues
			vim.fn.system({ "git", "-C", git_root, "check-ignore", "-q", "--", fullpath })
		end)
		if not ok then
			return nil
		end
		if vim.v.shell_error == 0 then
			ignored_cache[fullpath] = true
			return true
		elseif vim.v.shell_error == 1 then
			ignored_cache[fullpath] = false
			return false
		else
			return nil
		end
	end

	local function is_ignored(rel_cwd, rel_root, fullpath)
		-- Prefer checking against git-root relative path for gitignore rules
		if not rel_cwd and not rel_root then
			return false
		end
		-- Fast path: always ignore .git directory and its contents, regardless of git's answer
		local function is_dot_git(path)
			if not path or path == "" then
				return false
			end
			-- Normalize separators and wrap with slashes to match the segment
			local norm = "/" .. path:gsub("\\", "/") .. "/"
			return norm:find("/%.git/") ~= nil
		end
		if is_dot_git(rel_cwd) or is_dot_git(rel_root) then
			return true
		end

		-- Apply user-defined ignore globs (relative to CWD) before asking git
		if rel_cwd and rel_cwd ~= "" and #ignore_regex_user > 0 then
			local s = rel_cwd:gsub("\\", "/")
			for _, rx in ipairs(ignore_regex_user) do
				if rx:match_str(s) then
					return true
				end
			end
		end

		-- Ask git only after user globs and the hard-coded .git exclusion; this covers nested .gitignore and complex rules
		local git_answer = git_check_ignore(fullpath)
		if git_answer ~= nil then
			return git_answer
		end
		return false
	end
	watch:start(dir, { recursive = true }, function(err, fname, events)
		if err then
			return
		end

		vim.schedule(function()
			-- If a concrete file changed, ensure it's present as a buffer
			if type(fname) == "string" and fname ~= "" then
				-- If .gitignore changed, reset cache so new rules take effect
				if fname:match("%.gitignore$") then
					ignored_cache = {}
				end
				-- Skip ignored paths. We match .gitignore rules against the path
				-- relative to the git root (if available) and custom ignores
				-- against the path relative to the current working directory.
				local fullpath = vim.fn.fnamemodify(dir .. "/" .. fname, ":p")
				local rel_root = git_root and relpath(git_root, fullpath) or fname
				if is_ignored(fname, rel_root, fullpath) then
					return
				end
				local stat = vim.uv.fs_stat(fullpath)
				if stat and stat.type == "file" and vim.fn.filereadable(fullpath) == 1 then
					local bufnr = vim.fn.bufnr(fullpath)
					if bufnr == -1 then
						log("calling :badd: " .. fullpath)
						pcall(vim.cmd.badd, { args = { fullpath } })
						bufnr = vim.fn.bufnr(fullpath)
					end

					-- Ensure the buffer is loaded so LSP/filetype autocmds can attach
					if bufnr > 0 and not vim.api.nvim_buf_is_loaded(bufnr) then
						log("calling bufload: " .. fullpath)
						pcall(vim.fn.bufload, bufnr)
						-- Trigger FileChangedShellPost to run any listeners (e.g., formatters) for this file
						pcall(vim.api.nvim_exec_autocmds, "FileChangedShellPost", { buffer = bufnr })
					end
				end
				-- Reload all open buffers after a relevant file change
				reload_callback()
				return
			end
			-- If we don't know the specific file, do a general reload
			reload_callback()
		end)
	end)
end

return FileWatcher
