local Term = {}

-- Backend implementations
local backends = {
	snacks = nil, -- Will be loaded lazily
	tmux = nil, -- Will be loaded lazily
}

---Get the active backend based on configuration
---@return table|nil The backend implementation
local function get_backend()
	local config = require("ai-terminals.config").config
	local backend_name = config.backend or "snacks"

	-- Load backend lazily
	if not backends[backend_name] then
		if backend_name == "snacks" then
			local ok, snacks_backend = pcall(require, "ai-terminals.snacks-backend")
			if not ok then
				vim.notify("Failed to load snacks backend: " .. snacks_backend, vim.log.levels.ERROR)
				return nil
			end
			backends.snacks = snacks_backend
		elseif backend_name == "tmux" then
			local ok, tmux_backend = pcall(require, "ai-terminals.tmux-backend")
			if not ok then
				vim.notify("Failed to load tmux backend: " .. tmux_backend, vim.log.levels.ERROR)
				return nil
			end
			backends.tmux = tmux_backend
		else
			vim.notify("Unknown terminal backend: " .. backend_name, vim.log.levels.ERROR)
			return nil
		end
	end

	return backends[backend_name]
end

---Resolve the command string from configuration (can be string or function).
---@param cmd_config string|function The command configuration value.
---@return string|nil The resolved command string, or nil if the type is invalid.
function Term.resolve_command(cmd_config)
	local backend = get_backend()
	if not backend then
		return nil
	end
	return backend:resolve_command(cmd_config)
end

-- Public API - delegates to active backend

function Term.toggle(terminal_name, position)
	local backend = get_backend()
	if not backend then
		return nil
	end
	return backend:toggle(terminal_name, position)
end

function Term.focus(term)
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:focus(term)
end

function Term.get(terminal_name, position)
	local backend = get_backend()
	if not backend then
		return nil, false
	end
	return backend:get(terminal_name, position)
end

function Term.get_hidden(terminal_name, position)
	local backend = get_backend()
	if not backend then
		return nil, false
	end
	-- Fall back to regular get if backend doesn't support get_hidden
	if backend.get_hidden then
		return backend:get_hidden(terminal_name, position)
	else
		return backend:get(terminal_name, position)
	end
end

function Term.open(terminal_name, position, callback)
	local backend = get_backend()
	if not backend then
		return nil, false
	end
	return backend:open(terminal_name, position, callback)
end

function Term.destroy_all()
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:destroy_all()
end

function Term.send(text, opts)
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:send(text, opts)
end

function Term.run_command_and_send_output(cmd, opts)
	if cmd == "" or cmd == nil then
		local cwd = vim.fn.getcwd()
		local home = vim.fn.expand("~")
		local display_cwd = cwd
		if string.find(cwd, home .. "/", 1, true) == 1 then
			display_cwd = "~/" .. string.sub(cwd, string.len(home) + 2)
		elseif cwd == home then
			display_cwd = "~"
		end
		local prompt = string.format("Shell (in %s)", display_cwd)
		cmd = vim.fn.input(prompt, "", "shellcmd")
	end
	if cmd == "" then
		vim.notify("No command entered.", vim.log.levels.WARN)
		return
	end

	local stdout_lines = {}
	local stderr_lines = {}

	-- Use the shell command approach from tmux backend for consistency
	local job_cmd = cmd
	if type(cmd) == "string" then
		job_cmd = { vim.o.shell, "-c", cmd }
	end

	vim.fn.jobstart(job_cmd, {
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

				-- Delegate terminal opening and message sending to backend
				local backend = get_backend()
				if not backend then
					vim.notify("No backend available to send command output", vim.log.levels.ERROR)
					return
				end

				if opts and opts.terminal_name then
					Term.open(opts.terminal_name, nil, function(term)
						if term then
							Term.send(message_to_send, { term = term, submit = opts.submit or false })
							Term.focus(term)
						end
					end)
				elseif opts and opts.term then
					Term.send(message_to_send, opts)
				elseif vim.b.terminal_job_id then
					-- For snacks backend fallback
					Term.send(message_to_send, opts)
					vim.notify("Command exit code and output sent to terminal.", vim.log.levels.INFO)
				else
					vim.notify(
						"Current buffer is not an active AI terminal and no terminal name provided. "
							.. "Cannot send command exit code and output.",
						vim.log.levels.ERROR
					)
				end
			end)
		end,
	})
end

function Term.reload_changes()
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:reload_changes()
end

function Term.register_autocmds(term)
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:register_autocmds(term)
end

function Term.resolve_terminal_options(terminal_name, position)
	local backend = get_backend()
	if not backend then
		return nil, nil
	end
	return backend:_resolve_terminal_options(terminal_name, position)
end

return Term
