local DiffLib = require("ai-terminals.diff")
local TmuxTerminal = {}

-- Lazy initialization of tmux-toggle-popup
local tmux_popup = nil
local function get_tmux_popup()
	if not tmux_popup then
		tmux_popup = require("ai-terminals.vendor.tmux-toggle-popup")
		-- Setup is handled in init.lua during plugin setup
	end
	return tmux_popup
end

---Resolve the command string from configuration (can be string or function).
---@param cmd_config string|function The command configuration value.
---@return string|nil The resolved command string, or nil if the type is invalid.
function TmuxTerminal.resolve_command(cmd_config)
	if type(cmd_config) == "function" then
		return cmd_config()
	elseif type(cmd_config) == "string" then
		return cmd_config
	else
		vim.notify("Invalid 'cmd' type", vim.log.levels.ERROR)
		return nil
	end
end

-- Track newly created sessions that need startup delay
local newly_created_sessions = {}

---Mark a session as newly created
---@param session_name string The tmux session name
local function mark_session_as_new(session_name)
	newly_created_sessions[session_name] = vim.loop.hrtime()
	-- Auto-cleanup after 5 seconds
	vim.defer_fn(function()
		newly_created_sessions[session_name] = nil
	end, 5000)
end

---Check if a session was recently created and needs startup delay
---@param session_name string The tmux session name
---@return boolean True if session needs startup delay
local function needs_startup_delay(session_name)
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

---Send text to a tmux popup terminal
---@param text string The text to send
---@param opts {term?: table, submit?: boolean, insert_mode?: boolean}|nil
---@return nil
function TmuxTerminal.send(text, opts)
	opts = opts or {}
	local session = nil

	-- Extract session from term if provided
	if opts.term and opts.term.session then
		session = opts.term.session
	elseif opts.session then
		session = opts.session
	end

	if not session then
		vim.notify("No tmux session provided for sending text", vim.log.levels.ERROR)
		return
	end

	-- Get session name for tmux commands
	local tmux_popup = get_tmux_popup()
	local session_name = tmux_popup.format(session)

	-- Check if session exists and is running
	local check_cmd = string.format("tmux has-session -t %s", vim.fn.shellescape(session_name))
	local exit_code = vim.fn.system(check_cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("Tmux session does not exist: " .. session_name, vim.log.levels.ERROR)
		return
	end

	-- Add delay if this is a newly created session to allow REPL startup
	local function send_text()
		-- Handle multi-line text with paste escape codes
		local text_to_send = text
		if text:find("\n") then
			text_to_send = TmuxTerminal._multiline(text)
		end

		-- Send text to the tmux session
		local escaped_text = vim.fn.shellescape(text_to_send)
		local send_cmd = string.format("tmux send-keys -t %s %s", vim.fn.shellescape(session_name), escaped_text)

		-- Send the text
		local result = vim.fn.system(send_cmd)
		if vim.v.shell_error ~= 0 then
			vim.notify("Failed to send text to tmux session: " .. result, vim.log.levels.ERROR)
			return
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

	if needs_startup_delay(session_name) then
		-- Delay sending to allow REPL startup time (default 1 second)
		local delay_ms = 1000
		vim.defer_fn(send_text, delay_ms)
	else
		send_text()
	end
end

---Helper to resolve term config and options for tmux
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored - tmux uses width/height instead)
---@return table?, table?
local function resolve_tmux_session_options(terminal_name, position)
	local config = require("ai-terminals.config").config
	local term_config = config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, nil
	end

	local cmd_str = TmuxTerminal.resolve_command(term_config.cmd)
	if not cmd_str then
		return nil, nil
	end

	-- Build tmux session options
	local session_opts = {
		name = terminal_name,
		command = { vim.o.shell, "-c", cmd_str },
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

---Create or toggle a tmux popup terminal
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored - tmux uses width/height instead)
---@return table|nil The tmux session object or nil on failure
function TmuxTerminal.toggle(terminal_name, position)
	local term_config, session_opts = resolve_tmux_session_options(terminal_name, position)
	if not term_config then
		return nil
	end

	local tmux_popup = get_tmux_popup()

	-- Check if we're in tmux
	if not vim.env.TMUX then
		vim.notify("Not in a tmux session. Cannot use tmux popup backend.", vim.log.levels.ERROR)
		return nil
	end

	-- Try to open/toggle the popup
	local ok, result = pcall(tmux_popup.open, session_opts)
	if not ok then
		vim.notify("Failed to open tmux popup: " .. tostring(result), vim.log.levels.ERROR)
		return nil
	end

	-- Mark this session as newly created for startup delay
	local session_name = tmux_popup.format(session_opts)
	mark_session_as_new(session_name)

	-- Create a mock terminal object that mimics snacks.win interface
	local mock_term = {
		session = session_opts,
		terminal_name = terminal_name,
		buf = nil, -- tmux doesn't have a vim buffer

		-- Mock methods to match snacks.win interface
		focus = function()
			-- Tmux popup steals focus automatically, nothing needed
		end,

		show = function()
			-- Already shown when opened
		end,

		hide = function()
			-- Close the popup
			tmux_popup.kill(session_opts)
		end,

		close = function()
			tmux_popup.kill(session_opts)
		end,

		is_floating = function()
			return true -- tmux popups are always floating
		end,
	}

	TmuxTerminal._after_terminal_creation(mock_term, terminal_name)
	return mock_term
end

