local DiffLib = require("ai-terminals.diff")
local FileWatcher = require("ai-terminals.fswatch")
-- Forward declarations for tmux popup helper
local tmux_popup
local get_tmux_popup

---@class TmuxTerminalObject : TerminalObject
---@field session table Tmux session configuration
local TmuxTerminalObject = {}
TmuxTerminalObject.__index = TmuxTerminalObject

function TmuxTerminalObject.new(session, terminal_name)
	local obj = setmetatable({
		backend = "tmux",
		terminal_name = terminal_name,
		buf = nil, -- tmux doesn't have a vim buffer
		session = session,
	}, TmuxTerminalObject)
	return obj
end

function TmuxTerminalObject:send(text, opts)
	opts = opts or {}
	local TmuxBackend = require("ai-terminals.tmux-backend")
	local session_name = TmuxBackend._session_name(self.session)

	-- Check if session exists
	if not TmuxBackend._has_session(session_name) then
		vim.notify("Tmux session does not exist: " .. session_name, vim.log.levels.ERROR)
		return
	end

	local function send_text()
		local text_to_send = text
		if text:find("\n") then
			text_to_send = self:_multiline(text)
		end

		-- Use tmux buffers to avoid command line length limits
		local temp_file = vim.fn.tempname()
		local file = io.open(temp_file, "w")
		if not file then
			vim.notify("Failed to create temporary file for text", vim.log.levels.ERROR)
			return
		end
		file:write(text_to_send)
		file:close()

		-- Load text into tmux buffer and paste it
		local load_cmd =
			string.format("tmux load-buffer -t %s %s", vim.fn.shellescape(session_name), vim.fn.shellescape(temp_file))
		local load_result = vim.fn.system(load_cmd)
		if vim.v.shell_error ~= 0 then
			vim.fn.delete(temp_file)
			vim.notify("Failed to load text into tmux buffer: " .. load_result, vim.log.levels.ERROR)
			return
		end

		-- Paste the buffer
		local paste_cmd = string.format("tmux paste-buffer -t %s", vim.fn.shellescape(session_name))
		local paste_result = vim.fn.system(paste_cmd)
		vim.fn.delete(temp_file)

		if vim.v.shell_error ~= 0 then
			vim.notify("Failed to paste text from tmux buffer: " .. paste_result, vim.log.levels.ERROR)
			return
		end

		-- Position cursor at end of text
		local newline_count = select(2, text:gsub("\n", "\n"))
		if newline_count > 0 or string.len(text) > 0 then
			if newline_count > 0 then
				local down_keys = {}
				for i = 1, newline_count do
					table.insert(down_keys, "Down")
				end
				local down_cmd = string.format(
					"tmux send-keys -t %s %s",
					vim.fn.shellescape(session_name),
					table.concat(down_keys, " ")
				)
				vim.fn.system(down_cmd)
			end
		end

		-- Send newline if submit is requested
		if opts.submit then
			local submit_cmd = string.format("tmux send-keys -t %s Enter", vim.fn.shellescape(session_name))
			local submit_result = vim.fn.system(submit_cmd)
			if vim.v.shell_error ~= 0 then
				vim.notify("Failed to send Enter to tmux session: " .. submit_result, vim.log.levels.ERROR)
			end
		end
	end

	-- Check if session needs startup delay
	if TmuxBackend._needs_startup_delay(session_name) then
		vim.notify("Tmux: deferring send 1000ms for new session " .. session_name, vim.log.levels.INFO)
		vim.defer_fn(send_text, 1000)
	else
		send_text()
	end
end

function TmuxTerminalObject:show()
	local TmuxBackend = require("ai-terminals.tmux-backend")
	TmuxBackend._open_popup(self.session)
end

function TmuxTerminalObject:hide()
	local TmuxBackend = require("ai-terminals.tmux-backend")
	TmuxBackend._kill_popup(self.session)
end

function TmuxTerminalObject:focus()
	-- Tmux popups automatically steal focus when opened, no action needed
end

function TmuxTerminalObject:close()
	local TmuxBackend = require("ai-terminals.tmux-backend")
	TmuxBackend._kill_popup(self.session)
end

function TmuxTerminalObject:is_floating()
	return true -- tmux popups are always floating
end

function TmuxTerminalObject:_multiline(text)
	local esc = "\27"
	local prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	return prefix .. text .. postfix
end

---@class TmuxBackend : TerminalBackend
local TmuxBackend = {
	name = "tmux",
}

-- Track newly created sessions that need startup delay
local newly_created_sessions = {}

