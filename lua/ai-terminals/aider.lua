local Term = require("ai-terminals.terminal") -- Require TerminalLib directly
local Aider = {}

---Add a comment above the current line based on user input
---@param prefix string|nil The prefix to add before the user's comment text
---@return nil
function Aider.comment(prefix)
	prefix = prefix or "AI!" -- Default prefix if none provided

	-- Start terminal in background so it's watching files (don't show popup yet)
	local term, _ = Term.get_hidden("aider")
	if not term then
		vim.notify("Unable to get terminal: aider", vim.log.levels.ERROR)
		return nil
	end

	-- Use helper and perform aider-specific follow-up in callback
	local insert_comment = require("ai-terminals.comment")
	insert_comment(prefix, function()
		Term.open("aider") -- Focus/show aider terminal after insertion
	end)
end

-- Helper function to send commands to the aider terminal
---@deprecated Use M.add_files_to_terminal("aider", files, opts) instead
---@param files string[] List of file paths to add to aider. Paths will be converted to paths relative to the current working directory.
---@param opts? { read_only?: boolean } Options for the command
function Aider.add_files(files, opts)
	vim.notify(
		"Aider.add_files is deprecated. Use M.add_files_to_terminal('aider', files, opts) instead.",
		vim.log.levels.WARN
	)

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
