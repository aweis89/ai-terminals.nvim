<img width="1512" alt="Screenshot 2025-05-24 at 2 52 48 PM" src="https://github.com/user-attachments/assets/cd7b5acb-4285-498e-b4af-825a5f3161a9" />

# 🤖 AI Terminals Neovim Plugin
This plugin **seamlessly integrates any command-line (CLI) AI coding agents**
into Neovim. It provides a unified workflow for interacting with AI assistants
directly within your editor, reducing the need for specific, dedicated AI
plugins for each tool.

## 🤔 Motivation

While many Neovim plugins offer deep integration with *specific* AI services or
models, `ai-terminals.nvim` takes a different approach. It focuses on leveraging
the power and flexibility of existing **command-line AI tools**. By providing a
unified interface to manage and interact with these tools within Neovim
terminals, it offers:

* **Flexibility:** Easily switch between or use multiple AI agents (Aider,
  Claude CLI, custom scripts, etc.) without needing separate plugins for each.
* **Future-Proofing:** As new CLI tools emerge, integrating them is often as
  simple as adding a new entry to your configuration.
* **Consistency:** Provides a consistent workflow (sending selections/diagnostics, diffing, reversing changes, creating prompts) across different tools.
* **Leverages Existing Tools:** Benefits from the features and updates of the
  underlying CLI tools themselves.
* **Stdin Integration:** CLI tools provide a straightforward API for sending input via `stdin`.
* This plugin utilizes that capability by exposing functions like `send`, enabling a wide range of custom integrations. For example, when toggling any terminal from visual mode, the code will get added to the prompt with the file path. You can also send diagnostics or command outputs. The `send` function can also be used to create custom prompts or functions like pulling in Jira ticket details or reviewing PRs.

This plugin is ideal for users who prefer terminal-based AI interaction and
want a single, configurable way to manage them within Neovim.

## ✨ Features

### ⚙️ Generic Features (Works with any terminal-based AI agent)

* **🔌 Configurable Terminal Integration:** Define and manage terminals for
  various AI CLI tools (e.g., Claude, Goose, Aider, custom scripts)
  through a simple configuration table. Uses `Snacks` for terminal window
  management.
* **🔄 Diff View & Revert:**
  * **Track Changes:** See modifications made to your project files in the last AI terminal session.
  * **How it Works:** When `enable_diffing = true` (default), the plugin
    maintains a persistent backup of your project using `rsync`. This backup is
    synced *every time* you open an AI terminal, capturing the state *before*
    the current AI interaction begins.
  * **View Differences:**
    * `diff_changes()`: Opens modified files in Neovim's built-in `vimdiff`.
      Use standard commands like `:diffget`, `:diffput`.
    * `diff_changes({ delta = true })`: Shows a unified diff using the
      [delta](https://github.com/dandavison/delta) tool in a terminal buffer
      (requires `delta` installed). Offers advanced highlighting but no
      `:diffget`/`:diffput`.
  * **Revert Changes:** `revert_changes()` reverses the changes in the diff view.
  * **Quick Close:** Press `q` in any vimdiff window or the delta terminal
    buffer to close the diff view (this mapping is added automatically).
* **🔃 Automatic File Reloading:** When you switch focus away from the AI
  terminal window, all listed buffers in Neovim are checked for modifications
  and reloaded if necessary, ensuring you see the latest changes made by the AI.
* **📋 Send Visual Selection:** Send the currently selected text (visual mode) to
  the AI terminal, automatically wrapped in a markdown code block with the file
  path and language type included. Each terminal can have a custom path header
  template to format file paths according to the AI tool's preferences (e.g., 
  `@filename` or `` `filename` ``).

  
