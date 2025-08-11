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
	local backend = get_backend()
	if not backend then
		return
	end
	return backend:run_command_and_send_output(cmd, opts)
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
