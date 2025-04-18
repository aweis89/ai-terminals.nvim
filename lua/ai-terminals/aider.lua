local TerminalLib = require("ai-terminals.terminal") -- Require TerminalLib directly
local Aider = {}

---Add a comment above the current line based on user input
---@param prefix string The prefix to add before the user's comment text
---@return nil
function Aider.comment(prefix)
	prefix = prefix or "AI!" -- Default prefix if none provided
	local bufnr = vim.api.nvim_get_current_buf()
	-- toggle aider terminal so we know it's running
	TerminalLib.toggle("aider") -- Open, using name
	TerminalLib.toggle("aider") -- Close (or focus if already open), using name
	local comment_text = vim.fn.input("Enter comment (" .. prefix .. "): ")
	if comment_text == "" then
		return -- Do nothing if the user entered nothing
	end
	local current_line = vim.api.nvim_win_get_cursor(0)[1]

	local cs = vim.bo.commentstring
	local comment_string = (cs and #cs > 0) and cs or "# %s"

	-- Format the comment string
	local formatted_prefix = " " .. prefix .. " " -- Add spaces around the prefix
	local formatted_comment
	if comment_string:find("%%s") then
		formatted_comment = comment_string:format(formatted_prefix .. comment_text)
	else
		-- Handle cases where commentstring might not have %s (less common)
		-- or just prepend if it's a simple prefix like '#'
		formatted_comment = comment_string .. formatted_prefix .. comment_text
	end
	-- Insert the comment above the current line
	vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line - 1, false, { formatted_comment })
	vim.cmd.write() -- Save the file
	vim.cmd.stopinsert() -- Exit insert mode
	TerminalLib.toggle("aider") -- Ensure terminal is focused/open for potential follow-up, using name
end

-- Helper function to send commands to the aider terminal
---@param files string[] List of file paths to add to aider. Paths will be converted to absolute paths.
---@param opts? { read_only?: boolean } Options for the command
function Aider.add_files(files, opts)
	opts = opts or {}
	local command = opts.read_only and "/read-only" or "/add"

	if #files == 0 then
		vim.notify("No files provided to add", vim.log.levels.WARN)
		return
	end

	-- Convert all file paths to absolute paths
	local absolute_files = {}
	for _, file in ipairs(files) do
		table.insert(absolute_files, vim.fn.fnamemodify(file, ":p"))
	end

	local files_str = table.concat(absolute_files, " ")

	-- Ensure the aider terminal is open and get its instance, using name
	local term = TerminalLib.open("aider")
	-- Use the TerminalLib send function
	TerminalLib.send(command .. " " .. files_str .. "\n", { term = term, submit = true })
end

-- Helper function to add listed buffers to the aider terminal
function Aider.add_buffers()
	vim.schedule(function() -- Defer execution slightly
		local files = {}

		for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
			local bnr = bufinfo.bufnr
			-- Check if buffer is valid, loaded, modifiable, and not the terminal buffer itself
			local filename = vim.api.nvim_buf_get_name(bnr)
			if vim.api.nvim_buf_is_valid(bnr) and bufinfo.loaded and vim.bo[bnr].modifiable then
				table.insert(files, filename)
			end
		end
		-- Call add_files directly (no TerminalLib to pass)
		Aider.add_files(files)
	end)
end

return Aider
