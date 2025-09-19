# AI Terminals — Architecture

This document describes the overall architecture, data flow, and extension points of the ai-terminals.nvim plugin.

## Purpose

A Neovim plugin that integrates terminal-based AI tools (e.g., Aider, Claude CLI, Goose, aichat) into Neovim via pluggable terminal backends (Snacks or tmux), with helpers for selections, diagnostics, diffing, and file watching.

## Directory Layout and Modules

- Public API and orchestration
  - lua/ai-terminals/init.lua — top-level module exporting the public API (M.*) and setting up keymaps/autocmds.
- Configuration
  - lua/ai-terminals/config.lua — default configuration including terminal definitions, prompts, keymaps, environment, and backend options.
- Backend abstraction and façade
  - lua/ai-terminals/backend-interface.lua — typed interface docs for TerminalBackend and TerminalObject.
  - lua/ai-terminals/terminal.lua — façade that selects the active backend and delegates all terminal operations.
- Backend implementations
  - lua/ai-terminals/snacks-backend.lua — implementation using Snacks.nvim terminals inside Neovim.
  - lua/ai-terminals/tmux-backend.lua — implementation using tmux popups, powered by a vendored tmux-toggle-popup module.
  - lua/ai-terminals/vendor/tmux-toggle-popup/* — vendored tmux popup controller (api/config/utils/log).
- Feature helpers
  - lua/ai-terminals/selection.lua — visual selection extraction and code-fenced formatting with file path headers.
  - lua/ai-terminals/diagnostics.lua — formatting of LSP diagnostics with code context.
  - lua/ai-terminals/fswatch.lua — libuv fs_event watchers and unified buffer reloads via :checktime.
  - lua/ai-terminals/diff.lua — backup (rsync), vimdiff/delta views, close and revert operations.
  - lua/ai-terminals/tmux-diagnostics.lua — simple checks for tmux environment and popup plugin.
- Documentation and tests
  - README.md, TMUX_BACKEND.md — usage and backend docs.
  - tests/selection_spec.lua, tests/terminal_spec.lua — behavior tests for selection and terminal send semantics.

Note: Some helper functions reference an Aider-specific module (aider.lua). Generic file APIs replace most Aider-specific flows.

## Core Abstractions

- Config (config.lua)
  - terminals[name] = { cmd, path_header_template, file_commands?, … }
  - window_dimensions per position (Snacks), backend choice, enable_diffing flag, prompts, prompt_keymaps, terminal_keymaps, tmux config.
  - cmd can be a string or a function evaluated at open-time.

- TerminalBackend interface (backend-interface.lua)
  - Methods: toggle, get, open, focus, send, destroy_all, run_command_and_send_output, reload_changes, register_autocmds, resolve_command.
  - TerminalObject methods: send, show, hide, focus, close, is_floating.

- Terminal façade (terminal.lua)
  - Selects backend based on Config.config.backend (auto “tmux” if in TMUX, else “snacks”).
  - Delegates all API calls to the chosen backend.
  - Provides a consistent API surface for higher-level modules.

## Backends

- Snacks backend (snacks-backend.lua)
  - Uses Snacks.terminal.* API to toggle/get/open windows.
  - Sends text via vim.fn.chansend to the terminal buffer; wraps multiline content with bracketed paste (ESC[200~ … ESC[201~).
  - Marks buffers with b[buf].term_title = terminal_name for terminal-only keymaps.
  - Registers file watchers and optional diff pre-sync.

- Tmux backend (tmux-backend.lua)
  - Uses vendored tmux-toggle-popup to create/manage tmux popup sessions.
  - Resolves a predictable tmux session name (tmux display -p, then normalized).
  - Can create hidden sessions (tmux new-session -d) to pre-warm, and introduces a startup delay when sending to very new sessions.
  - Sends text using tmux load-buffer/paste-buffer and optionally sends Enter for submission.
  - Popup size via width/height percentages; extra flags like close_on_exit, start_directory, title supported.

- Vendored tmux library (vendor/tmux-toggle-popup/*)
  - api.lua: open/save/kill sessions, format session id, parse flags, spawn “tmux run …” commands (via plenary.job).
  - config.lua: defaults and setup/validation.
  - utils.lua: tmux detection, UI size calculations, serialization helpers.
  - log.lua: leveled logging to vim.notify.

## Public API (init.lua)

- Setup and lifecycle
  - M.setup(user_config) — merge config, ensure backend loaded, setup buffer-local keymaps (Snacks), prompt keymaps.
  - M.destroy_all() — close all terminals in the active backend.

- Terminal control
  - M.toggle(name, position?)
  - M.open(name, position?, callback?)
  - M.get(name, position?)
  - M.focus(term?)

- Sending and utilities
  - M.send(text, opts?)
  - M.send_term(name, text, opts?)
  - M.send_command_output(term_name?, cmd?, opts?)
  - M.add_files_to_terminal(terminal_name, files, opts?)
  - M.add_buffers_to_terminal(terminal_name, opts?)
  - M.get_visual_selection(bufnr?)
  - M.get_visual_selection_with_header(bufnr?, terminal_name?)
  - M.send_diagnostics(name, opts?)
  - M.diagnostics() / M.diag_format(diagnostics)

- Diff and backup
  - M.diff_changes(opts?)
  - M.close_diff()
  - M.revert_changes()

- Tmux diagnostics
  - M.diagnose_tmux()

## Key Call Flows

### 1) Toggle/Open/Get/Focus a Terminal

- M.toggle(name, position?)
  - If in visual mode: M.open(name, nil, callback that sends selection with newline).
  - Otherwise: terminal.toggle → backend.toggle.
    - Snacks: Snacks.terminal.toggle(cmd, opts) → buffer marked and autocmds registered.
    - Tmux: tmux_popup.open(session_opts) → mark session new → register autocmds.

- M.open(name, position?, callback?)
  - terminal.open → backend.open.
    - Snacks: Snacks.terminal.get(cmd, opts) → show window → defer callback if first creation.
    - Tmux: backend.get (checks/creates session) → term:show() → defer callback (~300ms).

- M.get(name, position?)
  - terminal.get → backend.get.
    - Snacks: Snacks.terminal.get(cmd, opts) returns window and created boolean.
    - Tmux: has-session? if false, create with _create_hidden_session and return created=true.

- M.focus(term?)
  - Snacks: focus last/floating window or a provided term.
  - Tmux: no-op (tmux popups grab focus when opened).

### 2) Sending Text

- M.send(text, opts?) → terminal.send → backend.send → TerminalObject:send
- M.send_term(name, text, opts?)
  - M.open(name, nil, function(term) term:send(text, { submit = opts.submit }) ; if opts.focus then term:focus() end)

Backend differences:
- Snacks: chansend(job_id, text); bracketed paste for multiline; optional newline.
- Tmux: write to temp file → load-buffer → paste-buffer; simulate cursor moves for newlines; optional Enter; may defer if freshly created.

### 3) Prompt Keymaps

- M.setup registers keymaps from config.prompt_keymaps.
- On trigger:
  - Evaluate prompt (string or function).
  - If include_selection and in visual mode: prefix with Selection.get_visual_selection_with_header(bufnr, term_name).
  - Send via M.send_term(term_name, message, { submit = mapping.submit (default true), focus = true }).

### 4) Visual Selection Formatting

- Selection.get_visual_selection(bufnr?)
  - Uses visual marks < and >, clamps columns, returns sliced lines, filepath, start/end lines.
- Selection.get_visual_selection_with_header(bufnr?, terminal_name?)
  - Wraps selection in a fenced code block with the buffer’s filetype.
  - Prepends a path header using terminal-specific path_header_template (default "# Path: %s").

### 5) Diagnostics

- M.send_diagnostics(term_name, opts?)
  - Diagnostics.get_formatted() returns a string with per-diagnostic blocks:
    - Severity/source/line/column/message, then code context.
    - Context range is either the visual selection or a fixed window around each diagnostic.
  - Sends to terminal, optionally prefixed with opts.prefix and with submit control.

### 6) Run Command and Send Output

- M.send_command_output(term_name?, cmd?, opts?)
  - Prompts for cmd if omitted, runs via jobstart (shell).
  - Captures stdout/stderr; composes:
    - “Command exited with code: N”
    - “Output:” fenced block
    - “Errors:” fenced block
  - Sends via backend.send to the chosen terminal or current terminal buffer (Snacks).

### 7) Add Files/Buffers to Terminals (Generic)

- M.add_files_to_terminal(terminal_name, files, opts?)
  - Convert to paths relative to the current working directory; choose template from terminal_config.file_commands (add_files or add_files_readonly); or fallback “@path1 @path2”.
  - Opens terminal and sends command; submit obeys file_commands.submit (default false).
- M.add_buffers_to_terminal(terminal_name, opts?)
  - Collects buflisted/loaded/modifiable files in current session and delegates to add_files_to_terminal.

### 8) Diffing Lifecycle (Optional)

- Registration:
  - SnacksBackend.register_autocmds(term) and TmuxBackend.register_autocmds(term) call:
    - FileWatcher.setup_unified_watching(terminal_name).
    - If Config.enable_diffing: Diff.pre_sync_code_base() now (and for Snacks, BufEnter on terminal to keep it fresh).

- Diff.pre_sync_code_base()
  - Debounced rsync from cwd to cache backup dir (Diff.BASE_COPY_DIR), respecting Diff.DIFF_IGNORE_PATTERNS.

- M.diff_changes(opts?)
  - If opts.delta:
    - Run “diff -ur [--exclude …] <backup> <cwd>” to check differences; if found, open a new tab and run “diff … | delta”.
    - Mark the terminal buffer and map close key (Config.diff_close_keymap).
  - Else (vimdiff):
    - Run “diff -rq [--exclude …] <cwd> <backup>” async.
    - Parse “Files A and B differ” lines; for each pair:
      - Open a tab; edit A, vsplit B; :diffthis both; set wrap; map close key on both buffers.

- M.close_diff()
  - Diff.close_diff() wipes out diff buffers from backup paths and any delta terminal buffers, closing marked tabs.

- M.revert_changes()
  - Confirmation; rsync from backup → cwd; on success, :checktime to reload buffers.

### 9) File Watching and Reload

- FileWatcher.setup_unified_watching(terminal_name)
  - For all windows in current tab, if buffer has a real file, set libuv fs_event watchers.
  - On changes: FileWatcher.reload_changes() → iterate loaded buffers and :checktime each readable file.
  - Adds VimLeavePre autocmd to stop watchers for the terminal.

## Backend-Specific Notes

- Tmux backend
  - Session naming: tmux display -p with id_format, then string normalization.
  - Startup delay: recently created sessions get a ~1s defer before sending, to ensure tmux is ready.
  - Sending: uses load-buffer/paste-buffer instead of send-keys to avoid command-length limits.
  - Popup sizing: width/height are calculated into tmux percentage args; flags cover border/close-on-exit/start_directory/title, etc.
  - Logging: vendored log.lua logs to vim.notify with configured log level.

- Snacks backend
  - Marks buffers with b[buf].term_title, used to apply terminal-only keymaps on TermOpen.
  - Bracketed paste for multiline to preserve formatting in the REPL-like CLIs.

## Error Handling and UX

- Consistent notifications via vim.notify with levels (DEBUG/INFO/WARN/ERROR).
- Asynchronous jobs schedule UI updates safely (vim.schedule).
- Diff commands check exit codes and show messages accordingly; run-time checks for required tools (e.g., delta).

## Extensibility

- Add a new terminal tool:
  - Extend Config.config.terminals with { cmd, path_header_template, file_commands? }.
- Add a new prompt or keymap:
  - Add to config.prompts and config.prompt_keymaps.
- Add a new backend:
  - Implement the TerminalBackend interface and wire it in terminal.lua’s backend resolver.

## Testing

- tests/selection_spec.lua validates selection slicing and header formatting (filetype handling, column clamping).
- tests/terminal_spec.lua validates send behaviors under the façade (bracketed paste, submit newline, job_id selection, error notifications).

## Dependencies

- Snacks.nvim — terminal windows for the Snacks backend.
- tmux-toggle-popup (vendored) — popup orchestration for tmux backend; requires tmux environment.
- plenary.job — used by the vendored tmux code.
- libuv (vim.uv) fs_event — used for watching file changes and reloading buffers.
