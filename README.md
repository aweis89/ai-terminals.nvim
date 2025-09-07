# 🤖 AI Terminals Neovim Plugin

[![StandWithPalestine](https://raw.githubusercontent.com/Safouene1/support-palestine-banner/master/StandWithPalestine.svg)](https://github.com/Safouene1/support-palestine-banner/blob/master/Markdown-pages/Support.md)
[![test](https://github.com/aweis89/ai-terminals.nvim/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/aweis89/ai-terminals.nvim/actions/workflows/test.yml)
[![lint](https://github.com/aweis89/ai-terminals.nvim/actions/workflows/lint-test.yml/badge.svg?branch=master)](https://github.com/aweis89/ai-terminals.nvim/actions/workflows/lint-test.yml)

<img width="1512" height="949" alt="Screenshot 2025-07-27 at 11 04 59 AM" src="https://github.com/user-attachments/assets/4353b150-78bc-46ac-a1b7-f34b28738305" />

This plugin integrates command-line (CLI) AI coding agents
into Neovim. It provides a unified workflow for interacting with AI assistants
directly in your editor.

## ⚡ Quick Start

Using lazy.nvim:

```lua
{
  "aweis89/ai-terminals.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {}, -- uses sensible defaults; tmux backend auto-selected in tmux
}
```

Try it:

- Visual select code, then: `:lua require("ai-terminals").toggle("claude")`
- Send diagnostics: `:lua require("ai-terminals").send_diagnostics("claude")`
- Add current file: `:lua require("ai-terminals").add_files_to_terminal("claude", { vim.fn.expand("%") })`

### 🚀 Auto Terminal Keymaps

The plugin can automatically generate consistent keymaps for all your configured terminals, eliminating the need to manually create repetitive keymap configurations.

**Configuration:**

```lua
require("ai-terminals").setup({
  auto_terminal_keymaps = {
    prefix = "<leader>at",            -- Base prefix for toggle keymaps (default: "<leader>at")
    terminals = {
      {name = "claude", key = "c"},
      {name = "aider", key = "a"},
      {name = "goose", key = "g"},
      {name = "codex", key = "d", enabled = false}, -- Disabled
    }
  }
})
```

**Generated Keymaps:**

For each enabled terminal, the following keymaps are automatically created:

- `<prefix><key>` - Toggle terminal (normal/visual modes)
- `<leader>ad<key>` - Send diagnostics to terminal (normal/visual modes)
- `<leader>al<key>` - Add current file to terminal (normal mode)
- `<leader>aL<key>` - Add all buffers to terminal (normal mode)
- `<leader>ar<key>` - Run command and send output to terminal (normal mode)

**Example:** With the above configuration, you get:

- `<leader>atc` - Toggle Claude terminal
- `<leader>adc` - Send diagnostics to Claude
- `<leader>alc` - Add current file to Claude
- And the same pattern for `a` (Aider), `g` (Goose), etc.

This feature provides a quick way to get consistent keymaps across all your terminals while maintaining full control over which ones are enabled.

## Public API

- `toggle(name, position?)`: open/toggle a terminal; sends visual selection if active. See `:h ai-terminals.toggle()`.
- `send_term(name, text, opts?)`: send text to a specific named terminal; opts `{ submit?, focus? }`. See `:h ai-terminals.send_term()`.
- `send_diagnostics(name, opts?)`: send formatted diagnostics; opts `{ submit?, prefix? }`. See `:h ai-terminals.send_diagnostics()`.
- `add_files_to_terminal(name, files, opts?)`: add files to terminal. See [Snacks Picker Integration](#-snacks-picker-integration) for picker examples.
- `send_command_output(name, cmd?, opts?)`: run a shell command and send stdout/exit code. See `:h ai-terminals.send_command_output()`.
- `open(name, position?, callback?)`: open a terminal and optionally run a callback with it. See `:h ai-terminals.open()`.
- `setup(opts)`: initialize and merge configuration with sensible defaults. See `:h ai-terminals-configuration`.

## 🔌 Integrations

This plugin integrates with existing command-line AI tools. These CLIs are
optional — install only the ones you plan to use. If you don't intend to use a
given tool, you do not need to install it.

The tools below are preconfigured and ready to use. If they are installed and on
your `PATH`, you can use them immediately. You can also add your own custom
REPLs/CLIs — the plugin communicates via a PTY (Neovim terminal channels) and
 tmux `send-keys`, so any interactive process that reads from the terminal/stdin
will work. See the Configuration section for the `terminals` table to add your
own entries.

Here are links to some of the tools mentioned in the default configuration:

- **Aider:** [Aider](https://aider.chat)
- **Claude Code:** [Claude Code](https://www.anthropic.com/claude-code)
- **Goose:** [Goose](https://github.com/block/goose)
- **Codex:** [Codex](https://github.com/openai/codex)
- **Cursor CLI:** [Cursor CLI](https://cursor.com/en/cli)
- **Gemini CLI:** [Gemini CLI](https://cloud.google.com/gemini/docs/codeassist/gemini-cli)

If you choose to use any of these, make sure they are installed and accessible
in your system's `PATH`.

## 🤔 Motivation

Most Neovim AI plugins implement editor-specific functionality for modifying files
and interacting with LLMs directly. `ai-terminals.nvim` takes a fundamentally
different approach: it focuses on the generic features of pre-existing terminal
CLI tools and integrates them into Neovim by creating a bridge to send data over.

Rather than reimplementing AI functionality within Neovim, this plugin leverages
the robust ecosystems that already exist in terminal-based AI tools. It acts as
a communication layer, providing:

- **Universal CLI Integration:** Works with any terminal-based AI tool that accepts
  stdin — from Aider and Claude CLI to custom scripts and future tools.
- **Data Bridge Architecture:** Creates a bridge between your editor
  context (code selections, diagnostics, file paths) and terminal AI agents.
- **Tool Agnostic:** Instead of locking you into specific AI services, it lets
  you use whatever CLI tools work best for your workflow.
- **stdin as API:** Leverages the universal stdin interface that all CLI tools
  provide, making integration straightforward and reliable.
- **Composable Functions:** Exposes core functions like `send`, `toggle`, and
  `send_diagnostics` that can be combined to create custom workflows - from
  sending Jira tickets to reviewing PRs to running tests and analyzing output.

This plugin is ideal for users who prefer terminal-based AI interaction and
want a single, configurable way to manage them within Neovim.

## ✨ Features

### ⚙️ Generic Features (Works with any terminal-based AI agent)

- **🔌 Configurable Terminal Integration:** Define and manage terminals for
  various AI CLI tools (e.g., Claude, Goose, Cursor, Aider, custom scripts)
  through a simple configuration table. Uses `Snacks` for terminal window
  management.
- **🔃 Automatic File Reloading:** Real-time file reloading using file watchers
  automatically detects and reloads changes made by AI tools instantly,
  ensuring you see the latest modifications as they happen.
- **🔍 Git Integration Recommendation:** For tracking changes made by AI tools,
  we recommend using established git plugins:
  - **[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim):** Shows git
    changes in the sign column and provides inline diff views
  - **[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or
    [snacks.nvim](https://github.com/folke/snacks.nvim) git pickers:** Browse git
    status with custom actions for staging, discarding, or viewing changes
  - **[diffview.nvim](https://github.com/sindrets/diffview.nvim):** Comprehensive
    git diff viewer with side-by-side comparisons
- **📋 Send Visual Selection:** Send the currently selected text (visual mode) to
  the AI terminal, automatically wrapped in a markdown code block with the file
  path and language type included. Each terminal can have a custom path header
  template to format file paths according to the AI tool's preferences (e.g.,
  `@filename` or `` `filename` ``).

- **🩺 Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the
  current buffer or visual selection to the AI terminal
  (`:h ai-terminals.send_diagnostics`), formatted with severity, line/column
  numbers, messages, and the corresponding source code lines.
- **🚀 Run Command and Send Output:** Execute an arbitrary shell command and
  send its standard output and exit code to the active AI terminal
  (`:h ai-terminals.send_command_output`). Useful for running tests, linters,
  or even fetching information from other CLIs (e.g.,
  `jira issue view MYTICKET-123`) and feeding results to the AI.
- **📁 File Management:** Generic functions to add files or buffers to any
  terminal using configurable commands
  (`:h ai-terminals.add_files_to_terminal`,
  `:h ai-terminals.add_buffers_to_terminal`). Works with all terminals, with
  fallback behavior for terminals without specific file commands configured.
- **📝 Prompt Keymaps:** Define custom keymaps (`:h ai-terminals-config-prompt-keymaps`) to
  send pre-defined prompts to specific terminals.
  - **Selection Handling:** Configure whether the keymap includes visual
    selection (`include_selection` option, defaults to `true`).
    - If `true`, the keymap works in normal and visual modes. In visual mode,
      the selection is prefixed to the prompt.
    - If `false`, the keymap works only in normal mode and sends just the prompt.
  - **Submission Control:** Configure whether a newline is sent after the
    prompt (`submit` option, defaults to `true`).
  - **Dynamic Prompts:** Prompt text can be a string or a function that returns
    a string. Functions are evaluated when the keymap is triggered, allowing
    dynamic content (e.g., current file path). See example in
    `:h ai-terminals-configuration`.
- **⌨️ Terminal Keymaps:** Define custom keymaps (`:h ai-terminals-configuration`)
  that only apply within the AI terminal buffers. **Note: Only works with the
  Snacks backend** - tmux terminals cannot execute Neovim functions.
  - **Modes:** Specify which modes the keymap applies to (e.g., "t" for
    terminal mode, "n" for normal mode within the terminal). Defaults to "t".
  - **Actions:** Actions can be functions or strings (e.g., to close the
    terminal or send keys).
- **🚀 Auto Terminal Keymaps:** Automatically generate consistent keymaps for
  all your configured terminals (`:h ai-terminals-configuration`).
  - **Consistent Patterns:** Creates standardized keymaps following a common
    pattern for each terminal (toggle, diagnostics, add files, etc.).
  - **Customizable:** Configure key suffixes, display names, and enable/disable
    individual terminals.
  - **Global Control:** Enable or disable the entire feature with a single flag.

### 📁 File Management

The plugin provides generic file management functions that work with any terminal:

- **📂 Add Files to Terminal:** `add_files_to_terminal(terminal_name, files, opts)`
  - Send files to any terminal using its configured file commands
  - **Terminals with file_commands:** Uses configured templates (e.g., Aider
    uses `/add` or `/read-only` commands with automatic submission)
  - **Other terminals:** Uses fallback `@file1 @file2` format without submission
  - **Options:** `{ read_only = true }` for read-only mode (Aider only)
  
- **📋 Add Buffers to Terminal:** `add_buffers_to_terminal(terminal_name, opts)`
  - Add all currently listed buffers to any terminal
  - Filters out invalid, unloaded, or non-modifiable buffers
  - Uses the same command templates as `add_files_to_terminal`

**Configuration:** Add `file_commands` to your terminal config to customize:

```lua
terminals = {
  my_ai_tool = {
    cmd = "my-ai-cli",
    file_commands = {
      add_files = "load %s",           -- Template for adding files
      add_files_readonly = "view %s",  -- Template for read-only files  
      submit = true,                   -- Whether to auto-submit
    },
  },
}
```

**File Picker Integration:** These functions integrate with file
pickers like Snacks.nvim. You can configure picker actions to add selected files
directly to any terminal with keymaps like `<localleader>aa` for Aider or
`<localleader>cc` for Claude. See the [Snacks Picker Integration](#-snacks-picker-integration)
section below for a complete working example and the
[picker integration recipe](recipes/picker_integration.md) for additional approaches.

### 🔥 Additional Features

The plugin includes some additional convenience functions:

- **💬 Add Comments (Aider):** Insert comments above the current line with a
  custom prefix (e.g., `AI!`, `AI?`) and automatically start the Aider terminal
  if not already running (`:h ai-terminals.aider_comment`).
- **🔄 Diff Changes:** View changes made by AI tools in vim diff tabs.
  Requires `enable_diffing = true` in your config. Each changed file opens in
  its own tab for review. Reopening the terminal window resets the changes.
  See `:help diff-mode` for vim's diff commands like `:diffput` and `:diffget`
  to manipulate changes. Alternatively, use `diff_changes({ delta = true })` to
  view changes with the delta diff viewer in a terminal. Note: Git-based diff
  tools (like gitsigns.nvim or fugitive.vim) provide more feature-rich diff
  management and are recommended for most workflows
  (`:h ai-terminals.diff_changes`).

### 🧼 Format On External Change

Automatically format buffers when the AI agent modifies them.

- Default: disabled
- Provider order when enabled:
  - [conform.nvim](https://github.com/stevearc/conform.nvim) (if installed)
  - none-ls/null-ls
  - any attached LSP
- Formatting runs asynchronously.

Enable via `setup` (auto-detects the provider in the order above):

```lua
require("ai-terminals").setup({
  trigger_formatting = {
    enabled = true,
  },
})
```

Conform first, then LSP fallback (this is the default behavior):

```lua
require("ai-terminals").setup({
  trigger_formatting = { enabled = true, timeout_ms = 5000 },
})
  -- Internally tries: require("conform").format({ lsp_format = "never" })
  -- If conform.nvim isn't available, tries none-ls/null-ls, then any LSP.
```

Note: If conform.nvim is not installed or has no formatter for the filetype, it falls back to any attached LSP automatically. Formatting runs asynchronously (non-blocking).

### 👀 Directory Watch Mode (Optional)

Control what gets watched for external edits made by your AI agent.

- Default: disabled (`watch_cwd.enabled = false`).
- When enabled, the plugin watches the current working directory recursively and will:
  - Load files changed by the agent even if they were not previously open in Neovim.
  - Reload and (if `trigger_formatting.enabled = true`) format those files after edits.
- When disabled, only files that were already open in Neovim are reloaded/formatted.

Enable in setup:

```lua
require("ai-terminals").setup({
  watch_cwd = { enabled = true },      -- watch entire CWD (recursively)
  trigger_formatting = { enabled = true }, -- optional: auto-format on reload
})
```

#### Ignore Patterns (Globs)

You can exclude paths from directory watching using glob patterns.

- Examples: `"**/.git/**"`, `"**/node_modules/**"`, `"**/.venv/**"`, `"**/*.log"`
- Matching is performed against the path relative to your current working directory.
- Ignored files will not be loaded into Neovim nor formatted when changed by the agent.

```lua
require("ai-terminals").setup({
  watch_cwd = {
    enabled = true,
    ignore = {
      "**/.git/**",
      "**/node_modules/**",
      "**/.venv/**",
      "**/*.log",
    },
    -- Also merge ignore rules from <git root>/.gitignore
    -- Negations (!) are supported; patterns are evaluated relative to repo root
    gitignore = true,
  },
  trigger_formatting = { enabled = true },
})
```

Notes
- .gitignore semantics supported: comments (#), negation (!), root-anchored patterns (leading “/”), directory-only (trailing “/”), and “**”.
- Only the repository root .gitignore is read; per-directory .gitignore files are not currently merged.
- Matching uses paths relative to the git root for .gitignore rules, and paths relative to your current working directory for `watch_cwd.ignore`.

#### Deprecated Functions

These functions still work but are deprecated in favor of the generic file management:

- **➕ Add Files:** *(Deprecated)* Use
  `add_files_to_terminal("aider", files, opts)` instead
  (`:h ai-terminals.aider_add_files`).
- **➕ Add Buffers:** *(Deprecated)* Use
  `add_buffers_to_terminal("aider", opts)` instead
  (`:h ai-terminals.aider_add_buffers`).

## 🔗 Dependencies

- [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal
  window management. 🍬
- Optional CLI tools (install on demand):
  [Aider](https://github.com/paul-gauthier/aider),
  [Claude CLI](https://github.com/anthropics/claude-cli),
  [Goose](https://github.com/aweis89/goose),
  [Codex CLI](https://github.com/openai/codex),
  [Cursor CLI](https://cursor.com/en/cli)

## 🔧 Configuration

You can optionally configure the plugin using the `setup` function. This allows
you to define your own terminals or override the default commands and settings.

### 🖥️ Tmux Backend (Preferred)

The tmux backend is the **preferred approach** for this plugin as it provides
better performance and stability. When using the tmux backend
(`backend = "tmux"`), the plugin provides additional configuration options:

**Prerequisites:**
To use the tmux backend, you need to install the
[tmux-toggle-popup](https://github.com/loichyan/tmux-toggle-popup) plugin:

```tmux
# Add to your tmux.conf
set -g @plugin "loichyan/tmux-toggle-popup"
set -g @popup-toggle-mode 'force-close'
```

**Default Keybinding:**

- `C-h` - Hide/toggle the tmux popup when it's in focus
- `Escape` - Hide/toggle the tmux popup when it's in focus

This keybinding is automatically configured when using the tmux backend and
allows you to quickly hide the terminal popup from within tmux.

**Credit:** The tmux nvim bridge implementation is adapted from
[tmux-toggle-popup.nvim](https://github.com/cenk1cenk2/tmux-toggle-popup.nvim).
The code has been integrated directly into this repository for additional
control and to avoid external dependencies.

### 🎯 Path Header Templates

Each terminal can have a custom `path_header_template` that controls how file
paths are formatted when sending visual selections. This allows different AI
terminals to receive path information in their preferred format without
requiring additional tool calls.

**Default Templates:**

- **Aider:** `` `%s` `` (wrapped in backticks for Aider's file reference format)
- **All other terminals:** `@%s` (prefixed with @ symbol)

**Custom Template Example:**

```lua
terminals = {
  my_ai_tool = {
    path_header_template = "File: %s", -- Custom format
  },
}
```

When you send a visual selection from `src/main.js` to a terminal, the path
header will be formatted according to that terminal's template:

- Aider receives: `` `src/main.js` ``
- Claude receives: `@src/main.js`
- Custom tool receives: `File: src/main.js`

## 🔌 Snacks Picker Integration

Built-in integration with [Snacks.nvim](https://github.com/folke/snacks.nvim)
lets you add the currently selected files in any picker to an AI terminal in a
single keystroke — without overriding your own Snacks configuration.

Important: prefixes
- Toggle/diagnostics/etc. keymaps (set by `auto_terminal_keymaps`) use
  `auto_terminal_keymaps.prefix` (default in examples: `<leader>at`).
- Picker actions use a separate `auto_terminal_keymaps.picker_prefix` and
  default to `<localleader>` so they don’t conflict with toggles.

What you get
- Actions for every configured terminal: `<term>_add` is generated for all
  entries in `Config.config.terminals`; `<term>_read_only` is added only when
  that terminal defines `file_commands.add_files_readonly` (e.g., `aider`).
- Safe defaults: default keymaps are added to common file pickers only when a
  key is not already defined.
- Absolute path resolution: uses `Snacks.picker.util.path(item)` to resolve
  project-relative entries to full paths.
- Claude directory special-case: selecting a single directory triggers
  `claude /add-dir <dir>`.

Enable it (lazy.nvim)
```lua
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local sa = require("ai-terminals.snacks_actions")
      return sa.apply(opts) -- merges actions + default keymaps; user options win
    end,
  },
}
```

Default keymaps (added only if unset)
- Keys derive from your `auto_terminal_keymaps` entries:
  - `{picker_prefix}a{key}` → `{terminal}_add`
  - `{picker_prefix}A{key}` → `{terminal}_read_only` (only when supported)
  Where `{picker_prefix}` is `auto_terminal_keymaps.picker_prefix` (defaults to
  `<localleader>`). Example: with `picker_prefix = "<localleader>"` and
  `{ name = "claude", key = "c" }`, the picker maps use `<localleader>ac` for
  `claude_add`.
- If `auto_terminal_keymaps` is not set, no default picker mappings are added
  (actions are still available to bind manually).

Applied to these pickers
- `buffers`, `files`, `git_diff`, `git_files`, `git_log_file`, `git_log`,
  `git_status`, `grep_buffers`, `grep_word`, `grep`, `projects`, `recent`,
  `smart`, `explorer`.

Customize
- Mappings never override yours. To change keys, set them in your Snacks opts
  as usual; `sa.apply()` will leave existing mappings intact.
- Add keys for other terminals by binding to the generated actions (e.g.,
  `goose_add`, `cursor_add`). Example:

```lua
opts = {
  picker = {
    sources = {
      files = {
        win = {
          input = {
            keys = {
              ["<localleader>ag"] = { "goose_add", mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },
}
```

Notes
- Disable notifications from the integration with
  `vim.g.ai_terminals_snacks_actions_notify = false`.
- If you prefer full manual control, skip `sa.apply()` and define your own
  actions/mappings; `ai-terminals.add_files_to_terminal()` works everywhere.

### 📋 Example Usage

A concise `lazy.nvim` setup that relies on auto-generated keymaps. This keeps your config small while still exposing all the common actions.

```lua
-- lua/plugins/ai-terminals.lua
return {
  {
    "aweis89/ai-terminals.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      -- Optional: customize commands and per-terminal formatting
      terminals = {
        claude = { cmd = function() return "claude" end },
        aider  = { cmd = function() return "aider --watch-files" end, path_header_template = "`%s`" },
        goose  = { cmd = function() return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background) end },
      },
      -- One line to get consistent mappings for all terminals
      auto_terminal_keymaps = {
        prefix = "<leader>at",
        terminals = {
          { name = "claude", key = "c" },
          { name = "aider",  key = "a" },
          { name = "goose",  key = "g" },
          -- { name = "cursor", key = "r", enabled = false }, -- example disabled
        },
      },
    },
    config = function(_, opts)
      require("ai-terminals").setup(opts)
      -- Optional: integrate Snacks pickers with add-file actions
      local sa = require("ai-terminals.snacks_actions")
      require("snacks").setup({}) -- or your existing Snacks opts
      sa.apply(require("snacks").config) -- merges actions + safe default picker keys
    end,
  },
}
```

What you get out of the box (with the config above):

- `<leader>atc` / `<leader>ata` / `<leader>atg` — Toggle Claude/Aider/Goose; sends visual selection.
- `<leader>adc` — Send diagnostics to Claude. Same pattern for other terminals.
- `<leader>alc` / `<leader>aLc` — Add current file / all buffers to Claude.
- `<leader>arc` — Prompt for a shell command and send output to Claude.
- Picker adds: `<localleader>ac` adds the selected file(s) to Claude. Same for `a` (Aider), `g` (Goose), etc.

### 📦 Installation

#### Using `lazy.nvim`

1. Add the plugin specification to your `lazy.nvim` configuration:

    ```lua
    -- lua/plugins/ai-terminals.lua
    return {
      "aweis89/ai-terminals.nvim",
      dependencies = { "folke/snacks.nvim" },
      opts = {
        auto_terminal_keymaps = {
          prefix = "<leader>at",
          terminals = {
            { name = "claude", key = "c" },
            { name = "aider",  key = "a" },
          },
        },
      },
      config = function(_, opts)
        require("ai-terminals").setup(opts)
        local sa = require("ai-terminals.snacks_actions")
        sa.apply(require("snacks").config)
      end,
    }
    ```

2. Restart Neovim or run `:Lazy sync`.

#### Using `packer.nvim`

If you are using `packer.nvim`, you only need to call the `setup` function in
your configuration if you want to customize the defaults.

```lua
-- In your Neovim configuration (e.g., lua/plugins.lua)
use({
  "aweis89/ai-terminals.nvim",
  requires = { "folke/snacks.nvim" },
  config = function()
    require("ai-terminals").setup({
      auto_terminal_keymaps = {
        prefix = "<leader>at",
        terminals = {
          { name = "claude", key = "c" },
          { name = "aider",  key = "a" },
        },
      },
    })

    -- Optional Snacks picker integration
    local sa = require("ai-terminals.snacks_actions")
    sa.apply(require("snacks").config)
  end,
})
```

**Note on `destroy_all`:** This function stops the underlying processes
associated with the AI terminals and closes their windows/buffers using the
underlying `Snacks` library's `destroy()` method. The next time you use `toggle`
or `open` for a specific AI tool, a completely new instance of that tool will be
started.

### 🧩 Integrating with Other Tools or Pickers

`ai-terminals.nvim` can be easily integrated with other Neovim plugins for
advanced workflows. Check the [recipes directory](recipes/) for examples.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Please feel free to
check the [issues page](https://github.com/aweis89/ai-terminals.nvim/issues).

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.
