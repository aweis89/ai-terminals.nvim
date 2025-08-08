local M = {
	_ = {
		---@type table<string, number>
		autocmd_to_kill = {},
		---@type table<string, tmux-toggle-popup.SessionIdentifier>
		sessions = {},
	},
}

local config = require("ai-terminals.vendor.tmux-toggle-popup.config")
local log = require("ai-terminals.vendor.tmux-toggle-popup.log")
local utils = require("ai-terminals.vendor.tmux-toggle-popup.utils")
local Job = require("plenary.job")

local AUGROUP_TO_KILL = "tmux-toggle-popup.to-kill"

---@class tmux-toggle-popup.Session: tmux-toggle-popup.ConfigUiSize, tmux-toggle-popup.SessionIdentifier
---@field socket_name string?
---@field command string[]?
---@field env table<string, ((fun (): string) | string)>?
---@field on_init ((fun (session: tmux-toggle-popup.Session, name?: string): string) | string)[]?
---@field before_open ((fun (session: tmux-toggle-popup.Session, name?: string): string) | string)[]?
---@field after_close ((fun (session: tmux-toggle-popup.Session, name?: string): string) | string)[]?
---@field toggle tmux-toggle-popup.ToggleKeymap?
---@field kill boolean?
---@field flags tmux-toggle-popup.Flags?

---@class tmux-toggle-popup.Flags
---@field no_border boolean? --- -B does not surround the popup by a border.
---@field close boolean? --- The -C flag closes any popup on the client.
---@field close_on_exit (true | 'on-success' | false)? --- -E closes the popup automatically when shell-command exits. Two -E closes the popup only if shell-command exited with success.
---@field border string? --- -b sets the type of characters used for drawing popup borders.  When -B is specified, the -b option is ignored.  See popup-border-lines for possible values for border-lines.
---@field target_client string? --- target-client
---@field start_directory ((fun (): string | nil) | string)? --- -d directory
---@field popup_style string? --- -s sets the style for the popup (see “STYLES”).
---@field border_style string? --- -S sets the style for the popup border (see “STYLES”).
---@field target_pane string? --- target-pane
---@field title ((fun (session: tmux-toggle-popup.Session): string) | string)? --- -T is a format for the popup title (see “FORMATS”).

---@class tmux-toggle-popup.ToggleKeymap
---@field key string?
---@field mode ("switch" | "force-close" | "force-open")?

---@class tmux-toggle-popup.SessionIdentifier
---@field name string?
---@field id_format string?

---@param opts tmux-toggle-popup.SessionIdentifier
function M.validate_session_identifier(opts)
	vim.validate({
		name = { opts.name, "string", true },
		id_format = { opts.id_format, "string", true },
	})
end

---@param opts tmux-toggle-popup.Session
function M.validate_session_options(opts)
	vim.validate({
		flags = { opts.flags, "table", true },
		id_format = { opts.id_format, "string", true },
		command = { opts.command, "table", true },
		env = { opts.env, "table", true },
		on_init = { opts.on_init, "table", true },
		before_open = { opts.before_open, "table", true },
		after_close = { opts.after_close, "table", true },
		toggle = { opts.toggle, "table", true },
		kill = { opts.kill, "boolean", true },
		height = { opts.height, { "number", "function" }, true },
		width = { opts.height, { "number", "function" }, true },
	})
end

---@param opts tmux-toggle-popup.Flags
function M.validate_session_flags(opts)
	vim.validate({
		no_border = { opts.no_border, "boolean", true },
		close = { opts.close, "boolean", true },
		close_on_exit = { opts.close_on_exit, { "string", "boolean" }, true },
		border = { opts.border, "string", true },
		target_client = { opts.target_client, "string", true },
		start_directory = { opts.start_directory, { "function", "string" }, true },
		popup_style = { opts.popup_style, "string", true },
		border_style = { opts.border_style, "string", true },
		target_pane = { opts.target_pane, "string", true },
		title = { opts.title, { "function", "string" }, true },
	})
end

