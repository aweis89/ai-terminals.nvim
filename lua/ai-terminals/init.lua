local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")
local ConfigLib = require("ai-terminals.config")
local SelectionLib = require("ai-terminals.selection")
require("snacks") -- Load snacks.nvim for annotations

local function setup_terminal_keymaps()
	local config = ConfigLib.config
	if not config.terminal_keymaps or #config.terminal_keymaps == 0 then
		return -- No terminal keymaps defined
	end

	-- Create autocmd group for terminal buffer keymaps
	local group_id = vim.api.nvim_create_augroup("AITerminalBufferKeymaps", { clear = true })

	-- Create autocmd to apply keymaps when terminal buffer is created
	vim.api.nvim_create_autocmd("TermOpen", {
		group = group_id,
		pattern = "*",
		callback = function(ev)
			-- Only apply to AI terminal buffers (check if this is our terminal)
			if not vim.b[ev.buf].term_title then
				return
			end

			for _, mapping in ipairs(config.terminal_keymaps) do
				local key = mapping.key
				local action = mapping.action
				local description = mapping.desc or "Terminal keymap"
				local modes = mapping.modes or "t" -- Default to "t" (terminal mode)

				-- Create buffer-local keymap
				if type(action) == "function" then
					vim.keymap.set(modes, key, action, { buffer = ev.buf, desc = description })
				elseif type(action) == "string" then
					-- Handle string actions
					if action == "close" then
						vim.keymap.set(modes, key, function()
							local term = Snacks.terminal.for_buf(ev.buf)
							if term then
								term:close()
							end
						end, { buffer = ev.buf, desc = description })
					else
						-- Default: treat as raw keys to send (if action is a string of keys)
						-- For string actions that are meant to be sent as keys, they should typically be in terminal mode.
						-- If the user wants to map a string action to normal mode in a terminal, they can specify modes = "n".
						vim.keymap.set(modes, key, action, { buffer = ev.buf, desc = description })
					end
				end
			end
		end,
	})
end

local function setup_prompt_keymaps()
	local config = ConfigLib.config
	if not config.prompt_keymaps or not config.prompts then
		return -- No keymaps or prompts defined
	end

	for i, mapping in ipairs(config.prompt_keymaps) do
		local key = mapping.key
		local term_name = mapping.term
		local prompt_key = mapping.prompt
		local description = mapping.desc
		local include_selection_config = mapping.include_selection -- Get configured value (true, false, or nil)

		-- Determine default if nil: defaults to true
		if include_selection_config == nil then
			include_selection_config = true
		end

		-- Determine modes based on include_selection_config
		local keymap_modes
		if include_selection_config then
			keymap_modes = { "n", "v" } -- Normal and Visual mode
		else
			keymap_modes = "n" -- Normal mode only
		end

		-- Validate terminal name
		if not config.terminals or not config.terminals[term_name] then
			vim.notify(
				string.format("AI Terminals: Invalid terminal name '%s' in prompt_keymap #%d (%s)", term_name, i, key),
				vim.log.levels.ERROR
			)
			goto continue -- Skip this mapping
		end

		-- Retrieve the prompt definition (string or function)
		local prompt_definition = config.prompts[prompt_key]
		if not prompt_definition then
			vim.notify(
				string.format("AI Terminals: Invalid prompt key '%s' in prompt_keymap #%d (%s)", prompt_key, i, key),
				vim.log.levels.ERROR
			)
			goto continue -- Skip this mapping
		end

		-- Create the keymap for the determined mode(s)
		vim.keymap.set(keymap_modes, key, function()
			-- Evaluate the prompt definition inside the callback
			local prompt_text -- This will hold the final string prompt
			if type(prompt_definition) == "function" then
				local success, result = pcall(prompt_definition)
				if success and type(result) == "string" then
					prompt_text = result
				else
					vim.notify(
						string.format(
							"AI Terminals: Error evaluating prompt function for keymap #%d (%s): %s",
							i,
							key,
							tostring(result) -- Show error message if pcall failed
						),
						vim.log.levels.ERROR
					)
					return -- Don't proceed if prompt function failed
				end
			elseif type(prompt_definition) == "string" then
				prompt_text = prompt_definition -- Use the string directly
			else
				vim.notify(
					string.format(
						"AI Terminals: Invalid prompt type (%s) for keymap #%d (%s)",
						type(prompt_definition),
						i,
						key
					),
					vim.log.levels.ERROR
				)
				return -- Don't proceed with invalid prompt type
			end

			local message_to_send = prompt_text -- Start with the evaluated prompt
			local visual_selection_text = nil
			local current_vim_mode = vim.fn.mode(1) -- Get full mode string (e.g., "v", "V", "n")
			local submit_prompt = mapping.submit == nil or mapping.submit -- Default submit to true

			-- Re-check include_selection config inside callback for logic clarity
			local should_include_selection = mapping.include_selection
			if should_include_selection == nil then
				should_include_selection = true -- Default to true if not specified
			end

			-- Check if we are actually in visual mode *and* selection should be included
			if string.match(current_vim_mode, "^[vVsS]") and should_include_selection then
				visual_selection_text = M.get_visual_selection_with_header(0) -- 0 for current buffer
				if visual_selection_text and visual_selection_text ~= "" then
					-- Always prefix the selection
					message_to_send = visual_selection_text .. "\n\n" .. prompt_text
				else
					-- No visual selection found, notify and send only the prompt
					vim.notify("No visual selection found. Sending prompt only.", vim.log.levels.INFO)
					-- message_to_send remains the original prompt_text
				end
			else
				-- Not in visual mode, or selection_mode is false.
				-- Just use the base prompt text.
				-- message_to_send remains the original prompt_text
			end

			-- Send the potentially modified message to the specified terminal
			M.send_term(term_name, message_to_send, { submit = submit_prompt }) -- Use the configured submit value

			-- Optional: Focus the terminal after sending
			-- M.focus()
		end, { desc = description })

		::continue:: -- Label for goto
	end
