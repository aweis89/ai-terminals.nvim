local M = {}

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
function M.send(text, opts)
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
			-- Don't return here, the main text was sent successfully
		end
	else
		vim.api.nvim_feedkeys("i", "n", false) -- Enter insert mode in the terminal window
	end
end

---Create or toggle a terminal by name with specified position
---@param cmd string The command to run in the terminal.
---@param position "float"|"bottom"|"top"|"left"|"right" The position of the terminal window.
---@param dimensions table Dimensions {width, height} for the terminal window.
---@return snacks.win|nil The terminal window object or nil on failure.
function M.toggle(cmd, position, dimensions)
	-- Assuming Snacks is available globally or required elsewhere
	local term = Snacks.terminal.toggle(cmd, {
		env = { id = cmd },
		win = {
			position = position,
			height = dimensions.height,
			width = dimensions.width,
		},
	})
	return term
end

---Get an existing terminal instance by command and position
---@param cmd string The command associated with the terminal.
---@param position "float"|"bottom"|"top"|"left"|"right" The position of the terminal window.
---@param dimensions table Dimensions {width, height} for the terminal window.
---@return snacks.win?, boolean? The terminal window object and a boolean indicating if it was found.
function M.get(cmd, position, dimensions)
	-- Assuming Snacks is available globally or required elsewhere
	return Snacks.terminal.get(cmd, {
		env = { id = cmd }, -- Use cmd as the identifier
		win = {
			position = position, -- Pass position for potential window matching/creation logic in Snacks
			height = dimensions.height,
			width = dimensions.width,
		},
	})
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param cmd string|nil The shell command to execute.
---@return nil
function M.run_command_and_send_output(cmd)
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
		M.send(message_to_send) -- Use M.send from this module
		vim.notify("Command exit code and output sent to terminal.", vim.log.levels.INFO)
	else
		vim.notify(
			"Current buffer is not an active AI terminal. Cannot send command exit code and output.",
			vim.log.levels.ERROR
		)
	end
end

return M