---@param opts? tmux-toggle-popup.Session
function M.open(opts)
	local c = config.read()
	---@type tmux-toggle-popup.Session
	opts = vim.tbl_deep_extend("force", {}, c, opts or {})

	M.validate_session_identifier(opts)
	M.validate_session_options(opts)
	M.validate_session_flags(opts.flags)

	local ui = require("ai-terminals.vendor.tmux-toggle-popup.utils").calculate_ui(opts)

	if not require("ai-terminals.vendor.tmux-toggle-popup.utils").is_tmux() then
		log.error("Not running inside tmux, aborting.")

		return
	end

	local session = M.format(opts)

	local args = {
		"--name",
		opts.name,
		"--socket-name",
		opts.socket_name,
		"--id-format",
		utils.escape_id_format(opts.id_format),
		("-w%s%%"):format(ui.width),
		("-h%s%%"):format(ui.height),
	}

	opts.env["NVIM"] = function()
		local sockets = vim.fn.serverlist()
		if sockets and #sockets > 0 then
			return sockets[1]
		end

		return ""
	end

	if opts.toggle and opts.toggle.key then
		vim.list_extend(args, { "--toggle-key", utils.escape(opts.toggle.key) })

		if opts.toggle.mode then
			vim.list_extend(args, { "--toggle-mode", opts.toggle.mode })
		end
	end

	for key, value in pairs(opts.env) do
		---@type string?
		local v = utils.self_or_result(value)

		if vim.list_contains({ "nil", "function" }, type(v)) then
			v = ""
		end

		vim.list_extend(args, { "-e", key .. [[=']] .. v .. [[']] })
	end

	if opts.on_init and #opts.on_init > 0 then
		table.insert(args, "--on-init")
		table.insert(args, utils.tmux_serialize(opts.on_init, opts, session))
	end

	if opts.before_open and #opts.before_open > 0 then
		table.insert(args, "--before-open")
		table.insert(args, utils.tmux_serialize(opts.before_open, opts, session))
	end

	if opts.after_close and #opts.after_close > 0 then
		table.insert(args, "--after-close")
		table.insert(args, utils.tmux_serialize(opts.after_close, opts, session))
	end

	vim.list_extend(args, M.parse_flags(opts))

	if opts.command then
		vim.list_extend(args, opts.command)
	end

	log.debug("Trying to spawn a new tmux command with: %s", args)

	-- Build the full command for debugging
	local full_command = table.concat(vim.list_extend({ "#{@popup-toggle}" }, args), " ")
	vim.notify('Full tmux popup command: tmux run "' .. full_command .. '"', vim.log.levels.DEBUG)

	Job:new({
		command = "tmux",
		args = {
			"run",
			full_command,
		},
		detached = true,
		on_exit = function(j, code)
			if code > 0 then
				-- log.error("Can not spawn tmux command: %s", j:stderr_result())

				return
			end

			log.debug("Finished tmux command: %s", j:result())
		end,
	}):start()

	if not session then
		log.warn("Can not get session name for popup: %s", opts.id_format)

		return
	end

	M._.sessions[session] = opts

	if opts.kill then
		M._.autocmd_to_kill[session] = vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
			group = vim.api.nvim_create_augroup(AUGROUP_TO_KILL, { clear = false }),
			pattern = "*",
			callback = function()
				---@diagnostic disable-next-line: missing-fields
				M.kill_session(session, { detached = true }):start()
			end,
		})
	end
end

--- Aborts the kill process on the matching popup.
---@param opts? tmux-toggle-popup.SessionIdentifier
function M.save(opts)
	local c = config.read()
	---@type tmux-toggle-popup.Session
	opts = vim.tbl_deep_extend("force", {}, c, opts or {})

	M.validate_session_identifier(opts)

	local session = M.format(opts)

	if not session then
		log.warn("Can not get session name for popup: %s", opts.id_format)

		return
	end

	local id = M._.autocmd_to_kill[session]

	if not id then
		return
	end

	vim.api.nvim_del_autocmd(id)

	M._.autocmd_to_kill[session] = nil

	log.info("Saved tmux session: %s", session)
end

