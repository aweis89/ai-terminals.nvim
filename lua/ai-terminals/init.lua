local M = {}

local AiderLib = require("ai-terminals.aider")
local DiagnosticsLib = require("ai-terminals.diagnostics")
local TerminalLib = require("ai-terminals.terminal")
local DiffLib = require("ai-terminals.diff")
local ConfigLib = require("ai-terminals.config")
local SelectionLib = require("ai-terminals.selection")

-- Conditionally load snacks based on backend configuration
local function ensure_snacks_loaded()
	local config = ConfigLib.config
	if not config.backend or config.backend == "snacks" then
		require("snacks") -- Load snacks.nvim for annotations
	end
end

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
							local config = ConfigLib.config
							if config.backend == "tmux" then
								-- For tmux backend, we can't easily close individual terminals
								-- since they don't map to vim buffers in the same way
								vim.notify("Terminal close not supported for tmux backend", vim.log.levels.WARN)
							else
								local term = Snacks.terminal.for_buf(ev.buf)
								if term then
									term:close()
								end
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
				visual_selection_text = M.get_visual_selection_with_header(0, term_name) -- 0 for current buffer
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
			M.send_term(term_name, message_to_send, { submit = submit_prompt, focus = true }) -- Use the configured submit value
		end, { desc = description })

		::continue:: -- Label for goto
	end
end

---Setup function to merge user configuration with defaults and create keymaps.
---@param user_config ConfigType|nil
function M.setup(user_config)
	ConfigLib.config = vim.tbl_deep_extend("force", ConfigLib.config, user_config or {})

	-- Ensure the appropriate backend is loaded
	ensure_snacks_loaded()

	-- Validate tmux backend requirements
	if ConfigLib.config.backend == "tmux" then
		if not vim.env.TMUX then
			vim.notify("Warning: tmux backend selected but not running in tmux session", vim.log.levels.WARN)
		end

		-- Setup tmux-toggle-popup with our configuration
		local ok, tmux_popup = pcall(require, "ai-terminals.vendor.tmux-toggle-popup")
		if not ok then
			vim.notify("Error: tmux backend files are missing or corrupted", vim.log.levels.ERROR)
		else
			-- Initialize tmux-toggle-popup with our tmux config
			local tmux_config = ConfigLib.config.tmux or {}
			-- Enable debug logging to troubleshoot tmux issues
			tmux_config.log_level = vim.log.levels.DEBUG
			local setup_ok, _ = pcall(tmux_popup.setup, tmux_config)
			if not setup_ok then
				vim.notify("Warning: Failed to setup tmux backend", vim.log.levels.WARN)
			end
		end
	end

	setup_prompt_keymaps() -- Create keymaps after config is merged
	setup_terminal_keymaps() -- Setup terminal-specific keymaps
end