---Focus a tmux popup terminal (no-op since tmux handles focus)
---@param term table|nil
function TmuxTerminal.focus(term)
	-- Tmux popups automatically steal focus when opened
	-- No additional action needed
end

---Get an existing tmux popup terminal or create it
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored - tmux uses width/height instead)
---@return table?, boolean? The terminal object and created flag
function TmuxTerminal.get(terminal_name, position)
	local term_config, session_opts = resolve_tmux_session_options(terminal_name, position)
	if not term_config then
		return nil, false
	end

	local tmux_popup = get_tmux_popup()

	-- Check if session already exists
	local session_name = tmux_popup.format(session_opts)
	local check_cmd = string.format("tmux has-session -t %s", vim.fn.shellescape(session_name))
	local has_session = vim.fn.system(check_cmd)
	local exists = vim.v.shell_error == 0

	if exists then
		-- Session exists, just create mock object
		local mock_term = {
			session = session_opts,
			terminal_name = terminal_name,
			buf = nil,
			focus = function() end,
			show = function()
				tmux_popup.open(session_opts)
			end,
			hide = function()
				tmux_popup.kill(session_opts)
			end,
			close = function()
				tmux_popup.kill(session_opts)
			end,
			is_floating = function()
				return true
			end,
		}
		TmuxTerminal._after_terminal_creation(mock_term, terminal_name)
		return mock_term, false
	else
		-- Create new session
		local new_term = TmuxTerminal.toggle(terminal_name, position)
		return new_term, true
	end
end

---Open a tmux popup terminal
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter (ignored - tmux uses width/height instead)
---@param callback function|nil Optional callback to execute after opening
---@return table?, boolean
function TmuxTerminal.open(terminal_name, position, callback)
	local term, created = TmuxTerminal.get(terminal_name, position)
	if not term then
		return nil, false
	end

	-- Show the popup
	term:show()

	if callback then
		-- For tmux, we need to defer the callback since popup creation is async
		vim.defer_fn(function()
			callback(term)
		end, 100)
	end

	return term, created or false
end

---Destroy all tmux popup terminals
function TmuxTerminal.destroy_all()
	local tmux_popup = get_tmux_popup()

	-- Kill all sessions - this is a bit aggressive but matches the interface
	local ok, result = pcall(tmux_popup.kill_all)
	if not ok then
		vim.notify("Failed to destroy all tmux sessions: " .. tostring(result), vim.log.levels.ERROR)
	end
end

---Execute a shell command and send its stdout to a tmux popup terminal
---@param cmd string|nil The shell command to execute
---@param opts {session?: table, submit?: boolean}|nil Options
---@return nil
function TmuxTerminal.run_command_and_send_output(cmd, opts)
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

	vim.fn.jobstart({ vim.o.shell, "-c", cmd }, {
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

				TmuxTerminal.send(message_to_send, opts)
			end)
		end,
	})
end

-- Keep track of registered terminals for autocmd setup
local registered_terminals = {}

function TmuxTerminal.reload_changes()
	vim.schedule(function()
		vim.cmd.checktime()
	end)
end

---Register autocommands for a tmux terminal (adapted for tmux popup)
---@param term table The mock terminal object
function TmuxTerminal.register_autocmds(term)
	if not term or not term.terminal_name then
		vim.notify("Invalid terminal provided for autocommand registration.", vim.log.levels.ERROR)
		return
	end

	local terminal_name = term.terminal_name
	if registered_terminals[terminal_name] then
		return -- Already registered
	else
		registered_terminals[terminal_name] = true
	end

	local config = require("ai-terminals.config").config

	-- Since tmux popups don't have vim buffers, we can't use BufLeave events
	-- Instead, we'll set up FocusGained to reload buffers when returning to neovim
	local group_name = "AITerminalTmux_" .. terminal_name
	vim.api.nvim_create_augroup(group_name, { clear = true })

	-- Reload buffers when neovim gains focus (returning from tmux popup)
	vim.api.nvim_create_autocmd("FocusGained", {
		group = group_name,
		callback = TmuxTerminal.reload_changes,
		desc = "Reload buffers when returning to neovim from tmux popup",
	})

	-- Auto trigger diff on focus gain if enabled
	if config.enable_diffing and config.show_diffs_on_leave then
		vim.api.nvim_create_autocmd("FocusGained", {
			group = group_name,
			callback = function()
				vim.schedule(function()
					local opts = {}
					if type(config.show_diffs_on_leave) == "table" then
						opts = config.show_diffs_on_leave
					end
					DiffLib.diff_changes(opts)
				end)
			end,
			desc = "Show diffs when returning to neovim from tmux popup",
		})
	end

	-- Set up diffing if enabled
	if config.enable_diffing then
		DiffLib.pre_sync_code_base()
	end
end

---Common setup steps after a terminal is created or retrieved
---@param term table The terminal object
---@param terminal_name string The name of the terminal
function TmuxTerminal._after_terminal_creation(term, terminal_name)
	if not term then
		vim.notify("Invalid terminal object in _after_terminal_creation", vim.log.levels.WARN)
		return
	end
	-- Store terminal name in the mock object
	term.terminal_name = terminal_name
	TmuxTerminal.register_autocmds(term)
end

-- Helper function for multi-line text handling
function TmuxTerminal._multiline(text)
	local esc = "\27"
	local prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	-- Concatenate prefix, text, and postfix
	return prefix .. text .. postfix
end

return TmuxTerminal
