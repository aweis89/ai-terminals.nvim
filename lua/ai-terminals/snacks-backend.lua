local DiffLib = require("ai-terminals.diff")
local FileWatcher = require("ai-terminals.fswatch")

---@class SnacksTerminalObject : TerminalObject
---@field win snacks.win The snacks window object
local SnacksTerminalObject = {}
SnacksTerminalObject.__index = SnacksTerminalObject

function SnacksTerminalObject.new(win, terminal_name)
	local obj = setmetatable({
		backend = "snacks",
		terminal_name = terminal_name,
		buf = win.buf,
		win = win,
	}, SnacksTerminalObject)
	return obj
end

function SnacksTerminalObject:send(text, opts)
	opts = opts or {}
	local job_id = vim.b[self.buf].terminal_job_id
	if not job_id then
		vim.notify("No terminal job id found", vim.log.levels.ERROR)
		return
	end

	local text_to_send = text
	if text:find("\n") then
		text_to_send = self:_multiline(text)
	end

	local success = vim.fn.chansend(job_id, text_to_send)
	if success == 0 then
		vim.notify(
			string.format(
				"Failed to send text to terminal (job_id: %s, content length: %d). Possible causes: terminal is closed or invalid job ID.",
				tostring(job_id),
				#text_to_send
			),
			vim.log.levels.ERROR
		)
		return
	end

	if opts.submit then
		local success_nl = vim.fn.chansend(job_id, "\n")
		if success_nl == 0 then
			vim.notify("Failed to send newline to terminal", vim.log.levels.ERROR)
			return
		end
	end

	if opts.insert_mode then
		vim.cmd("startinsert")
	end
end

function SnacksTerminalObject:show()
	self.win:show()
end

function SnacksTerminalObject:hide()
	self.win:hide()
end

function SnacksTerminalObject:focus()
	self.win:focus()
end

function SnacksTerminalObject:close()
	self.win:close({ buf = true })
end

function SnacksTerminalObject:is_floating()
	return self.win:is_floating()
end

function SnacksTerminalObject:_multiline(text)
	local esc = "\27"
	local prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	return prefix .. text .. postfix
end

---@class SnacksBackend : TerminalBackend
local SnacksBackend = {
	name = "snacks",
}

-- Keep track of buffers where autocommands have been registered
local registered_buffers = {}

---Resolve the command string from configuration (can be string or function).
---@param cmd_config string|function The command configuration value.
---@return string|nil The resolved command string, or nil if the type is invalid.
function SnacksBackend:resolve_command(cmd_config)
	if type(cmd_config) == "function" then
		return cmd_config()
	elseif type(cmd_config) == "string" then
		return cmd_config
	else
		vim.notify("Invalid 'cmd' type", vim.log.levels.ERROR)
		return nil
	end
end

---Helper to resolve term config, position, and dimensions
---@param terminal_name string The name of the terminal
---@param position string|nil Optional override position.
---@return table?, string?, table?
function SnacksBackend:_resolve_term_details(terminal_name, position)
	local config = require("ai-terminals.config").config
	local term_config = config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, nil, nil
	end

	local resolved_position = position or config.default_position
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }
	if not valid_positions[resolved_position] then
		vim.notify(
			"Invalid terminal position: "
				.. tostring(resolved_position)
				.. ". Falling back to default: "
				.. config.default_position,
			vim.log.levels.WARN
		)
		resolved_position = config.default_position
	end

	local dimensions = config.window_dimensions[resolved_position]
	return term_config, resolved_position, dimensions
end

---Resolve terminal command and options based on name and position.
---@param terminal_name string The name of the terminal.
---@param position string|nil Optional override position.
---@return string?, table? Resolved command string and options table, or nil, nil on failure.
function SnacksBackend:_resolve_terminal_options(terminal_name, position)
	local term_config, resolved_position, dimensions = self:_resolve_term_details(terminal_name, position)
	if not term_config then
		return nil, nil
	end

	local cmd_str = self:resolve_command(term_config.cmd)
	if not cmd_str then
		return nil, nil
	end

	local config = require("ai-terminals.config").config
	---@type snacks.terminal.Opts
	local opts = {
		cwd = vim.fn.getcwd(),
		env = config.env,
		interactive = true,
		win = {
			position = resolved_position,
			height = dimensions and dimensions.height,
			width = dimensions and dimensions.width,
		},
	}
	return cmd_str, opts