-- Keep track of registered terminals for autocmd setup
local registered_terminals = {}

-- Lazy initialization of tmux-toggle-popup
tmux_popup = nil
function get_tmux_popup()
	if not tmux_popup then
		tmux_popup = require("ai-terminals.vendor.tmux-toggle-popup")
	end
	return tmux_popup
end

---Format a tmux session name from options
---@param session_opts table
---@return string session_name
function TmuxBackend._session_name(session_opts)
	return get_tmux_popup().format(session_opts)
end

---Open the tmux popup for a session
---@param session_opts table
---@return boolean ok
function TmuxBackend._open_popup(session_opts)
	local ok, result = pcall(get_tmux_popup().open, session_opts)
	if not ok then
		vim.notify("Failed to open tmux popup: " .. tostring(result), vim.log.levels.ERROR)
		return false
	end
	return true
end

---Kill the tmux popup for a session
---@param session_opts table
---@return boolean ok
function TmuxBackend._kill_popup(session_opts)
	local ok, result = pcall(get_tmux_popup().kill, session_opts)
	if not ok then
		vim.notify("Failed to kill tmux popup: " .. tostring(result), vim.log.levels.ERROR)
		return false
	end
	return true
end

---Kill all tmux popups/sessions managed by the plugin
---@return boolean ok
function TmuxBackend._kill_all()
	local ok, result = pcall(get_tmux_popup().kill_all)
	if not ok then
		vim.notify("Failed to destroy all tmux sessions: " .. tostring(result), vim.log.levels.ERROR)
		return false
	end
	return true
end

---Check if a tmux session exists by name
---@param session_name string The tmux session name
---@return boolean True if the session exists
function TmuxBackend._has_session(session_name)
	local check_cmd = string.format("tmux has-session -t %s", vim.fn.shellescape(session_name))
	vim.fn.system(check_cmd)
	return vim.v.shell_error == 0
end

---Mark a session as newly created
---@param session_name string The tmux session name
function TmuxBackend._mark_session_as_new(session_name)
	newly_created_sessions[session_name] = vim.loop.hrtime()
	vim.notify("Tmux: marked session as new: " .. session_name, vim.log.levels.DEBUG)
	-- Auto-cleanup after 5 seconds
	vim.defer_fn(function()
		newly_created_sessions[session_name] = nil
	end, 5000)
end

---Check if a session was recently created and needs startup delay
---@param session_name string The tmux session name
---@return boolean True if session needs startup delay
function TmuxBackend._needs_startup_delay(session_name)
	local creation_time = newly_created_sessions[session_name]
	if not creation_time then
		return false
	end

	local elapsed_ns = vim.loop.hrtime() - creation_time
	local elapsed_ms = elapsed_ns / 1000000

	-- Remove from tracking and return true if less than 2 seconds have passed
	if elapsed_ms < 2000 then
		return true
	else
		newly_created_sessions[session_name] = nil
		return false
	end
end

---Resolve the command string from configuration (can be string or function).
---@param cmd_config string|function The command configuration value.
---@return string|nil The resolved command string, or nil if the type is invalid.
function TmuxBackend:resolve_command(cmd_config)
	if type(cmd_config) == "function" then
		return cmd_config()
	elseif type(cmd_config) == "string" then
		return cmd_config
	else
		vim.notify("Invalid 'cmd' type", vim.log.levels.ERROR)
		return nil
	end
end

---Helper to resolve term config and options for tmux
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored - tmux uses width/height instead)
---@return table?, table?
function TmuxBackend:_resolve_tmux_session_options(terminal_name, position)
	local config = require("ai-terminals.config").config
	local term_config = config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, nil
	end

	local cmd_str = self:resolve_command(term_config.cmd)
	if not cmd_str then
		return nil, nil
	end

	-- Build tmux session options
	local session_opts = {
		name = terminal_name,
		command = { vim.o.shell, "-c", vim.fn.shellescape(cmd_str) },
		env = config.env or {},
	}

	-- Add tmux-specific options
	local tmux_config = config.tmux or {}
	session_opts.width = tmux_config.width or 0.9
	session_opts.height = tmux_config.height or 0.9
	session_opts.flags = tmux_config.flags

	if tmux_config.toggle then
		session_opts.toggle = tmux_config.toggle
	end
	if tmux_config.on_init then
		session_opts.on_init = tmux_config.on_init
	end

	return term_config, session_opts
end

