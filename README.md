# 🤖 AI Terminals Neovim Plugin

<img width="1512" height="949" alt="Screenshot 2025-07-27 at 11 04 59 AM" src="https://github.com/user-attachments/assets/4353b150-78bc-46ac-a1b7-f34b28738305" />

This plugin **seamlessly integrates any command-line (CLI) AI coding agents**
into Neovim. It provides a unified workflow for interacting with AI assistants
directly within your editor, enabling seamless integration of terminal AI agents.

## ⚡ Quick Start

Using lazy.nvim

```lua
{
  "aweis89/ai-terminals.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {}, -- uses sensible defaults; tmux backend auto-selected in tmux
}
```

Try it

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

The tools below are preconfigured out of the box. If they are installed and on
your `PATH`, you can use them immediately. You can also add your own custom
REPLs/CLIs — the plugin communicates via a PTY (Neovim terminal channels) and
tmux `send-keys`, so any interactive process that reads from the terminal/STDIN
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
  stdin input - from Aider and Claude CLI to custom scripts and future tools.
- **Data Bridge Architecture:** Creates a seamless bridge between your editor
  context (code selections, diagnostics, file paths) and terminal AI agents.
- **Tool Agnostic:** Instead of locking you into specific AI services, it lets
  you use whatever CLI tools work best for your workflow.
- **Stdin as API:** Leverages the universal stdin interface that all CLI tools
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
  snacks backend** - tmux terminals cannot execute Neovim functions.
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

**File Picker Integration:** These functions integrate seamlessly with file
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
  its own tab for review. Re-opening the terminal window resets the changes.
  See `:help diff-mode` for vim's diff commands like `:diffput` and `:diffget`
  to manipulate changes. Alternatively, use `diff_changes({ delta = true })` to
  view changes with the delta diff viewer in a terminal. Note: Git-based diff
  tools (like gitsigns.nvim or fugitive.vim) provide more feature-rich diff
  management and are recommended for most workflows
  (`:h ai-terminals.diff_changes`).

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

**Note:** Calling `setup()` is only necessary if you want to customize the
default configuration (e.g., change terminal commands, window dimensions, or the
default position). The core functionality, including autocommands for file
reloading and backup syncing, works out-of-the-box without calling `setup()`.

```lua
-- In your Neovim configuration (e.g., lua/plugins/ai-terminals.lua)
require("ai-terminals").setup({
  -- Override or add terminal configurations
  terminals = {
    -- Example: Override the default Aider command
    aider = {
      cmd = function()
        -- Use dark/light mode based on background
        return string.format("aider --watch-files --%s-mode", vim.o.background)
      end,
      -- Custom path header template for Aider (uses backticks)
      path_header_template = "`%s`",
      -- File management commands (optional)
      file_commands = {
        add_files = "/add %s",           -- Template for adding files
        add_files_readonly = "/read-only %s",  -- Template for read-only files
        submit = true,                   -- Auto-submit after sending command
      },
    },
    -- Example: Add a new terminal for a custom script
    my_custom_ai = {
      cmd = "/path/to/my/ai_script.sh --interactive",
      -- Custom path header template with '@' prefix
      path_header_template = "@%s",
    },
    -- Example: Remove a default terminal if you don't use it
    goose = nil,
  },
  -- Override default window dimensions (uses Snacks options)
  -- Keys correspond to positions: 'float', 'bottom', 'top', 'left', 'right'
  window_dimensions = {
    float = { width = 0.8, height = 0.7 }, -- Example: Change float dimensions
    bottom = { width = 1.0, height = 0.4 }, -- Example: Change bottom dimensions
    border = "rounded",
  },
  -- Set the default window position if none is specified (default: "float")
  default_position = "bottom", -- Example: Make terminals open at the bottom
  -- Environment variables to set for terminal commands
  env = {
    PAGER = "cat", -- Example: Set PAGER to cat
    -- MY_API_KEY = os.getenv("MY_SECRET_API_KEY"), -- Example: Pass an env var
  },
  -- Define keymaps that only apply within terminal buffers (snacks backend only)
  terminal_keymaps = {
    { key = "<C-w>q", action = "close", desc = "Close terminal window",
      modes = "t" },
    { key = "<Esc>", action = function() vim.cmd("stopinsert") end,
      desc = "Exit terminal insert mode", modes = "t" },
    -- Add more terminal-specific keymaps here
  },
})
```

