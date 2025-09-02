---@class TerminalBackend
---@field name string Backend name
local TerminalBackend = {}

---Create or toggle a terminal
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter
---@return TerminalObject|nil The terminal object or nil on failure
function TerminalBackend:toggle(terminal_name, position) end

---Get an existing terminal instance or create it
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter
---@return TerminalObject?, boolean? The terminal object and created flag
function TerminalBackend:get(terminal_name, position) end

---Open a terminal, creating if necessary
---@param terminal_name string The name of the terminal
---@param position string|nil Position parameter
---@param callback function|nil Optional callback to execute after opening
---@return TerminalObject?, boolean?
function TerminalBackend:open(terminal_name, position, callback) end

---Focus a terminal
---@param term TerminalObject|nil The terminal object
function TerminalBackend:focus(term) end

---Send text to a terminal
---@param text string The text to send
---@param opts {term?: TerminalObject, submit?: boolean, insert_mode?: boolean}|nil
function TerminalBackend:send(text, opts) end

---Destroy all terminals
function TerminalBackend:destroy_all() end

---Execute a shell command and send its output to a terminal
---@param cmd string|nil The shell command to execute
---@param opts {term?: TerminalObject, submit?: boolean}|nil
function TerminalBackend:run_command_and_send_output(cmd, opts) end

---Reload changes in buffers
function TerminalBackend:reload_changes() end

---Register autocommands for a terminal
---@param term TerminalObject The terminal object
function TerminalBackend:register_autocmds(term) end

---Resolve command string from configuration
---@param cmd_config string|function The command configuration
---@return string|nil The resolved command string
function TerminalBackend:resolve_command(cmd_config) end

---@class TerminalObject
---@field backend string Backend type ("snacks" or "tmux")
---@field terminal_name string Name of the terminal
---@field buf number|nil Buffer number (snacks only)
---@field session table|nil Session info (tmux only)
local TerminalObject = {}

---Send text to this terminal
---@param text string The text to send
---@param opts {submit?: boolean, insert_mode?: boolean}|nil
function TerminalObject:send(text, opts) end

---Show the terminal
function TerminalObject:show() end

---Hide the terminal
function TerminalObject:hide() end

---Focus the terminal
function TerminalObject:focus() end

---Close the terminal
function TerminalObject:close() end

---Check if terminal is floating
---@return boolean
function TerminalObject:is_floating() end

return {
	TerminalBackend = TerminalBackend,
	TerminalObject = TerminalObject,
}
