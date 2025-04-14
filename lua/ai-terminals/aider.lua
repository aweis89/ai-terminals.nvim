local Aider = {}

---Add a comment above the current line based on user input
---@param M table The main ai-terminals module table
---@param prefix string The prefix to add before the user's comment text
---@return nil
function Aider.comment(M, prefix)
	prefix = prefix or "AI!" -- Default prefix if none provided
	local bufnr = vim.api.nvim_get_current_buf()
	-- toggle aider terminal so we know it's running
	M.toggle("aider") -- Open
	M.toggle("aider") -- Close (or focus if already open)
	local comment_text = vim.fn.input("Enter comment (" .. prefix .. "): ")
	if comment_text == "" then
		return -- Do nothing if the user entered nothing
	end
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local comment_string = vim.bo.commentstring or "# %s" -- Default to '#' if not set
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
	M.toggle("aider") -- Ensure terminal is focused/open for potential follow-up
end

-- Helper function to send commands to the aider terminal
---@param M table The main ai-terminals module table
---@param files string[] List of file paths to add to aider
---@param opts? { read_only?: boolean } Options for the command
function Aider.add_files(M, files, opts)
	opts = opts or {}
	local command = opts.read_only and "/read-only" or "/add"

	if #files == 0 then
		vim.notify("No files provided to add", vim.log.levels.WARN)
		return
	end

	local files_str = table.concat(files, " ")

	-- Ensure the aider terminal is open and get its instance
	local term = M.open("aider")
	M.send(command .. " " .. files_str .. "\n", { term = term, submit = true })
end

return Aider