The `cmd` field for each terminal can be a `string` or a `function` that returns
a string. Using a function allows the command to be generated dynamically *just
before* the terminal is opened (e.g., to check `vim.o.background` at invocation
time).

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
    cmd = "my-ai-cli",
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

The plugin integrates seamlessly with [Snacks.nvim](https://github.com/folke/snacks.nvim)
pickers, allowing you to add selected files from any picker directly to your AI
terminals. Here's a complete working example:

```lua
-- Helper function to extract files from a snacks picker and send them to ai-terminals
---@param picker snacks.Picker
---@param term string
---@param opts? { read_only?: boolean } Options for the command
local function add_files_from_picker(picker, term, opts)
  local selected = picker:selected({ fallback = true })
  local files_to_add = {}
  for _, item in pairs(selected) do
    if item.file then
      -- Use Snacks.picker.util.path() to get the absolute path
      -- This is necessary to get the absolute path from project picker
      local abs_path = Snacks.picker.util.path(item)
      if abs_path then
        table.insert(files_to_add, abs_path)
      end
    end
  end
  require("ai-terminals").add_files_to_terminal(term, files_to_add, opts)
end

-- Configure Snacks picker with ai-terminals actions
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    return vim.tbl_deep_extend("force", opts or {}, {
      picker = {
        actions = {
          -- Actions for adding files to different AI terminals
          ["aider_add"] = function(picker)
            picker:close()
            add_files_from_picker(picker, "aider")
          end,
          ["aider_read_only"] = function(picker)
            picker:close()
            add_files_from_picker(picker, "aider", { read_only = true })
          end,
          ["claude_add"] = function(picker)
            picker:close()
            add_files_from_picker(picker, "claude")
          end,
          ["codex_add"] = function(picker)
            picker:close()
            add_files_from_picker(picker, "codex")
          end,
        },
        sources = {
          -- Apply file actions to multiple picker sources
          files = {
            win = {
              input = {
                keys = {
                  ["<localleader>aa"] = { "aider_add", mode = { "n", "i" } },
                  ["<localleader>Aa"] = { "aider_read_only", mode = { "n", "i" } },
                  ["<localleader>ac"] = { "claude_add", mode = { "n", "i" } },
                  ["<localleader>ad"] = { "codex_add", mode = { "n", "i" } },
                },
              },
            },
          },
          git_files = {
            win = {
              input = {
                keys = {
                  ["<localleader>aa"] = { "aider_add", mode = { "n", "i" } },
                  ["<localleader>Aa"] = { "aider_read_only", mode = { "n", "i" } },
                  ["<localleader>ac"] = { "claude_add", mode = { "n", "i" } },
                  ["<localleader>ad"] = { "codex_add", mode = { "n", "i" } },
                },
              },
            },
          },
          -- Add the same keymaps to other pickers like git_status, recent, etc.
        },
      },
    })
  end,
}
```

**Usage:**

1. Open any Snacks picker (files, git_files, git_status, etc.)
2. Select one or more files using `<Tab>` or navigate to the file you want
3. Use the keymaps to add files to your AI terminals:
   - `<localleader>aa` - Add to Aider (normal mode)
   - `<localleader>Aa` - Add to Aider (read-only mode)  
   - `<localleader>ac` - Add to Claude
   - `<localleader>ad` - Add to Codex

This integration works with all Snacks pickers that show files and uses the modern
generic `add_files_to_terminal()` function, which automatically handles the
appropriate file commands for each terminal type.

### 📋 Example Usage

Here's a more complete example using `lazy.nvim`:

```lua
-- lua/plugins/ai-terminals.lua
return {
  {
    "aweis89/ai-terminals.nvim",
    -- Example opts using functions for dynamic command generation
    -- (matches plugin defaults)
    opts = {
      terminals = {
        goose = {
          cmd = function()
            return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)
          end,
          path_header_template = "@%s", -- Default: @ prefix
        },
        cursor = {
          cmd = function()
            return "cursor-agent"
          end,
          path_header_template = "@%s", -- Default: @ prefix
        },
        codex = {
          cmd = function()
            return "codex"
          end,
          path_header_template = "@%s", -- Default: @ prefix
        },
        claude = {
          cmd = function()
            return string.format("claude config set -g theme %s && claude", vim.o.background)
          end,
          path_header_template = "@%s", -- Default: @ prefix
        },
        aider = {
          cmd = function()
            return string.format("aider --watch-files --%s-mode", vim.o.background)
          end,
          path_header_template = "`%s`", -- Special: backticks for Aider
        },
      },
      -- You can also set window, default_position, enable_diffing here
    },
    dependencies = { "folke/snacks.nvim" },
    keys = {
      -- Example Keymaps (using default terminal names: 'claude', 'goose',
      -- 'cursor', 'aider', 'codex')
      -- Claude Keymaps
      {
        "<leader>atc", -- Mnemonic: AI Terminal Claude
        function() require("ai-terminals").toggle("claude") end,
        mode = { "n", "v" }, -- Works in normal and visual mode
        desc = "Toggle Claude terminal (sends selection in visual mode)",
      },
      {
        "<leader>adc", -- Mnemonic: AI Diagnostics Claude
        function() require("ai-terminals").send_diagnostics("claude") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Claude",
      },
      -- Goose Keymaps
      {
        "<leader>atg",
        function() require("ai-terminals").toggle("goose") end,
        mode = { "n", "v" },
        desc = "Toggle Goose terminal (sends selection in visual mode)",
      },
      {
        "<leader>adg",
        function() require("ai-terminals").send_diagnostics("goose") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Goose",
      },
      -- Cursor Keymaps
      {
        "<leader>atr",
        function() require("ai-terminals").toggle("cursor") end,
        mode = { "n", "v" },
        desc = "Toggle Cursor terminal (sends selection in visual mode)",
      },
      {
        "<leader>adr",
        function() require("ai-terminals").send_diagnostics("cursor") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Cursor",
      },
      -- Aider Keymaps
      {
        "<leader>ata",
        function() require("ai-terminals").toggle("aider") end,
        mode = { "n", "v" },
        desc = "Toggle Aider terminal (sends selection in visual mode)",
      },
      {
        "<leader>ac",
        function()
          -- Adds comment and saves file
          require("ai-terminals").aider_comment("AI!")
        end,
        desc = "Add 'AI!' comment above line",
      },
      {
        "<leader>aC",
        function()
          -- Adds comment and saves file
          require("ai-terminals").aider_comment("AI?")
        end,
        desc = "Add 'AI?' comment above line",
      },
      -- Generic File Management (works with any terminal)
      {
        "<leader>af", -- Mnemonic: Add Files
        function()
          -- Add current file to Claude using generic function
          require("ai-terminals").add_files_to_terminal("claude", {vim.fn.expand("%")})
        end,
        desc = "Add current file to Claude",
      },
      {
        "<leader>aF", -- Mnemonic: Add Files (all buffers)
        function()
          -- Add all buffers to Claude using generic function
          require("ai-terminals").add_buffers_to_terminal("claude")
        end,
        desc = "Add all buffers to Claude",
      },
      {
        "<leader>aa", -- Mnemonic: Add files to Aider
        function()
          -- Add current file to Aider using generic function
          require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")})
        end,
        desc = "Add current file to Aider",
      },
      {
        "<leader>aA", -- Mnemonic: Add all buffers to Aider
        function()
          -- Add all buffers to Aider using generic function
          require("ai-terminals").add_buffers_to_terminal("aider")
        end,
        desc = "Add all buffers to Aider",
      },
      {
        "<leader>ar", -- Mnemonic: Add read-only to Aider
        function()
          -- Add current file as read-only to Aider
          require("ai-terminals").add_files_to_terminal("aider",
            {vim.fn.expand("%")}, { read_only = true })
        end,
        desc = "Add current file to Aider (read-only)",
      },
      {
        "<leader>ada",
        function() require("ai-terminals").send_diagnostics("aider") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Aider",
      },
      -- Codex Keymaps
      {
        "<leader>atd",
        function() require("ai-terminals").toggle("codex") end,
        mode = { "n", "v" },
        desc = "Toggle Codex terminal (sends selection in visual mode)",
      },
      {
        "<leader>add",
        function() require("ai-terminals").send_diagnostics("codex") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Codex",
      },
      -- Gemini Keymaps
      {
        "<leader>atm",
        function() require("ai-terminals").toggle("gemini") end,
        mode = { "n", "v" },
        desc = "Toggle Gemini terminal (sends selection in visual mode)",
      },
      {
        "<leader>adm",
        function() require("ai-terminals").send_diagnostics("gemini") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Gemini",
      },
      -- Run Command and Send Output
      {
        "<leader>ar", -- Mnemonic: AI Run command (prompts)
        function()
          -- Prompts user for a command, then sends its output to the
          -- active/last-focused AI terminal.
          require("ai-terminals").send_command_output()
        end,
        desc = "Run command (prompts) and send output to active AI terminal",
      },
      {
        "<leader>aj", -- Mnemonic: AI Jira (example fixed command)
        function()
          -- Sends output of a fixed command to the active/last-focused AI terminal.
          -- Replace with your actual command, e.g., dynamically get ticket ID.
          require("ai-terminals").send_command_output(
            "jira issue view YOUR-TICKET-ID --plain")
        end,
        desc = "Send Jira ticket (example) to active AI terminal",
      },
      -- Destroy All Terminals
      {
        "<leader>ax", -- Mnemonic: AI eXterminate
        function() require("ai-terminals").destroy_all() end,
        desc = "Destroy all AI terminals (closes windows, stops processes)",
      },
      -- Focus Terminal
      {
        "<leader>af", -- Mnemonic: AI Focus
        function() require("ai-terminals").focus() end,
        desc = "Focus the last used AI terminal window",
      },
      -- Diff Changes (requires enable_diffing = true in config)
      {
        "<leader>ad", -- Mnemonic: AI Diff
        function() require("ai-terminals").diff_changes() end,
        desc = "Show vim diff of all changed files in tabs",
      },
    },
  },
}
```

### 📦 Installation

#### Using `lazy.nvim`

1. Add the plugin specification to your `lazy.nvim` configuration:

    ```lua
    -- lua/plugins/ai-terminals.lua
    return {
      "aweis89/ai-terminals.nvim",
      dependencies = { "folke/snacks.nvim" },
      -- Optional: Add opts = {} to configure, or define keys as shown above
      config = function(_, opts)
        require("ai-terminals").setup(opts)
        -- Define your keymaps here (or use auto_terminal_keymaps)
        
        -- Example manual keymaps - consider using auto_terminal_keymaps instead
        vim.keymap.set({"n", "v"}, "<leader>atc",
          function() require("ai-terminals").toggle("claude") end,
          { desc = "Toggle Claude terminal" })
        vim.keymap.set({"n", "v"}, "<leader>ata",
          function() require("ai-terminals").toggle("aider") end,
          { desc = "Toggle Aider terminal" })
        vim.keymap.set({"n", "v"}, "<leader>adc",
          function() require("ai-terminals").send_diagnostics("claude") end,
          { desc = "Send diagnostics to Claude" })
        vim.keymap.set("n", "<leader>aa",
          function() require("ai-terminals").add_files_to_terminal("aider",
            {vim.fn.expand("%")}) end, { desc = "Add current file to Aider" })
        vim.keymap.set("n", "<leader>ax",
          function() require("ai-terminals").destroy_all() end,
          { desc = "Destroy all AI terminals" })

        
        -- More examples available in the first example above
        -- Or better: use auto_terminal_keymaps for automatic generation!
      end,
    }
    ```

2. Restart Neovim or run `:Lazy sync`.

#### Using `packer.nvim`

If you are using `packer.nvim`, you only need to call the `setup` function in
your configuration if you want to customize the defaults.

```lua
-- In your Neovim configuration (e.g., lua/plugins.lua or similar)
use({
  "aweis89/ai-terminals.nvim",
  requires = { "folke/snacks.nvim" },
  config = function()
    -- Optional: Call setup only if you need to customize defaults
    require("ai-terminals").setup({
      -- Your custom configuration here (see Configuration section)
      -- e.g., default_position = "bottom"
    })

    -- Define your keymaps here or in a separate keymap file

    -- Claude Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atc",
      function() require("ai-terminals").toggle("claude") end,
      { desc = "Toggle Claude terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adc",
      function() require("ai-terminals").send_diagnostics("claude") end,
      { desc = "Send diagnostics to Claude" })

    -- Goose Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atg",
      function() require("ai-terminals").toggle("goose") end,
      { desc = "Toggle Goose terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adg",
      function() require("ai-terminals").send_diagnostics("goose") end,
      { desc = "Send diagnostics to Goose" })

    -- Cursor Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atr",
      function() require("ai-terminals").toggle("cursor") end,
      { desc = "Toggle Cursor terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adr",
      function() require("ai-terminals").send_diagnostics("cursor") end,
      { desc = "Send diagnostics to Cursor" })

    -- Aider Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ata",
      function() require("ai-terminals").toggle("aider") end,
      { desc = "Toggle Aider terminal (sends selection)" })
    vim.keymap.set("n", "<leader>ac",
      function() require("ai-terminals").aider_comment("AI!") end,
      { desc = "Add 'AI!' comment above line" })
    vim.keymap.set("n", "<leader>aC",
      function() require("ai-terminals").aider_comment("AI?") end,
      { desc = "Add 'AI?' comment above line" })
    -- Generic File Management (works with any terminal)
    vim.keymap.set("n", "<leader>af",
      function() require("ai-terminals").add_files_to_terminal("claude",
        {vim.fn.expand("%")}) end, { desc = "Add current file to Claude" })
    vim.keymap.set("n", "<leader>aF",
      function() require("ai-terminals").add_buffers_to_terminal("claude") end,
      { desc = "Add all buffers to Claude" })
    vim.keymap.set("n", "<leader>aa",
      function() require("ai-terminals").add_files_to_terminal("aider",
        {vim.fn.expand("%")}) end, { desc = "Add current file to Aider" })
    vim.keymap.set("n", "<leader>aA",
      function() require("ai-terminals").add_buffers_to_terminal("aider") end,
      { desc = "Add all buffers to Aider" })
    vim.keymap.set("n", "<leader>ar",
      function() require("ai-terminals").add_files_to_terminal("aider",
        {vim.fn.expand("%")}, { read_only = true }) end,
      { desc = "Add current file to Aider (read-only)" })
    vim.keymap.set({"n", "v"}, "<leader>ada",
      function() require("ai-terminals").send_diagnostics("aider") end,
      { desc = "Send diagnostics to Aider" })

    -- Codex Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atd",
      function() require("ai-terminals").toggle("codex") end,
      { desc = "Toggle Codex terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>add",
      function() require("ai-terminals").send_diagnostics("codex") end,
      { desc = "Send diagnostics to Codex" })

    -- Gemini Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atm",
      function() require("ai-terminals").toggle("gemini") end,
      { desc = "Toggle Gemini terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adm",
      function() require("ai-terminals").send_diagnostics("gemini") end,
      { desc = "Send diagnostics to Gemini" })

    -- Example: Run a command and send output to a specific terminal
    vim.keymap.set("n", "<leader>ar",
      function() require("ai-terminals").send_command_output("aider") end,
      { desc = "Run command (prompts) and send output to Aider" })
    -- Or use a fixed command like:
    -- vim.keymap.set("n", "<leader>ar",
    --   function() require("ai-terminals").send_command_output("aider",
    --     "make test") end,
    --   { desc = "Run 'make test' and send output to Aider" })

   -- Destroy All Terminals
   vim.keymap.set("n", "<leader>ax",
      function() require("ai-terminals").destroy_all() end,
      { desc = "Destroy all AI terminals (closes windows, stops processes)" })

   -- Focus Terminal
   vim.keymap.set("n", "<leader>af",
      function() require("ai-terminals").focus() end,
      { desc = "Focus the last used AI terminal window" })

   -- Diff Changes (requires enable_diffing = true in config)
   vim.keymap.set("n", "<leader>ad",
      function() require("ai-terminals").diff_changes() end,
      { desc = "Show vim diff of all changed files in tabs" })
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