--- Aborts all the kill autocommands.
function M.save_all()
	pcall(vim.api.nvim_del_augroup_by_name, AUGROUP_TO_KILL)

	if vim.tbl_isempty(M._.autocmd_to_kill) then
		return
	end

	log.info("Saved tmux sessions: %s", table.concat(vim.tbl_keys(M._.autocmd_to_kill), ", "))

	M._.autocmd_to_kill = {}
end

--- @param opts? tmux-toggle-popup.SessionIdentifier
function M.kill(opts)
	local c = config.read()
	---@type tmux-toggle-popup.Session
	opts = vim.tbl_deep_extend("force", {}, c, opts or {})

	M.validate_session_identifier(opts)

	local session = M.format(opts)

	if not session then
		log.warn("Can not get session name for popup: %s", opts.id_format)

		return
	end

	---@diagnostic disable-next-line: missing-fields
	M.kill_session(session, { detached = true }):start()

	M._.sessions[session] = nil

	log.info("Killed tmux session: %s -> %s", opts.name, session)
end

--- Kills all managed sessions.
function M.kill_all()
	if vim.tbl_isempty(M._.sessions) then
		return
	end

	for _, session in ipairs(vim.tbl_keys(M._.sessions)) do
		---@diagnostic disable-next-line: missing-fields
		M.kill_session(session, { detached = true }):start()
	end

	log.info("Killed tmux sessions: %s", table.concat(vim.tbl_keys(M._.sessions), ", "))

	M._.sessions = {}
end

---@param opts tmux-toggle-popup.SessionIdentifier
---@return string
function M.format(opts)
	local c = config.read()
	---@type tmux-toggle-popup.Session
	opts = vim.tbl_deep_extend("force", {}, c, opts or {})

	log.debug("Trying to interpolate popup name: %s", opts.id_format)

	local result = vim.system({
		"tmux",
		"display",
		"-p",
		opts.id_format,
	}):wait(1000)

	local session = result.stdout:gsub("[\n]", ""):gsub("{popup_name}", opts.name)
	if result.code > 0 or session == "" then
		error(("Can not get session name for popup: %s: %s"):format(opts.name, opts.id_format))
	end

	-- dont know why display -p fixes this formatting errors, maybe figure that out later
	session = session:gsub("[. ]", "_")

	log.debug("Got session name for popup: %s: %s -> %s", opts.name, opts.id_format, session)

	return session
end

---@param opts tmux-toggle-popup.Session
---@return string[]
function M.parse_flags(opts)
	local flags = {}

	if opts.flags.no_border then
		table.insert(flags, "-B")
	end

	if opts.flags.close then
		table.insert(flags, "-C")
	end

	if opts.flags.close_on_exit == "on-failure" then
		table.insert(flags, "-EE")
	elseif opts.flags.close_on_exit == true then
		table.insert(flags, "-E")
	end

	if opts.flags.border then
		vim.list_extend(flags, { "-b", opts.flags.border })
	end

	if opts.flags.target_client then
		vim.list_extend(flags, { "-c", opts.flags.target_client })
	end

	if opts.flags.start_directory then
		if type(opts.flags.start_directory) == "function" then
			opts.flags.start_directory = opts.flags.start_directory()
		end

		if opts.flags.start_directory ~= nil then
			vim.list_extend(flags, { "-d", opts.flags.start_directory })
		end
	end

	if opts.flags.popup_style then
		vim.list_extend(flags, { "-s", opts.flags.popup_style })
	end

	if opts.flags.border_style then
		vim.list_extend(flags, { "-S", opts.flags.border_style })
	end

	if opts.flags.target_pane then
		vim.list_extend(flags, { "-p", opts.flags.target_pane })
	end

	if opts.flags.title then
		if type(opts.flags.title) == "function" then
			opts.flags.title = opts.flags.title(opts)
		end

		if opts.flags.title ~= nil then
			vim.list_extend(flags, { "-T", opts.flags.title })
		end
	end

	return flags
end

---
---@param session string
---@param opts? Job
---@return Job
function M.kill_session(session, opts)
	return Job:new(vim.tbl_extend("force", opts or {}, {
		command = "tmux",
		args = {
			"kill-session",
			"-t",
			session,
		},
	}))
end

return M