end

---Common setup steps after a terminal is created or retrieved.
---@param win snacks.win The terminal window object.
---@param terminal_name string The name of the terminal.
---@return SnacksTerminalObject
function SnacksBackend:_after_terminal_creation(win, terminal_name)
	if not win or not win.buf then
		vim.notify("Invalid terminal object in _after_terminal_creation", vim.log.levels.WARN)
		return nil
	end

	vim.b[win.buf].term_title = terminal_name
	local term_obj = SnacksTerminalObject.new(win, terminal_name)
	self:register_autocmds(term_obj)
	return term_obj
end

function SnacksBackend:toggle(terminal_name, position)
	local cmd_str, opts = self:_resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil
	end

	local win = Snacks.terminal.toggle(cmd_str, opts)
	if not win then
		vim.notify("Unable to toggle terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end

	return self:_after_terminal_creation(win, terminal_name)
end

function SnacksBackend:focus(term)
	if term and term.win then
		term.win:focus()
		return
	end

	local terms = Snacks.terminal.list()
	if #terms == 1 then
		terms[1]:focus()
		return
	end
	for _, term in ipairs(terms) do
		if term:is_floating() then
			term:focus()
			return
		end
	end
	vim.notify("No open terminal windows found to focus", vim.log.levels.ERROR)
end

function SnacksBackend:get(terminal_name, position)
	local cmd_str, opts = self:_resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil, false
	end

	local win, created = Snacks.terminal.get(cmd_str, opts)
	if not win then
		vim.notify("Unable to get terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil, false
	end

	local term_obj = self:_after_terminal_creation(win, terminal_name)
	return term_obj, created
end

function SnacksBackend:open(terminal_name, position, callback)
	local cmd_str, opts = self:_resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil, false
	end

	local win, created = Snacks.terminal.get(cmd_str, opts)
	if not win then
		vim.notify("Unable to open terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil, false
	end

	local term_obj = self:_after_terminal_creation(win, terminal_name)
	term_obj:show()

	if callback then
		if created then
			vim.defer_fn(function()
				callback(term_obj)
			end, 1000)
		else
			callback(term_obj)
		end
	end
	return term_obj, created or false
end

function SnacksBackend:destroy_all()
	local terms = Snacks.terminal.list()
	for _, term in ipairs(terms) do
		term:close({ buf = true })
	end
end

function SnacksBackend:send(text, opts)
	opts = opts or {}
	if opts.term then
		opts.term:send(text, opts)
	else
		-- Fallback to current buffer
		local job_id = vim.b.terminal_job_id
		if not job_id then
			vim.notify("No terminal job id found", vim.log.levels.ERROR)
			return
		end

		local text_to_send = text
		if text:find("\n") then
			local esc = "\27"
			local prefix = esc .. "[200~"
			local postfix = esc .. "[201~"
			text_to_send = prefix .. text .. postfix
		end

		local success = vim.fn.chansend(job_id, text_to_send)
		if success == 0 then
			vim.notify("Failed to send text to terminal", vim.log.levels.ERROR)
			return
		end

		if opts.submit then
			local success_nl = vim.fn.chansend(job_id, "\n")
			if success_nl == 0 then
				vim.notify("Failed to send newline to terminal", vim.log.levels.ERROR)
			end
		end
	end
end

function SnacksBackend:reload_changes()
	FileWatcher.reload_changes()
end

function SnacksBackend:register_autocmds(term)
	if not term or not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
		vim.notify("Invalid terminal or buffer provided for autocommand registration.", vim.log.levels.ERROR)
		return
	end

	local bufnr = term.buf
	if registered_buffers[bufnr] then
		return -- Already registered
	else
		registered_buffers[bufnr] = true
	end

	local config = require("ai-terminals.config").config

	-- Set up file watching for immediate reload
	FileWatcher.setup_watchers(term.terminal_name)

	-- Set up diffing pre-sync if enabled (backend-specific responsibility)
	if config.enable_diffing then
		DiffLib.pre_sync_code_base()

		local group_name = "AITerminalSync_" .. bufnr
		vim.api.nvim_create_augroup(group_name, { clear = true })
		vim.api.nvim_create_autocmd("BufEnter", {
			group = group_name,
			buffer = bufnr,
			callback = DiffLib.pre_sync_code_base,
			desc = "Sync code base backup on entering AI terminal window",
		})
	end
end

return SnacksBackend
