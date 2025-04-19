local ConfigLib = require("ai-terminals.config")
local DiffLib = require("ai-terminals.diff")
local Term = {}

---Resolve the command string from configuration (can be string or function).
---@param cmd_config string|function The command configuration value.
---@return string|nil The resolved command string, or nil if the type is invalid.
function Term.resolve_command(cmd_config)
	if type(cmd_config) == "function" then
		return cmd_config()
	elseif type(cmd_config) == "string" then
		return cmd_config
	else
		vim.notify("Invalid 'cmd' type", vim.log.levels.ERROR)
		return nil
	end
end

---Format text for bracketed paste mode.
---@param text string The text to format.
---@return string Formatted text.
local function multiline(text)
	local esc = "\27"
	local aider_prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local aider_postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	-- Concatenate prefix, text, and postfix
	return aider_prefix .. text .. aider_postfix
end

---Send text to a terminal
---@param text string The text to send
---@param opts {term?: snacks.win?, submit?: boolean, insert_mode?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true, `insert_mode` enters insert mode after sending if true.
---@return nil
function Term.send(text, opts)
	opts = opts or {} -- Ensure opts is a table
	local job_id = vim.b.terminal_job_id
	if opts.term then
		job_id = vim.b[opts.term.buf].terminal_job_id
	end
	if not job_id then
		vim.notify("No terminal job id found", vim.log.levels.ERROR)
		return -- Exit early if no job_id
	end

	local text_to_send = text
	if text:find("\n") then
		text_to_send = multiline(text)
	end

	-- Send the main text
	local ok, err = pcall(vim.fn.chansend, job_id, text_to_send)
	if not ok then
		vim.notify("Failed to send text: " .. tostring(err), vim.log.levels.ERROR)
		return -- Don't proceed if sending text failed
	end

	-- Send newline if submit is requested
	if opts.submit then
		local ok_nl, err_nl = pcall(vim.fn.chansend, job_id, "\n")
		if not ok_nl then
			vim.notify("Failed to send newline: " .. tostring(err_nl), vim.log.levels.ERROR)
		end
	end
	if opts.insert_mode then
		vim.api.nvim_feedkeys("i", "n", false)
	end
end

---Helper to resolve term config, position, and dimensions
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return table?, string?, table?
local function resolve_term_details(terminal_name, position)
	local term_config = ConfigLib.config.terminals[terminal_name]
	if not term_config then
		vim.notify("Unknown terminal name: " .. tostring(terminal_name), vim.log.levels.ERROR)
		return nil, nil, nil
	end

	local resolved_position = position or ConfigLib.config.default_position
	local valid_positions = { float = true, bottom = true, top = true, left = true, right = true }
	if not valid_positions[resolved_position] then
		vim.notify(
			"Invalid terminal position: "
				.. tostring(resolved_position)
				.. ". Falling back to default: "
				.. ConfigLib.config.default_position,
			vim.log.levels.WARN
		)
		resolved_position = ConfigLib.config.default_position -- Fallback
	end

	local dimensions = ConfigLib.config.window_dimensions[resolved_position]
	return term_config, resolved_position, dimensions
end

---Create or toggle a terminal by name with specified position
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return snacks.win|nil The terminal window object or nil on failure.
function Term.toggle(terminal_name, position)
	local term_config, resolved_position, dimensions = resolve_term_details(terminal_name, position)
	if not term_config then
		return nil -- Error already notified by resolve_term_details
	end

	local cmd_str = Term.resolve_command(term_config.cmd)
	if not cmd_str then
		return nil -- Error already notified by resolve_command
	end

	local term = Snacks.terminal.toggle(cmd_str, {
		env = { id = cmd_str },
		win = {
			position = resolved_position,
			height = dimensions and dimensions.height,
			width = dimensions and dimensions.width,
		},
	})
	if not term then
		vim.notify("Unable to get or create terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end
	vim.b[term.buf].term_title = terminal_name
	Term.register_autocmds(term)
	return term
end

---Focus an existing terminal instance by command and position
function Term.focus()
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

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return snacks.win?, boolean? The terminal window object and a boolean indicating if it was found.
function Term.get(terminal_name, position)
	local term_config, resolved_position, dimensions = resolve_term_details(terminal_name, position)
	if not term_config then
		return nil, false
	end

	local cmd_str = Term.resolve_command(term_config.cmd)
	if not cmd_str then
		return nil, false
	end

	local term, created = Snacks.terminal.get(cmd_str, {
		env = { id = cmd_str },
		win = {
			position = resolved_position,
			height = dimensions and dimensions.height,
			width = dimensions and dimensions.width,
		},
	})
	if not term then
		vim.notify("Unable to get or create terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end
	vim.b[term.buf].term_title = terminal_name
	Term.register_autocmds(term)
	return term, created
end

---Destroy existing terminals (closes windows and stops processes)
function Term.destroy_all()
	local terms = Snacks.terminal.list()
	for _, term in ipairs(terms) do
		require("snacks.bufdelete").delete({ buf = term.buf, wipe = true })
	end
end

---Open a terminal by name, creating it if it doesn't exist.
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return snacks.win? The terminal window object or nil on failure.
function Term.open(terminal_name, position)
	local term_config, resolved_position, dimensions = resolve_term_details(terminal_name, position)
	if not term_config then
		return nil
	end

	local cmd_str = Term.resolve_command(term_config.cmd)
	if not cmd_str then
		vim.notify("Invalid terminal command for name: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end

	local term = Snacks.terminal.get(cmd_str, {
		env = { id = cmd_str }, -- Use cmd as the identifier
		win = {
			position = resolved_position,
			height = dimensions and dimensions.height,
			width = dimensions and dimensions.width,
		},
	})
	if not term then
		vim.notify("Unable to get or create terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end

	vim.b[term.buf].term_title = terminal_name
	Term.register_autocmds(term)
	term:show()

	return term
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@param cmd string|nil The shell command to execute.
---@return nil
function Term.run_command_and_send_output(cmd, opts)
	if cmd == "" or cmd == nil then
		cmd = vim.fn.input("Enter command to run: ")
	end
	vim.notify("Running command: " .. cmd, vim.log.levels.INFO)
	local output = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	local message_to_send = string.format("Command exited with code: %d\nOutput:\n```\n%s\n```\n", exit_code, output)

	if exit_code ~= 0 then
		vim.notify(string.format("Command failed with exit code %d: %s", exit_code, cmd), vim.log.levels.WARN)
	end

	if output == "" and exit_code == 0 then
		vim.notify("Command succeeded but produced no output: " .. cmd, vim.log.levels.INFO)
		-- Still send the exit code message
	elseif output == "" and exit_code ~= 0 then
		vim.notify("Command failed and produced no output: " .. cmd, vim.log.levels.WARN)
		-- Still send the exit code message
	end

	-- Check if the current buffer is a terminal buffer managed by this plugin
	-- M.send relies on vim.b.terminal_job_id being set in the current buffer
	if vim.b.terminal_job_id then
		Term.send(message_to_send, opts) -- Use M.send from this module
		vim.notify("Command exit code and output sent to terminal.", vim.log.levels.INFO)
	else
		vim.notify(
			"Current buffer is not an active AI terminal. Cannot send command exit code and output.",
			vim.log.levels.ERROR
		)
	end
end

-- Keep track of buffers where autocommands have been registered
local registered_buffers = {}

function Term.reload_changes()
	vim.notify("Reloading changes in all buffers", vim.log.levels.INFO)
	vim.schedule(function() -- Defer execution slightly
		for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
			local bnr = bufinfo.bufnr
			-- Check if buffer is valid, loaded, modifiable, and not the terminal buffer itself
			if vim.api.nvim_buf_is_valid(bnr) and bufinfo.loaded and vim.bo[bnr].modifiable then
				-- Use pcall to handle potential errors during checktime
				---@diagnostic disable-next-line
				pcall(vim.cmd, bnr .. "checktime")
			end
		end
	end)
end

---Register autocommands for a specific terminal buffer if not already done.
---@param term snacks.win The terminal window object from Snacks.
function Term.register_autocmds(term)
	if not term or not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
		vim.notify("Invalid terminal or buffer provided for autocommand registration.", vim.log.levels.ERROR)
		return
	end

	local bufnr = term.buf
	if not bufnr then
		vim.notify("Invalid terminal or buffer provided for autocommand registration.", vim.log.levels.ERROR)
	end
	if registered_buffers[bufnr] then
		return -- Already registered for this buffer
	end

	-- Autocommand to reload buffers when focus leaves this specific terminal buffer
	term:on("BufLeave", Term.reload_changes, { buf = true })

	if ConfigLib.config.enable_diffing then -- Use ConfigLib here
		-- Call the sync function so it gets executed first time terminal is open
		DiffLib.pre_sync_code_base()
	end
	-- Autocommand to run backup when entering this specific terminal window (required for diffing)
	if ConfigLib.config.enable_diffing then -- Use ConfigLib here
		term:on("BufWinEnter", DiffLib.pre_sync_code_base, { buf = true })
	end

	if bufnr then
		registered_buffers[bufnr] = true -- Mark as registered
	end
end

return Term