---Create or toggle a terminal by name with specified position (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil
---@return snacks.win|nil
function M.toggle(terminal_name, position)
	local term
	if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		M.open(terminal_name, nil, function(term)
			local selection = M.get_visual_selection_with_header(0, terminal_name)
			if selection then
				M.send(selection, { term = term, insert_mode = true })
			end
			M.focus(term)
		end)
	else
		term = TerminalLib.toggle(terminal_name, position)
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
		selection = M.get_visual_selection_with_header(0, terminal_name)
	end
	local term, created = TerminalLib.get(terminal_name, position)
	if selection and term then
		if created then
			-- Defer send and focus to allow the terminal to initialize
			vim.defer_fn(function()
				M.send(selection, { term = term, insert_mode = true })
				M.focus(term)
			end, 100) -- 100ms delay
		else
			-- If terminal already exists, send and focus immediately
			M.send(selection, { term = term, insert_mode = true })
			M.focus(term)
		end
	end
	return term, created
end

---@param term snacks.win|nil
function M.focus(term)
	TerminalLib.focus(term)
end

---Open a terminal by name, creating if necessary (delegates to TerminalLib)
---@param terminal_name string The name of the terminal (key in M.config.terminals)
---@param position "float"|"bottom"|"top"|"left"|"right"|nil Optional: Specify position if needed for matching window dimensions
---@return snacks.win?, boolean
function M.open(terminal_name, position, callback)
	local term, created = TerminalLib.open(terminal_name, position, callback)
	if not term then
		return nil, false
	end
	return term, created
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
---@param opts {submit?: boolean, focus?: boolean}|nil Options: `submit` sends a newline after the text if true, `focus` will focus the terminal.
function M.send_term(name, text, opts)
	opts = opts or {}
	local send_opts = {
		term = nil, -- will be set later
		submit = opts.submit or false,
	}

	local term = M.open(name, nil, function(term)
		M.send(text, send_opts)
		if opts.focus then -- Only focus if requested
			M.focus(term)
		end
	end)

	if not term then
		vim.notify("Terminal '" .. name .. "' not found or could not be opened", vim.log.levels.ERROR)
		return
	end
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

---Diagnose tmux backend issues
function M.diagnose_tmux()
	local diagnostics = require("ai-terminals.tmux-diagnostics")
	diagnostics.print_diagnostics()
end

---Execute a shell command and send its stdout to the active terminal buffer.
---@param term_name string
---@param cmd string|nil The shell command to execute.
---@param opts {term?: snacks.win?, submit?: boolean}|nil Options: `term` specifies the target terminal, `submit` sends a newline after the text if true.
---@return nil
function M.send_command_output(term_name, cmd, opts)
	term_name = term_name or vim.b[0].term_title
	opts = opts or {}

	local function send_output(term)
		opts.term = term
		TerminalLib.run_command_and_send_output(cmd, opts) -- Call TerminalLib directly
	end

	local term, created = M.open(term_name, nil, send_output)

	if not term then
		vim.notify(
			"Terminal '" .. term_name .. "' not found or could not be opened for command output",
			vim.log.levels.ERROR
		)
		return
	end

	if not created then
		send_output(term)
	end
end

---Send files to a terminal using its configured file commands
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param files string[] List of file paths to add to terminal. Paths will be converted to absolute paths.
---@param opts? { read_only?: boolean } Options for the command
function M.add_files_to_terminal(terminal_name, files, opts)
	opts = opts or {}

	if #files == 0 then
		vim.notify("No files provided to add", vim.log.levels.WARN)
		return
	end

	-- Get terminal config
	local terminal_config = ConfigLib.config.terminals[terminal_name]
	if not terminal_config then
		vim.notify("Terminal '" .. terminal_name .. "' not found in config", vim.log.levels.ERROR)
		return
	end

	-- Convert all file paths to absolute paths
	local absolute_files = {}
	for _, file in ipairs(files) do
		table.insert(absolute_files, vim.fn.fnamemodify(file, ":p"))
	end

	-- Get file commands config or use defaults
	local file_commands = terminal_config.file_commands or {}
	local template = opts.read_only and file_commands.add_files_readonly or file_commands.add_files
	local submit = file_commands.submit or false

	local command
	-- Use fallback template if none configured
	if not template then
		-- Default fallback: "@<path-a> @<path-b>"
		local formatted_files = {}
		for _, file in ipairs(absolute_files) do
			table.insert(formatted_files, "@" .. file)
		end
		command = table.concat(formatted_files, " ")
	else
		-- Use configured template
		local files_str = table.concat(absolute_files, " ")
		command = string.format(template, files_str)
	end

	-- Send to terminal
	return M.open(terminal_name, nil, function(term)
		M.send(command .. " ", { term = term, submit = submit })
	end)
end

---Add all listed buffers to a terminal
---@param terminal_name string The name of the terminal (key in ConfigLib.config.terminals)
---@param opts? { read_only?: boolean } Options for the command
function M.add_buffers_to_terminal(terminal_name, opts)
	vim.schedule(function() -- Defer execution slightly
		local files = {}

		for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
			local bnr = bufinfo.bufnr
			-- Check if buffer is valid, loaded, modifiable, and not the terminal buffer itself
			local filename = vim.api.nvim_buf_get_name(bnr)
			if vim.api.nvim_buf_is_valid(bnr) and bufinfo.loaded and vim.bo[bnr].modifiable and filename ~= "" then
				table.insert(files, filename)
			end
		end

		M.add_files_to_terminal(terminal_name, files, opts)
	end)
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
---@param terminal_name string|nil
---@return string|nil
function M.get_visual_selection_with_header(bufnr, terminal_name)
	return SelectionLib.get_visual_selection_with_header(bufnr, terminal_name)
end

return M