* **🩺 Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the current buffer or visual selection to the AI terminal (`:h ai-terminals.send_diagnostics`), formatted with severity, line/column numbers, messages, and the corresponding source code lines.
* **🚀 Run Command and Send Output:** Execute an arbitrary shell command and send its standard output and exit code to the active AI terminal (`:h ai-terminals.send_command_output`). Useful for running tests, linters, or even fetching information from other CLIs (e.g., `jira issue view MYTICKET-123`) and feeding results to the AI.
* **📁 File Management:** Generic functions to add files or buffers to any terminal using configurable commands (`:h ai-terminals.add_files_to_terminal`, `:h ai-terminals.add_buffers_to_terminal`). Works with all terminals, with fallback behavior for terminals without specific file commands configured.
* **📝 Prompt Keymaps:** Define custom keymaps (`:h ai-terminals.config`) to send pre-defined prompts to specific terminals.
  * **Selection Handling:** Configure whether the keymap includes visual selection (`include_selection` option, defaults to `true`).
    * If `true`, the keymap works in normal and visual modes. In visual mode, the selection is prefixed to the prompt.
    * If `false`, the keymap works only in normal mode and sends just the prompt.
  * **Submission Control:** Configure whether a newline is sent after the prompt (`submit` option, defaults to `true`).
  * **Dynamic Prompts:** Prompt text can be a string or a function that returns a string. Functions are evaluated when the keymap is triggered, allowing dynamic content (e.g., current file path). See example in `:h ai-terminals.config`.
* **⌨️ Terminal Keymaps:** Define custom keymaps (`:h ai-terminals.config`) that only apply within the AI terminal buffers.
  * **Modes:** Specify which modes the keymap applies to (e.g., "t" for terminal mode, "n" for normal mode within the terminal). Defaults to "t".
  * **Actions:** Actions can be functions or strings (e.g., to close the terminal or send keys).

### 📁 File Management

The plugin provides generic file management functions that work with any terminal:

* **📂 Add Files to Terminal:** `add_files_to_terminal(terminal_name, files, opts)`
  * Send files to any terminal using its configured file commands
  * **Terminals with file_commands:** Uses configured templates (e.g., Aider uses `/add` or `/read-only` commands with automatic submission)
  * **Other terminals:** Uses fallback `@file1 @file2` format without submission
  * **Options:** `{ read_only = true }` for read-only mode (Aider only)
  
* **📋 Add Buffers to Terminal:** `add_buffers_to_terminal(terminal_name, opts)`
  * Add all currently listed buffers to any terminal
  * Filters out invalid, unloaded, or non-modifiable buffers
  * Uses the same command templates as `add_files_to_terminal`

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

### 🔥 Additional Features

The plugin includes some additional convenience functions:

* **💬 Add Comments (Aider):** Insert comments above the current line with a custom prefix (e.g., `AI!`, `AI?`) and automatically start the Aider terminal if not already running (`:h ai-terminals.aider_comment`).

#### Deprecated Functions

These functions still work but are deprecated in favor of the generic file management:

* **➕ Add Files:** *(Deprecated)* Use `add_files_to_terminal("aider", files, opts)` instead (`:h ai-terminals.aider_add_files`).
* **➕ Add Buffers:** *(Deprecated)* Use `add_buffers_to_terminal("aider", opts)` instead (`:h ai-terminals.aider_add_buffers`).

## ⚠️ Prerequisites

This plugin integrates with existing command-line AI tools. You need to install
the specific tools you want to use *before* configuring them in this plugin.

Here are links to some of the tools mentioned in the default configuration:

* **Aider:** [Aider](https://github.com/paul-gauthier/aider)
* **Claude CLI:** [Claude CLI](https://github.com/anthropics/claude-cli)
* **Goose:** [Goose](https://github.com/aweis89/goose)
* **AI Chat:** [AI Chat](https://github.com/sigoden/aichat)
* **Codex:** [Codex CLI](https://github.com/openai/codex)

* **Delta (Optional, for diffing):** [Delta](https://github.com/dandavison/delta)

Make sure these (or your chosen alternatives) are installed and accessible in
your system's `PATH`.

## 🔗 Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal
  window management. 🍬

## 🔧 Configuration

You can optionally configure the plugin using the `setup` function. This allows
you to define your own terminals or override the default commands and settings.

### 🖥️ Tmux Backend

When using the tmux backend (`backend = "tmux"`), the plugin provides additional configuration options:

**Default Keybinding:** 
- `C-h` - Hide/toggle the tmux popup when it's in focus

This keybinding is automatically configured when using the tmux backend and allows you to quickly hide the terminal popup from within tmux.

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
  -- Enable/disable the diffing feature (default: true)
  -- When enabled, a backup sync runs on terminal entry, allowing
  -- `diff_changes` and `close_diff` to work.
  -- Disabling this (`false`) skips the backup sync and prevents diff commands
  -- from functioning.
  enable_diffing = true,
  -- Automatically show diffs (if present) when leaving the terminal.
  -- Set to `false` or `nil` to disable.
  -- Set to `{ delta = true }` to automatically use delta instead of vimdiff.
  show_diffs_on_leave = true, -- Default: true
  -- Keymapping used within diff views (vimdiff or delta terminal) to close the diff.
  diff_close_keymap = "q", -- Default: "q"
  -- Define keymaps that only apply within terminal buffers
  terminal_keymaps = {
    { key = "<C-w>q", action = "close", desc = "Close terminal window", modes = "t" },
    { key = "<Esc>", action = function() vim.cmd("stopinsert") end, desc = "Exit terminal insert mode", modes = "t"},
    -- Add more terminal-specific keymaps here
  },
})
```

The `cmd` field for each terminal can be a `string` or a `function` that returns
a string. Using a function allows the command to be generated dynamically *just
before* the terminal is opened (e.g., to check `vim.o.background` at invocation
time).

### 🎯 Path Header Templates

Each terminal can have a custom `path_header_template` that controls how file paths are formatted when sending visual selections. This allows different AI terminals to receive path information in their preferred format without requiring additional tool calls.

**Key Benefits:**
- **Automatic Context:** File paths are automatically included with code selections, giving AI tools immediate context about the file being discussed
- **Format Flexibility:** Each terminal can use its own preferred path format (e.g., `@filename` for some tools, `` `filename` `` for others)
- **No Extra Steps:** No need for separate commands to provide file context - it's included automatically

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

When you send a visual selection from `src/main.js` to a terminal, the path header will be formatted according to that terminal's template:
- Aider receives: `` `src/main.js` ``
- Claude receives: `@src/main.js`
- Custom tool receives: `File: src/main.js`

### 🚀 Example Usage

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
        aichat = {
          cmd = function()
            return string.format(
              "AICHAT_LIGHT_THEME=%s aichat -r %%functions%% --session",
              -- Convert boolean to string "true" or "false"
              tostring(vim.o.background == "light")
            )
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
      -- Diff Tools
      {
        "<leader>dvo",
        function() require("ai-terminals").diff_changes() end,
        desc = "Show diff (vimdiff)",
      },
      {
        "<leader>dvD",
        function() require("ai-terminals").diff_changes({ delta = true }) end,
        desc = "Show diff (delta)",
      },
      {
        "<leader>dvr",
        function() require("ai-terminals").revert_changes() end,
        desc = "Revert changes from backup",
      },
      -- Example Keymaps (using default terminal names: 'claude', 'goose',
      -- 'aider', 'aichat')
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
          require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")}, { read_only = true })
        end,
        desc = "Add current file to Aider (read-only)",
      },
      {
        "<leader>ada",
        function() require("ai-terminals").send_diagnostics("aider") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Aider",
      },
      -- aichat Keymaps
      {
        "<leader>ati",
        function() require("ai-terminals").toggle("aichat") end,
        mode = { "n", "v" },
        desc = "Toggle AI Chat terminal (sends selection in visual mode)",
      },
      {
        "<leader>adi",
        function() require("ai-terminals").send_diagnostics("aichat") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to AI Chat",
      },
      -- Run Command and Send Output
      {
        "<leader>ar", -- Mnemonic: AI Run command (prompts)
        function()
          -- Prompts user for a command, then sends its output to the active/last-focused AI terminal.
          require("ai-terminals").send_command_output()
        end,
        desc = "Run command (prompts) and send output to active AI terminal",
      },
      {
        "<leader>aj", -- Mnemonic: AI Jira (example fixed command)
        function()
          -- Sends output of a fixed command to the active/last-focused AI terminal.
          -- Replace with your actual command, e.g., dynamically get ticket ID.
          require("ai-terminals").send_command_output("jira issue view YOUR-TICKET-ID --plain")
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
        -- Define your keymaps here or in a separate keymap file

        -- Diff Tools
        vim.keymap.set("n", "<leader>dvo", function() require("ai-terminals").diff_changes() end, { desc = "Show diff (vimdiff)" })
        vim.keymap.set("n", "<leader>dvD", function() require("ai-terminals").diff_changes({ delta = true }) end, { desc = "Show diff (delta)" })
        vim.keymap.set("n", "<leader>dvr", function() require("ai-terminals").revert_changes() end, { desc = "Revert changes from backup" })
        -- Note: 'q' closes diff views automatically, so a dedicated close
        -- mapping might be redundant.
        -- vim.keymap.set("n", "<leader>dvc", function() require("ai-terminals").close_diff() end, { desc = "Close all diff views (and wipeout buffers)" })

        -- Claude Keymaps
        vim.keymap.set({"n", "v"}, "<leader>atc", function() require("ai-terminals").toggle("claude") end, { desc = "Toggle Claude terminal (sends selection in visual mode)" })
        vim.keymap.set({"n", "v"}, "<leader>adc", function() require("ai-terminals").send_diagnostics("claude") end, { desc = "Send diagnostics to Claude" })

        -- Goose Keymaps
        vim.keymap.set({"n", "v"}, "<leader>atg", function() require("ai-terminals").toggle("goose") end, { desc = "Toggle Goose terminal (sends selection in visual mode)" })
        vim.keymap.set({"n", "v"}, "<leader>adg", function() require("ai-terminals").send_diagnostics("goose") end, { desc = "Send diagnostics to Goose" })

        -- Aider Keymaps
        vim.keymap.set({"n", "v"}, "<leader>ata", function() require("ai-terminals").toggle("aider") end, { desc = "Toggle Aider terminal (sends selection in visual mode)" })
        vim.keymap.set("n", "<leader>ac", function() require("ai-terminals").aider_comment("AI!") end, { desc = "Add 'AI!' comment above line" })
        vim.keymap.set("n", "<leader>aC", function() require("ai-terminals").aider_comment("AI?") end, { desc = "Add 'AI?' comment above line" })
        vim.keymap.set("n", "<leader>aa", function() require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")}) end, { desc = "Add current file to Aider" })
        vim.keymap.set("n", "<leader>aA", function() require("ai-terminals").add_buffers_to_terminal("aider") end, { desc = "Add all buffers to Aider" })
        vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")}, { read_only = true }) end, { desc = "Add current file to Aider (read-only)" })
        vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

        -- aichat Keymaps
        vim.keymap.set({"n", "v"}, "<leader>ati", function() require("ai-terminals").toggle("aichat") end, { desc = "Toggle AI Chat terminal (sends selection in visual mode)" })
        vim.keymap.set({"n", "v"}, "<leader>adi", function() require("ai-terminals").send_diagnostics("aichat") end, { desc = "Send diagnostics to AI Chat" })

        -- Run Command and Send Output
        vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider") end, { desc = "Run command (prompts) and send output to Aider terminal" })
        -- Or use a fixed command like:
        -- vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider", "make test") end, { desc = "Run 'make test' and send output to Aider" })

        -- Destroy All Terminals
        vim.keymap.set("n", "<leader>ax", function() require("ai-terminals").destroy_all() end, { desc = "Destroy all AI terminals (closes windows, stops processes)" })

        -- Focus Terminal
        vim.keymap.set("n", "<leader>af", function() require("ai-terminals").focus() end, { desc = "Focus the last used AI terminal window" })
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

    -- Diff Tools
    vim.keymap.set("n", "<leader>dvo", function() require("ai-terminals").diff_changes() end, { desc = "Show diff (vimdiff)" })
    vim.keymap.set("n", "<leader>dvD", function() require("ai-terminals").diff_changes({ delta = true }) end, { desc = "Show diff (delta)" })
    vim.keymap.set("n", "<leader>dvr", function() require("ai-terminals").revert_changes() end, { desc = "Revert changes from backup" })
    -- Note: 'q' closes diff views automatically, so a dedicated close
    -- mapping might be redundant.
    -- vim.keymap.set("n", "<leader>dvc", function() require("ai-terminals").close_diff() end, { desc = "Close all diff views (and wipeout buffers)" })

    -- Claude Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atc", function() require("ai-terminals").toggle("claude") end, { desc = "Toggle Claude terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adc", function() require("ai-terminals").send_diagnostics("claude") end, { desc = "Send diagnostics to Claude" })

    -- Goose Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atg", function() require("ai-terminals").toggle("goose") end, { desc = "Toggle Goose terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adg", function() require("ai-terminals").send_diagnostics("goose") end, { desc = "Send diagnostics to Goose" })

    -- Aider Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ata", function() require("ai-terminals").toggle("aider") end, { desc = "Toggle Aider terminal (sends selection)" })
    vim.keymap.set("n", "<leader>ac", function() require("ai-terminals").aider_comment("AI!") end, { desc = "Add 'AI!' comment above line" })
    vim.keymap.set("n", "<leader>aC", function() require("ai-terminals").aider_comment("AI?") end, { desc = "Add 'AI?' comment above line" })
    -- Generic File Management (works with any terminal)
    vim.keymap.set("n", "<leader>af", function() require("ai-terminals").add_files_to_terminal("claude", {vim.fn.expand("%")}) end, { desc = "Add current file to Claude" })
    vim.keymap.set("n", "<leader>aF", function() require("ai-terminals").add_buffers_to_terminal("claude") end, { desc = "Add all buffers to Claude" })
    vim.keymap.set("n", "<leader>aa", function() require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")}) end, { desc = "Add current file to Aider" })
    vim.keymap.set("n", "<leader>aA", function() require("ai-terminals").add_buffers_to_terminal("aider") end, { desc = "Add all buffers to Aider" })
    vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").add_files_to_terminal("aider", {vim.fn.expand("%")}, { read_only = true }) end, { desc = "Add current file to Aider (read-only)" })
    vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

    -- aichat Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ati", function() require("ai-terminals").toggle("aichat") end, { desc = "Toggle AI Chat terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adi", function() require("ai-terminals").send_diagnostics("aichat") end, { desc = "Send diagnostics to AI Chat" })

    -- Example: Run a command and send output to a specific terminal
    vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider") end, { desc = "Run command (prompts) and send output to Aider" })
    -- Or use a fixed command like:
    -- vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider", "make test") end, { desc = "Run 'make test' and send output to Aider" })

   -- Destroy All Terminals
   vim.keymap.set("n", "<leader>ax", function() require("ai-terminals").destroy_all() end, { desc = "Destroy all AI terminals (closes windows, stops processes)" })

   -- Focus Terminal
   vim.keymap.set("n", "<leader>af", function() require("ai-terminals").focus() end, { desc = "Focus the last used AI terminal window" })
  end,
})
```

**Note on `destroy_all`:** This function stops the underlying processes
associated with the AI terminals and closes their windows/buffers using the
underlying `Snacks` library's `destroy()` method. The next time you use `toggle`
or `open` for a specific AI tool, a completely new instance of that tool will be
started.

### 🧩 Integrating with Other Tools or Pickers

`ai-terminals.nvim` can be easily integrated with other Neovim plugins for advanced workflows. Check the [recipes directory](recipes/) for examples.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Please feel free to
check the [issues page](https://github.com/aweis89/ai-terminals.nvim/issues).

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.
yes
yes
