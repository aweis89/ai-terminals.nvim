local Term = require("ai-terminals.terminal") -- Require TerminalLib directly
local Aider = {}

---Add a comment above the current line based on user input
---@param prefix string The prefix to add before the user's comment text
---@return nil
function Aider.comment(prefix)
	prefix = prefix or "AI!" -- Default prefix if none provided
	local bufnr = vim.api.nvim_get_current_buf()

	-- Start terminal in background so it's watching files
	local cmd_str, opts = Term.resolve_terminal_options("aider")
	if not cmd_str then
		return nil -- Error handled in helper
	end
	local term, created = Snacks.terminal.get(cmd_str, opts)
	if not term then
		vim.notify("Unable to toggle terminal: " .. "aider", vim.log.levels.ERROR)
		return nil
	end
	if created then
		term:hide()
	end

	vim.ui.input({ prompt = "Enter comment (" .. prefix .. "): " }, function(comment_text)
		if not comment_text then
			vim.notify("No comment entered")
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
		Term.open("aider") -- Ensure terminal is focused/open for potential follow-up, using name
	end)
end

-- Helper function to send commands to the aider terminal
---@deprecated Use M.add_files_to_terminal("aider", files, opts) instead
---@param files string[] List of file paths to add to aider. Paths will be converted to absolute paths.
---@param opts? { read_only?: boolean } Options for the command
function Aider.add_files(files, opts)
	vim.notify("Aider.add_files is deprecated. Use M.add_files_to_terminal('aider', files, opts) instead.", vim.log.levels.WARN)
	
	-- Get the main module to call the new generic function
	local M = require("ai-terminals")
	M.add_files_to_terminal("aider", files, opts)
end

-- Helper function to add listed buffers to the aider terminal
---@deprecated Use M.add_buffers_to_terminal("aider", opts) instead
function Aider.add_buffers()
	vim.notify("Aider.add_buffers is deprecated. Use M.add_buffers_to_terminal('aider') instead.", vim.log.levels.WARN)
	
	-- Get the main module to call the new generic function
	local M = require("ai-terminals")
	M.add_buffers_to_terminal("aider")
end

return Aider