end

---Setup function to merge user configuration with defaults and create keymaps.
---@param user_config ConfigType|nil
function M.setup(user_config)
	ConfigLib.config = vim.tbl_deep_extend("force", ConfigLib.config, user_config or {})
	setup_prompt_keymaps() -- Create keymaps after config is merged
	setup_terminal_keymaps() -- Setup terminal-specific keymaps
end

---Create or toggle a terminal by name with specified position (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	-- Send selection if in visual mode (moved from original M.toggle)
	local selection = nil
	local term
	if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		selection = M.get_visual_selection_with_header(0)
		-- never toggle closed when in visual mode
		term = TerminalLib.open(terminal_name, position)
	else
		term = TerminalLib.toggle(terminal_name, position)
	end

	if selection and term then
		M.send(selection, { term = term, insert_mode = true })
	end
	return term
end

---Get an existing terminal instance by name (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean?
function M.get(terminal_name, position)
	-- Send selection if in visual mode (moved from original M.toggle)
	local selection = nil
	if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		selection = M.get_visual_selection_with_header(0)
	end
	local term, created = TerminalLib.get(terminal_name, position)
	if selection and term then
		M.send(selection, { term = term, insert_mode = true })
	end
	return term, created
end

function M.focus()
	TerminalLib.focus()
end

---Open a terminal by name, creating if necessary (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?
function M.open(terminal_name, position)
	return TerminalLib.open(terminal_name, position)
end

---Compare current directory with its backup and open differing files or show delta.
---@param opts? { diff_func?: function, delta?: boolean } Options table:
---  `diff_func`: A custom function to handle the diff (receives cwd, tmp_dir).
---  `delta`: If true, use `diff -ur | delta` in a terminal instead of vimdiff.
---@return nil
function M.diff_changes(opts)
	DiffLib.diff_changes(opts)
end

---Close and wipe out any buffers from the diff directory (delegates to DiffLib)
---@return nil
function M.close_diff()
	DiffLib.close_diff()
end

---Revert changes using the backup (delegates to DiffLib)
---@return nil
function M.revert_changes()
	DiffLib.revert_changes()
end

---Send text to a terminal (delegates to TerminalLib)
---@param text string The text to send
---@param opts {term?: snacks.win?, submit?: boolean, insert_mode?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true, `insert_mode` enters insert mode after sending if true.
---@return nil
function M.send(text, opts)
	TerminalLib.send(text, opts or {})
end

---Send text to a specific named terminal
---@param name string Terminal name (key in M.config.terminals)
---@param text string text to send
---@param opts {submit?: boolean}|nil Options: `submit` sends a newline after the text if true.
function M.send_term(name, text, opts)
	local term = M.open(name) -- Use M.open which delegates to TerminalLib.open
	if not term then
		vim.notify("Terminal '" .. name .. "' not found or could not be opened", vim.log.levels.ERROR)
		return
	end
	opts = opts or {}
	M.send(text, {
		term = term,
		submit = opts.submit or false,
	})
end

---Send diagnostics to a specific named terminal
---@param name string Terminal name (key in M.config.terminals)
---@param opts {term?: snacks.win?, submit?: boolean, prefix?: string}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true, `prefix` is a string to prepend to the diagnostics.
function M.send_diagnostics(name, opts)
	local diagnostics = M.diagnostics()
	if not diagnostics or #diagnostics == 0 then
		vim.notify("No diagnostics found", vim.log.levels.WARN)
		return
	end
	opts = opts or {}
	local term = opts.term or M.toggle(name)
	if not term then
		vim.notify("Terminal '" .. name .. "' not found or could not be toggled", vim.log.levels.ERROR)
		return
	end
	local submit = opts.submit == true -- Default submit to false unless explicitly true
	local prefix = opts.prefix or "Fix these diagnostic issues:\n"
	M.send(prefix .. diagnostics, { term = term, submit = submit })
end

---Get formatted diagnostics (delegates to DiagnosticsLib)
---@return string|nil
function M.diagnostics()
	return DiagnosticsLib.get_formatted()
end

---Format diagnostics simply (delegates to DiagnosticsLib)
---@param diagnostics table A list of diagnostic items from vim.diagnostic.get()
---@return string[] A list of formatted diagnostic strings
function M.diag_format(diagnostics)
	return DiagnosticsLib.format_simple(diagnostics)
end

---Add a comment above the current line based on user input (delegates to AiderLib)
---@param prefix string The prefix to add before the user's comment text
---@return nil
function M.aider_comment(prefix)
	AiderLib.comment(prefix)
end

-- Helper function to send commands to the aider terminal (delegates to AiderLib)
---@param files string[]|string List of file paths or a single file path to add to aider
---@param opts? { read_only?: boolean } Options for the command
function M.aider_add_files(files, opts)
	if type(files) == "string" then
		files = { files } -- Assign as table if input is string
	end
	AiderLib.add_files(files, opts)
end

-- Add all buffers to aider (delegates to AiderLib)
function M.aider_add_buffers()
	AiderLib.add_buffers()
end

---Destroy all active AI terminals (closes windows and stops processes).
---The next toggle/open will create new instances.
function M.destroy_all()
	TerminalLib.destroy_all()
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param term_name string
---@param cmd string|nil The shell command to execute.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send_command_output(term_name, cmd, opts)
	local term = M.open(term_name) -- Use M.open which delegates
	if not term then
		vim.notify(
			"Terminal '" .. term_name .. "' not found or could not be opened for command output",
			vim.log.levels.ERROR
		)
		return
	end
	opts = opts or {}
	opts.term = opts.term or term
	TerminalLib.run_command_and_send_output(cmd, opts) -- Call TerminalLib directly
end

---Get the current visual selection (delegates to SelectionLib)
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[]|nil lines Selected lines (nil if no selection)
---@return string|nil filepath Filepath of the buffer (nil if no selection)
---@return number start_line Starting line number (0 if no selection)
---@return number end_line Ending line number (0 if no selection)
function M.get_visual_selection(bufnr)
	return SelectionLib.get_visual_selection(bufnr)
end

---Format visual selection with markdown code block and file path (delegates to SelectionLib)
---@param bufnr integer|nil
---@return string|nil
function M.get_visual_selection_with_header(bufnr)
	return SelectionLib.get_visual_selection_with_header(bufnr)
end

return M