---Resolve terminal command and options based on name and position (compatibility with snacks backend).
---@param terminal_name string The name of the terminal.
---@param position string|nil Optional override position (ignored for tmux).
---@return string?, table? Resolved command string and options table, or nil, nil on failure.
function TmuxBackend:_resolve_terminal_options(terminal_name, position)
	local term_config, session_opts = self:_resolve_tmux_session_options(terminal_name, position)
	if not term_config or not session_opts then
		return nil, nil
	end

	-- Extract the command string from the session options
	local cmd_str = self:resolve_command(term_config.cmd)

	-- Return cmd_str and session_opts to match the interface
	return cmd_str, session_opts
end

---Common setup steps after a terminal is created or retrieved
---@param term TmuxTerminalObject The terminal object
---@param terminal_name string The name of the terminal
function TmuxBackend:_after_terminal_creation(term, terminal_name)
	if not term then
		vim.notify("Invalid terminal object in _after_terminal_creation", vim.log.levels.WARN)
		return
	end
	term.terminal_name = terminal_name
	self:register_autocmds(term)
end

function TmuxBackend:toggle(terminal_name, position)
	local term_config, session_opts = self:_resolve_tmux_session_options(terminal_name, position)
	if not term_config then
		return nil
	end

	local tmux_popup = get_tmux_popup()

	-- Check if we're in tmux
	if not vim.env.TMUX then
		vim.notify("Not in a tmux session. Cannot use tmux popup backend.", vim.log.levels.ERROR)
		return nil
	end

	-- Determine if the session already exists before toggling
	local session_name = TmuxBackend._session_name(session_opts)
	local existed_before = TmuxBackend._has_session(session_name)

	-- Try to open/toggle the popup
	local opened = TmuxBackend._open_popup(session_opts)
	if not opened then
		return nil
	end

	-- Only mark as newly created if it did not exist before
	if not existed_before then
		TmuxBackend._mark_session_as_new(session_name)
		vim.notify("Tmux: marked session as new: " .. session_name, vim.log.levels.DEBUG)
	else
		vim.notify("Tmux: session already existed, not marking as new: " .. session_name, vim.log.levels.DEBUG)
	end

	local term_obj = TmuxTerminalObject.new(session_opts, terminal_name)
	self:_after_terminal_creation(term_obj, terminal_name)
	return term_obj
end

function TmuxBackend:focus(term)
	-- Tmux popups automatically steal focus when opened, no additional action needed
end

function TmuxBackend:get(terminal_name, position)
	local term_config, session_opts = self:_resolve_tmux_session_options(terminal_name, position)
	if not term_config then
		return nil, false
	end

	local tmux_popup = get_tmux_popup()

	-- Check if session already exists
	local session_name = TmuxBackend._session_name(session_opts)
	local exists = TmuxBackend._has_session(session_name)

	if exists then
		-- Session exists, create terminal object
		local term_obj = TmuxTerminalObject.new(session_opts, terminal_name)
		self:_after_terminal_creation(term_obj, terminal_name)
		return term_obj, false
	else
		-- Create new session without showing it (to avoid double popup)
		local new_term = self:_create_hidden_session(terminal_name, session_opts)
		return new_term, true
	end
end

---Get or create a terminal without showing it (hidden session creation)
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored for tmux)
---@return TmuxTerminalObject|nil, boolean Terminal object and whether it was created
function TmuxBackend:get_hidden(terminal_name, position)
	local term_config, session_opts = self:_resolve_tmux_session_options(terminal_name, position)
	if not term_config then
		return nil, false
	end

	local tmux_popup = get_tmux_popup()

	-- Check if session already exists
	local session_name = TmuxBackend._session_name(session_opts)
	local exists = TmuxBackend._has_session(session_name)

	if exists then
		-- Session exists, create terminal object
		local term_obj = TmuxTerminalObject.new(session_opts, terminal_name)
		self:_after_terminal_creation(term_obj, terminal_name)
		return term_obj, false
	else
		-- Create session without showing popup
		return self:_create_hidden_session(terminal_name, session_opts), true
	end
end

