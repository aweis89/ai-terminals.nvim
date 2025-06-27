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
	local prefix = esc .. "[200~" -- Start sequence: ESC [ 200 ~
	local postfix = esc .. "[201~" -- End sequence:   ESC [ 201 ~
	-- Concatenate prefix, text, and postfix
	return prefix .. text .. postfix
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
		return -- Don't proceed if sending text failed
	end

	-- Send newline if submit is requested
	if opts.submit then
		local success_nl = vim.fn.chansend(job_id, "\n")
		if success_nl == 0 then
			vim.notify("Failed to send newline to terminal", vim.log.levels.ERROR)
			return
		end
	end
end

---Helper to resolve term config, position, and dimensions
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return table?, string?, table?
local function resolve_term_details(terminal_name, position)
	-- Access config dynamically inside the function
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
		resolved_position = config.default_position -- Fallback
	end

	local dimensions = config.window_dimensions[resolved_position]
	return term_config, resolved_position, dimensions
end

---Resolve terminal command and options based on name and position.
---@param terminal_name string The name of the terminal.
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return string?, table? Resolved command string and options table, or nil, nil on failure.
function Term.resolve_terminal_options(terminal_name, position)
	local term_config, resolved_position, dimensions = resolve_term_details(terminal_name, position)
	if not term_config then
		return nil, nil -- Error already notified by resolve_term_details
	end

	local cmd_str = Term.resolve_command(term_config.cmd)
	if not cmd_str then
		return nil, nil -- Error already notified by resolve_command
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
---@param term snacks.win The terminal window object.
---@param terminal_name string The name of the terminal.
local function _after_terminal_creation(term, terminal_name)
	if not term or not term.buf then
		vim.notify("Invalid terminal object in _after_terminal_creation", vim.log.levels.WARN)
		return
	end
	vim.b[term.buf].term_title = terminal_name
	Term.register_autocmds(term)
end

---Create or toggle a terminal by name with specified position
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return snacks.win|nil The terminal window object or nil on failure.
function Term.toggle(terminal_name, position)
	local cmd_str, opts = Term.resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil -- Error handled in helper
	end

	local term = Snacks.terminal.toggle(cmd_str, opts)
	if not term then
		vim.notify("Unable to toggle terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end
	_after_terminal_creation(term, terminal_name)
	return term
end

---Focus an existing terminal instance by command and position
---@param term snacks.win|nil
function Term.focus(term)
	if term then
		term:focus()
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

---Get an existing terminal instance by name
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@return snacks.win?, boolean? The terminal window object and a boolean indicating if it was created (true) or retrieved (false).
function Term.get(terminal_name, position)
	local cmd_str, opts = Term.resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil, false -- Error handled in helper
	end

	local term, created = Snacks.terminal.get(cmd_str, opts)
	if not term then
		vim.notify("Unable to get terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil
	end
	_after_terminal_creation(term, terminal_name)
	return term, created
end

---Destroy existing terminals (closes windows and stops processes)
function Term.destroy_all()
	local terms = Snacks.terminal.list()
	for _, term in ipairs(terms) do
		term:close({ buf = true })
	end
end

---Open a terminal by name, creating it if it doesn't exist.
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional override position.
---@param callback function(snacks.win)? -- Optional callback to execute after terminal is opened.
---@return snacks.win?, boolean
function Term.open(terminal_name, position, callback)
	local cmd_str, opts = Term.resolve_terminal_options(terminal_name, position)
	if not cmd_str then
		return nil, false -- Error handled in helper
	end

	-- Use Snacks.terminal.get because 'open' should retrieve if exists, or create if not.
	local term, created = Snacks.terminal.get(cmd_str, opts) -- We don't need the 'created' flag here
	if not term then
		vim.notify("Unable to open terminal: " .. terminal_name, vim.log.levels.ERROR)
		return nil, false
	end

	_after_terminal_creation(term, terminal_name)
	term:show() -- Ensure the window is visible after opening/getting

	if callback then
		if created then
			vim.defer_fn(function()
				callback(term)
			end, 2000)
		else
			callback(term)
		end
	end
	return term, created or false
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@param cmd string|nil The shell command to execute.
---@return nil
function Term.run_command_and_send_output(cmd, opts)
	if cmd == "" or cmd == nil then
		local cwd = vim.fn.getcwd()
		local home = vim.fn.expand("~")
		local display_cwd = cwd
		-- Check if cwd starts with home + path separator
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

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then -- Avoid adding empty lines if the command outputs them
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
			vim.schedule(function() -- Schedule to run on the main loop
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

				if opts and opts.term then
					Term.send(message_to_send, opts)
				elseif vim.b.terminal_job_id then
					Term.send(message_to_send, opts)
					vim.notify("Command exit code and output sent to terminal.", vim.log.levels.INFO)
				else
					vim.notify(
						"Current buffer is not an active AI terminal and no terminal options as passed. "
							.. "Cannot send command exit code and output.",
						vim.log.levels.ERROR
					)
				end
			end)
		end,
	})
end

-- Keep track of buffers where autocommands have been registered
local registered_buffers = {}

function Term.reload_changes()
	-- vim.notify("Reloading changes in all buffers", vim.log.levels.DEBUG)
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
		return
	elseif registered_buffers[bufnr] then
		return -- Already registered for this buffer
	else
		registered_buffers[bufnr] = true -- Mark as registered
	end

	-- Access config dynamically inside the function
	local config = require("ai-terminals.config").config

	-- Autocommand to reload buffers when focus leaves this specific terminal buffer
	term:on("BufLeave", Term.reload_changes, { buf = true })

	-- Auto trigger diff on leave if enabled
	if config.enable_diffing and config.show_diffs_on_leave then
		term:on("BufLeave", function()
			-- Schedule the diff_changes call to run soon,
			-- after the BufLeave event processing is finished.
			vim.schedule(function()
				local opts = {}
				if type(config.show_diffs_on_leave) == "table" then
					opts = config.show_diffs_on_leave
				end
				DiffLib.diff_changes(opts)
			end)
		end, { buf = true })
	end

	if config.enable_diffing then
		-- Call the sync function so it gets executed first time terminal is open
		DiffLib.pre_sync_code_base()
	end
	-- Autocommand to run backup when entering this specific terminal window (required for diffing)
	-- term:on doesn't work for splits for some reason
	if config.enable_diffing then
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

return Term
