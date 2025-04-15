local DiffLib = require("ai-terminals.diff")
local Term = {}

Term.group_name = "AiTermReload" -- Define group name once
-- Ensure the augroup exists and clear it once when the module is loaded
vim.api.nvim_create_augroup(Term.group_name, { clear = true })

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
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
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
		vim.api.nvim_feedkeys("i", "n", false) -- Enter insert mode in the terminal window
	end
end

---Create or toggle a terminal by name with specified position
---@param cmd string|function The command to run in the terminal.
---@param position "float"|"bottom"|"top"|"left"|"right" The position of the terminal window.
---@param dimensions table Dimensions {width, height} for the terminal window.
---@return snacks.win|nil The terminal window object or nil on failure.
function Term.toggle(cmd, position, dimensions)
	local cmd_str = Term.resolve_command(cmd)
	if not cmd_str then
		return nil -- Error already notified by resolve_command
	end
	local term = Snacks.terminal.toggle(cmd_str, {
		env = { id = cmd_str },
		win = {
			position = position,
			height = dimensions.height,
			width = dimensions.width,
		},
	})
	if term then
		Term.register_autocmds(term)
	end
	return term
end

---Get an existing terminal instance by command and position
---@param cmd string|function CMD for terminal
---@param position "float"|"bottom"|"top"|"left"|"right" The position of the terminal window.
---@param dimensions table Dimensions {width, height} for the terminal window.
---@return snacks.win?, boolean? The terminal window object and a boolean indicating if it was found.
function Term.get(cmd, position, dimensions)
	local cmd_str = Term.resolve_command(cmd)
	if not cmd_str then
		return nil -- Error already notified by resolve_command
	end
	-- Assuming Snacks is available globally or required elsewhere
	local term, created = Snacks.terminal.get(cmd_str, {
		env = { id = cmd_str }, -- Use cmd as the identifier
		win = {
			position = position, -- Pass position for potential window matching/creation logic in Snacks
			height = dimensions.height,
			width = dimensions.width,
		},
	})
	if term then
		Term.register_autocmds(term)
	end
	return term, created
end

---Get an existing terminal instance by command and position
---@param cmd string|function CMD for terminal
---@param position "float"|"bottom"|"top"|"left"|"right" The position of the terminal window.
---@param dimensions table Dimensions {width, height} for the terminal window.
---@return snacks.win?, boolean? The terminal window object and a boolean indicating if it was found.
function Term.open(cmd, position, dimensions)
	local cmd_str = Term.resolve_command(cmd)
	if not cmd_str then
		return nil -- Error already notified by resolve_command
	end

	local term = Snacks.terminal.get(cmd_str, {
		env = { id = cmd_str }, -- Use cmd as the identifier
		win = {
			position = position, -- Pass position for potential window matching/creation logic in Snacks
			height = dimensions.height,
			width = dimensions.width,
		},
	})

	if term then
		Term.register_autocmds(term)
		vim.api.nvim_set_current_win(term.win)
	end

	return term, false
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
-- Term.group_name is defined and the group is created at the top of the file

function Term.reload_changes()
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
		vim.notify("Invalid terminal or buffer provided for autocommand registration.", vim.log.levels.WARN)
		return
	end

	local bufnr = term.buf
	if registered_buffers[bufnr] then
		return -- Already registered for this buffer
	end

	local augroup = vim.api.nvim_create_augroup(Term.group_name, { clear = false }) -- Ensure group exists, don't clear existing unrelated autocommands

	-- Call the sync function so it gets executed first time terminal is open
	DiffLib.pre_sync_code_base()

	-- Autocommand to reload buffers when focus leaves this specific terminal buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		buffer = bufnr,
		desc = "Reload buffers when AI terminal " .. bufnr .. " loses focus",
		callback = Term.reload_changes,
	})

	-- Autocommand to run backup when entering this specific terminal window
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = augroup,
		buffer = bufnr,
		desc = "Run backup sync when entering AI terminal window " .. bufnr,
		callback = DiffLib.pre_sync_code_base,
	})

	registered_buffers[bufnr] = true -- Mark as registered
end

return Term