---Create a tmux session without showing the popup
---@param terminal_name string The name of the terminal
---@param session_opts table The session options
---@return TmuxTerminalObject|nil Terminal object
function TmuxBackend:_create_hidden_session(terminal_name, session_opts)
	if not vim.env.TMUX then
		vim.notify("Not in a tmux session. Cannot use tmux popup backend.", vim.log.levels.ERROR)
		return nil
	end

	local tmux_popup = get_tmux_popup()
	local session_name = TmuxBackend._session_name(session_opts)

	-- Build the command to run in the session
	local cmd_str = table.concat(session_opts.command, " ")

	-- Create a detached tmux session
	local create_cmd =
		string.format("tmux new-session -d -s %s %s", vim.fn.shellescape(session_name), vim.fn.shellescape(cmd_str))

	local result = vim.fn.system(create_cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to create hidden tmux session: " .. result, vim.log.levels.ERROR)
		return nil
	end

	-- Mark this session as newly created for startup delay
	TmuxBackend._mark_session_as_new(session_name)

	-- Create and return terminal object
	local term_obj = TmuxTerminalObject.new(session_opts, terminal_name)
	self:_after_terminal_creation(term_obj, terminal_name)
	return term_obj
end

function TmuxBackend:open(terminal_name, position, callback)
	local term, created = self:get(terminal_name, position)
	if not term then
		return nil, false
	end

	-- Show the popup
	term:show()

	if callback then
		-- For tmux, we need to defer the callback since popup creation is async
		vim.defer_fn(function()
			callback(term)
		end, 300)
	end

	return term, created or false
end

function TmuxBackend:destroy_all()
	-- Kill all sessions - this is a bit aggressive but matches the interface
	TmuxBackend._kill_all()
end

function TmuxBackend:send(text, opts)
	opts = opts or {}
	if opts.term then
		opts.term:send(text, opts)
	else
		vim.notify("No tmux terminal provided for sending text", vim.log.levels.ERROR)
	end
end

function TmuxBackend:run_command_and_send_output(cmd, opts)
	if cmd == "" or cmd == nil then
		local cwd = vim.fn.getcwd()
		local home = vim.fn.expand("~")
		local display_cwd = cwd
		if string.find(cwd, home .. "/", 1, true) == 1 then
			display_cwd = "~/" .. string.sub(cwd, string.len(home) + 2)
		elseif cwd == home then
			display_cwd = "~"
		end
		local prompt = string.format("Enter command to run (in %s)", display_cwd)
		cmd = vim.fn.input(prompt)
	end
	if cmd == "" then
		vim.notify("No command entered.", vim.log.levels.WARN)
		return
	end

	local stdout_lines = {}
	local stderr_lines = {}

	vim.fn.jobstart({ vim.o.shell, "-c", vim.fn.shellescape(cmd) }, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stdout_lines, line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stderr_lines, line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				local output = table.concat(stdout_lines, "\n")
				local errors = table.concat(stderr_lines, "\n")

				local message_to_send = string.format("Command exited with code: %d\n", exit_code)

				if output ~= "" then
					message_to_send = message_to_send .. "Output:\n```\n" .. output .. "\n```\n"
				end
				if errors ~= "" then
					message_to_send = message_to_send .. "Errors:\n```\n" .. errors .. "\n```\n"
				end

				if exit_code ~= 0 then
					local error_msg = string.format("Command failed with exit code %d: %s", exit_code, cmd)
					if errors ~= "" then
						error_msg = error_msg .. "\nErrors: " .. errors
					end
					vim.notify(error_msg, vim.log.levels.WARN)
				end

				if output == "" and errors == "" and exit_code == 0 then
					vim.notify("Command succeeded but produced no output: " .. cmd, vim.log.levels.INFO)
				elseif output == "" and errors == "" and exit_code ~= 0 then
					vim.notify("Command failed and produced no output: " .. cmd, vim.log.levels.WARN)
				end

				-- Open terminal with callback to send the message
				if opts and opts.terminal_name then
					self:open(opts.terminal_name, nil, function(term)
						if term then
							term:send(message_to_send, { submit = opts.submit or false })
							term:focus()
						end
					end)
				else
					vim.notify("Command exit code and output available, but no terminal name provided.", vim.log.levels.INFO)
				end
			end)
		end,
	})
end

function TmuxBackend:reload_changes()
	FileWatcher.reload_changes()
end

function TmuxBackend:register_autocmds(term)
	if not term or not term.terminal_name then
		vim.notify("Invalid terminal provided for autocommand registration.", vim.log.levels.ERROR)
		return
	end

	local terminal_name = term.terminal_name
	local config = require("ai-terminals.config").config

	-- Set up diffing callback if enabled
	local diff_callback = nil

	-- Use unified file watching
	FileWatcher.setup_unified_watching(terminal_name, diff_callback)

	-- Set up diffing pre-sync if enabled (backend-specific responsibility)
	if config.enable_diffing then
		DiffLib.pre_sync_code_base()
	end
end

return TmuxBackend
