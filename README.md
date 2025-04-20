# 🤖 AI Terminals Neovim Plugin

This plugin **seamlessly integrates any command-line (CLI) AI coding agents** into Neovim. It provides a unified workflow for interacting with AI assistants directly within your editor, eliminating the need for exlusively dedicated Neovim AI plugins.

## ✨ Features

### ⚙️ Generic Features (Works with any terminal-based AI agent)

* **🔌 Configurable Terminal Integration:** Define and manage terminals for various
  AI CLI tools (e.g., Claude, Goose, Aider, Kode, custom scripts) through a simple
  configuration table. Uses `Snacks` for terminal window management.
* **🔄 Diff View:**
  * **Track AI Changes:** Compare the current state of your project files against the state they were in the last time you opened an AI terminal.
  * **How it Works:** The plugin maintains a persistent backup of your project (using `rsync` for efficiency). This backup is created the *first* time you open an AI terminal and *updated* (synced) each subsequent time you open one, setting a new comparison point.
  * **View Differences:** Use the `diff_changes()` command to open all modified files in Neovim's standard diff view. You can manage changes using standard commands like `:diffget` and `:diffput`.
  * **Close Diffs:** Use the `close_diff()` command to close the diff tabs and clean up related buffers.
  * **Enable/Disable:** This feature is active by default (`enable_diffing = true` in the setup configuration). Setting it to `false` disables the backup/sync process and the diff commands.
* **🔃 Automatic File Reloading:** When you switch focus away from the AI terminal
  window, all listed buffers in Neovim are checked for modifications and
  reloaded if necessary, ensuring you see the latest changes made by the AI.
* **📋 Send Visual Selection:** Send the currently selected text (visual mode) to the AI terminal, automatically wrapped in a markdown code block with the file path and language type included.

  *Tip:* After sending the selection, ai-terminal doesn't send the enter key so you can add custom prompts to the selection.
  This is a goto way of sending prompts with context so the LLM knows which code it pertains to (when not using Aider and the add comment command).
* **🩺 Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the current buffer or visual selection to the AI terminal, formatted with severity, line/column numbers, messages, and the corresponding source code lines.
* **🚀 Run Command and Send Output:** Execute an arbitrary shell command and send its standard output along with the exit code to the active AI terminal. This is useful for running tests, linters, or other tools and feeding the results directly to the AI.

### 🔥 Aider Specific Features

While the generic features work well with Aider, this plugin includes additional helpers specifically for Aider:

* **➕ Add Files:** Quickly add the current file or a list of files to the Aider chat context using `/add` or `/read-only`.
* **➕ Add Buffers:** Add all currently listed buffers to the Aider chat context.
* **💬 Add Comments:** Insert comments above the current line with a custom prefix (e.g., `AI!`, `AI?`). This automatically starts the Aider terminal, if it's not already running, and brings it to the forefront.

## ⚠️ Prerequisites

This plugin integrates with existing command-line AI tools. You need to install the specific tools you want to use *before* configuring them in this plugin.

Here are links to some of the tools mentioned in the default configuration:

* **Aider:** [Aider](https://github.com/paul-gauthier/aider)
* **Claude Code:** [Claude Code](https://github.com/anthropics/claude-code)
* **Goose CLI:** [Goose](https://github.com/pressly/goose)
* **Kode:** [Kode](https://github.com/dnakov/anon-kode)

Make sure these (or your chosen alternatives) are installed and accessible in your system's `PATH`.

## 🔗 Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal window management. 🍬

## 🔧 Configuration

You can optionally configure the plugin using the `setup` function. This allows you to define your own terminals or override the default commands and settings.

**Note:** Calling `setup()` is only necessary if you want to customize the default configuration (e.g., change terminal commands, window dimensions, or the default position). The core functionality, including autocommands for file reloading and backup syncing, works out-of-the-box without calling `setup()`.

```lua
-- In your Neovim configuration (e.g., lua/plugins/ai-terminals.lua)
-- Only call setup if you need to customize defaults:
require("ai-terminals").setup({
  terminals = {
    -- Override the default aider command
    aider = {
      cmd = "aider --dark-mode --no-auto-commits",
    },
    -- Add a new custom terminal
    my_custom_ai = {
      cmd = "/path/to/my/ai/script --interactive",
    },
    -- Keep other defaults like 'goose', 'claude', 'aichat', 'kode' unless overridden
  },
  -- Override default window dimensions (optional)
  window_dimensions = {
    float = { width = 0.85, height = 0.85 }, -- Make float windows slightly smaller
    bottom = { width = 1.0, height = 0.4 }, -- Make bottom windows wider and shorter
    -- Keep other position defaults ('top', 'left', 'right')
  },
  -- Tip: use `require("snacks.toggle").zoom()` to make splits or float full-screen

  -- Set the default window position if none is specified (default: "float")
  default_position = "bottom", -- Example: Make terminals open at the bottom by default
  -- Enable/disable the diffing feature (default: true)
  -- When enabled, a backup sync runs on terminal entry, allowing `diff_changes` and `close_diff` to work.
  -- Disabling this (`false`) skips the backup sync and prevents diff commands from functioning.
  enable_diffing = false,
})
```

The `cmd` field for each terminal can be a `string` or a `function` that returns a string. Using a function allows the command to be generated dynamically *just before* the terminal is opened (e.g., to check `vim.o.background` at invocation time).

### 🚀 Example Usage

#### Using `lazy.nvim`

##### ⌨️ Basic Keymaps

```lua
-- lazy.nvim plugin specification
return {
  {
    "aweis89/ai-terminals.nvim",
    -- Example opts using functions for dynamic command generation (matches plugin defaults)
    opts = {
      terminals = {
        goose = {
          cmd = function()
            return string.format("GOOSE_CLI_THEME=%s goose", vim.o.background)
          end,
        },
        claude = {
          cmd = function()
            return string.format("claude config set -g theme %s && claude", vim.o.background)
          end,
        },
        aider = {
          cmd = function()
            return string.format("aider --watch-files --%s-mode", vim.o.background)
          end,
        },
        aichat = {
          cmd = function()
            return string.format(
              "AICHAT_LIGHT_THEME=%s aichat -r %%functions%% --session",
              tostring(vim.o.background == "light") -- Convert boolean to string "true" or "false"
            )
          end,
        },
        kode = {
            cmd = function()
                return string.format("kode config set -g theme %s && kode", vim.o.background)
            end,
        },
        -- Example of a simple string command
        -- my_simple_ai = { cmd = "my_ai_tool --interactive" },
      },
    },
    keys = {
      -- Diff Tools
      {
        "<leader>dvo",
        function()
          require("ai-terminals").diff_changes()
        end,
        desc = "Show diff of last changes made",
      },
      {
        "<leader>dvc",
        function()
          require("ai-terminals").close_diff()
        end,
        desc = "Close all diff views (and wipeout buffers)",
      },
      -- Example Keymaps (using default terminal names: 'claude', 'goose', 'aider', 'aichat', 'kode')
      -- Claude Keymaps
      {
        "<leader>atc", -- Mnemonic: AI Terminal Claude
        function()
          require("ai-terminals").toggle("claude")
        end,
        desc = "Toggle Claude terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adc", -- Mnemonic: AI Diagnostics Claude
        function()
          require("ai-terminals").send_diagnostics("claude")
        end,
        desc = "Send diagnostics to Claude",
        mode = { "n", "v" }, -- Allow sending buffer or selection diagnostics
      },
      -- Goose Keymaps
      {
        "<leader>atg", -- Mnemonic: AI Terminal Goose
        function()
          require("ai-terminals").toggle("goose")
        end,
        desc = "Toggle Goose terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adg", -- Mnemonic: AI Diagnostics Goose
        function()
          require("ai-terminals").send_diagnostics("goose")
        end,
        desc = "Send diagnostics to Goose",
        mode = { "n", "v" },
      },
      -- Aider Keymaps
      {
        "<leader>ata", -- Mnemonic: AI Terminal Aider
        function()
          require("ai-terminals").toggle("aider")
        end,
        desc = "Toggle Aider terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>ac",
        function()
          require("ai-terminals").aider_comment("AI!") -- Adds comment and saves file
        end,
        desc = "Add 'AI!' comment above line",
      },
      {
        "<leader>aC",
        function()
          require("ai-terminals").aider_comment("AI?") -- Adds comment and saves file
        end,
        desc = "Add 'AI?' comment above line",
      },
      {
        "<leader>al",
        function()
          -- add current file
          require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") })
        end,
        desc = "Add current file to Aider (/add)",
      },
      {
        "<leader>aR", -- Mnemonic: AI add Read-only
        function()
          -- add current file as read-only
          require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") }, { read_only = true })
        end,
        desc = "Add current file to Aider (read-only)",
      },
      {
        "<leader>aL", -- Mnemonic: AI add Listed buffers
        function()
          require("ai-terminals").aider_add_buffers()
        end,
        desc = "Add all listed buffers to Aider",
      },
      {
        "<leader>ada", -- Mnemonic: AI Diagnostics Aider
        function()
          require("ai-terminals").send_diagnostics("aider")
        end,
        desc = "Send diagnostics to Aider",
        mode = { "n", "v" },
      },
      -- aichat Keymaps
      {
        "<leader>ati", -- Mnemonic: AI Terminal AI Chat
        function()
          require("ai-terminals").toggle("aichat")
        end,
        desc = "Toggle AI Chat terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adi", -- Mnemonic: AI Diagnostics AI Chat
        function()
          require("ai-terminals").send_diagnostics("aichat")
        end,
        desc = "Send diagnostics to AI Chat",
        mode = { "n", "v" },
      },
      -- Kode Keymaps
      {
        "<leader>atk", -- Mnemonic: AI Terminal Kode
        function()
          require("ai-terminals").toggle("kode")
        end,
        desc = "Toggle Kode terminal (sends selection in visual mode)",
        mode = { "n", "v" },
      },
      {
        "<leader>adk", -- Mnemonic: AI Diagnostics Kode
        function()
          require("ai-terminals").send_diagnostics("kode")
        end,
        desc = "Send diagnostics to Kode",
        mode = { "n", "v" },
      },
      -- Example: Run a command and send output to a specific terminal (e.g., Aider)
      {
        "<leader>ar", -- Mnemonic: AI Run command
        function()
          -- Prompt user for command
          require("ai-terminals").send_command_output("aider")
          -- Or use a fixed command like:
          -- require("ai-terminals").send_command_output("aider", "make test")
        end,
        desc = "Run command (prompts) and send output to Aider terminal",
      },
      {
        "<leader>ax", -- Mnemonic: AI Destroy (X) all terminals
        function()
          require("ai-terminals").destroy_all()
        end,
        desc = "Destroy all AI terminals (closes windows, stops processes)",
      },
      {
        "<leader>af", -- Mnemonic: AI Focus
        function()
          require("ai-terminals").focus()
        end,
        desc = "Focus the last used AI terminal window",
      },
    },
  },
}
```

#### Using `packer.nvim`

If you are using `packer.nvim`, you only need to call the `setup` function in your configuration if you want to customize the defaults.

```lua
-- In your Neovim configuration (e.g., lua/plugins.lua or similar)
use({
  "aweis89/ai-terminals.nvim",
  requires = { "folke/snacks.nvim" }, -- Make sure dependencies are loaded
  config = function()
    -- Only call setup if you need to customize defaults:
    require("ai-terminals").setup({
      -- Your custom configuration goes here (optional)
      terminals = {
        aider = {
          cmd = "aider --dark-mode --no-auto-commits", -- Example override
        },
        -- Add other terminals or keep defaults
      },
    })

    -- Define your keymaps here or in a separate keymap file

    -- Diff Tools
    vim.keymap.set("n", "<leader>dvo", function() require("ai-terminals").diff_changes() end, { desc = "Show diff of last changes made" })
    vim.keymap.set("n", "<leader>dvc", function() require("ai-terminals").close_diff() end, { desc = "Close all diff views (and wipeout buffers)" })

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
    vim.keymap.set("n", "<leader>al", function() require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") }) end, { desc = "Add current file to Aider (/add)" })
    vim.keymap.set("n", "<leader>aR", function() require("ai-terminals").aider_add_files({ vim.fn.expand("%:p") }, { read_only = true }) end, { desc = "Add current file to Aider (read-only)" })
    vim.keymap.set("n", "<leader>aL", function() require("ai-terminals").aider_add_buffers() end, { desc = "Add all listed buffers to Aider" })
    vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

    -- aichat Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ati", function() require("ai-terminals").toggle("aichat") end, { desc = "Toggle AI Chat terminal (sends selection in visual mode)" })
    vim.keymap.set({"n", "v"}, "<leader>adi", function() require("ai-terminals").send_diagnostics("aichat") end, { desc = "Send diagnostics to AI Chat" })

    -- Kode Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atk", function() require("ai-terminals").toggle("kode") end, { desc = "Toggle Kode terminal (sends selection in visual mode)" })
    vim.keymap.set({"n", "v"}, "<leader>adk", function() require("ai-terminals").send_diagnostics("kode") end, { desc = "Send diagnostics to Kode" })

    -- Example: Run a command and send output to a specific terminal (e.g., Aider)
    vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider") end, { desc = "Run command (prompts) and send output to Aider terminal" })
    -- Or use a fixed command like:
    -- vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider", "make test") end, { desc = "Run 'make test' and send output to Aider terminal" })

   -- Destroy All Terminals
   vim.keymap.set("n", "<leader>ax", function() require("ai-terminals").destroy_all() end, { desc = "Destroy all AI terminals (closes windows, stops processes)" })

   -- Focus Terminal
   vim.keymap.set("n", "<leader>af", function() require("ai-terminals").focus() end, { desc = "Focus the last used AI terminal window" })
  end,
})
```

**Note on `destroy_all`:** This function stops the underlying processes associated with the AI terminals and closes their windows/buffers using the underlying `Snacks` library's `destroy()` method. The next time you use `toggle` or `open` for a specific AI tool, a completely new instance of that tool will be started.

#### 🤝 Integrating with a File Picker (e.g., snacks.nvim)

You can integrate the `aider_add_files` function with file pickers like `snacks.nvim` to easily add selected files to the Aider context.

Here's an example of how you might configure `snacks.nvim` to add actions for sending files to Aider:

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)

-- Helper function to extract files from a snacks picker and send them to aider
---@param picker snacks.Picker
---@param opts? { read_only?: boolean } Options for the command
local function add_files_from_picker(picker, opts)
  local selected = picker:selected({ fallback = true })
  local files_to_add = {}
  for _, item in pairs(selected) do
    table.insert(files_to_add, item.file)
  end
  require("ai-terminals").aider_add_files(files_to_add, opts)
end

-- Snacks picker opts:
{
  picker = {
    actions = {
      ["aider_add"] = function(picker)
        picker:close()
        add_files_from_picker(picker) -- Defaults to { read_only = false } -> /add
      end,
      ["aider_read_only"] = function(picker)
        picker:close()
        add_files_from_picker(picker, { read_only = true }) -- Send /read-only
      end,
      -- ... other actions
    },
    sources = {
      -- Add keymaps to relevant pickers (e.g., files, git_status)
      files = {
        win = {
          input = {
            keys = {
              ["<leader><space>a"] = { "aider_add", mode = { "n", "i" } },
              ["<leader><space>A"] = { "aider_read_only", mode = { "n", "i" } },
              -- ... other keys
            },
          },
        },
      },
      git_status = {
         win = {
          input = {
            keys = {
              ["<leader><space>a"] = { "aider_add", mode = { "n", "i" } },
              ["<leader><space>A"] = { "aider_read_only", mode = { "n", "i" } },
              -- ... other keys
            },
          },
        },
      },
      -- ... other sources
    },
  },
}

-- Make sure to merge these overrides with your existing snacks options
-- return vim.tbl_deep_extend("force", opts or {}, overrides)

```

This setup defines two actions, `aider_add` and `aider_read_only`, which use the helper function `add_files_from_picker` to collect selected file paths from the picker and pass them to `require("ai-terminals").aider_add_files`. Keymaps are then added to specific picker sources (like `files` and `git_status`) to trigger these actions.

##### 🔍 Sending Grep Results to Aider

Similarly, you can configure Snacks to send selected lines from a grep search directly to the Aider terminal.

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)

--- Helper function to extract search results and send them to aider
---@param picker snacks.Picker
local function send_search(picker)
  local selected = picker:selected({ fallback = true })
  local items = {}
  for _, item in pairs(selected) do
    table.insert(items, item.text) -- Send the full line text from grep
  end
  -- Get the aider terminal instance (assuming it's named 'aider')
  local term = require("ai-terminals").get("aider")
  -- Send the concatenated lines to the terminal
  require("ai-terminals").send(table.concat(items, "\n"), { term = term })
end

-- Snacks picker opts:
{
  picker = {
    actions = {
      -- ... other actions like aider_add, aider_read_only ...
      ["aider_search"] = function(picker)
        picker:close()
        send_search(picker)
      end,
    },
    sources = {
      -- ... other sources like files, git_status ...
      grep = { -- Apply to the grep picker
        win = {
          input = {
            keys = {
              -- Add a keymap to send selected grep lines
              ["<leader><space>s"] = { "aider_search", mode = { "n", "i" } },
              -- You might also want the file adding keys here too
              ["<leader><space>a"] = { "aider_add", mode = { "n", "i" } },
              ["<leader><space>A"] = { "aider_read_only", mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },
}

-- Make sure to merge these overrides with your existing snacks options
-- return vim.tbl_deep_extend("force", opts or {}, overrides)
```

This adds a `send_search` helper function that extracts the text lines from the selected items in the picker (typically grep results) and sends them concatenated together to the Aider terminal using `require("ai-terminals").send`. An `aider_search` action is defined to use this helper, and a keymap (`<leader><space>s`) is added to the `grep` source to trigger this action.

💡 **Tip:** You can use `<Tab>` in the Snacks picker to select multiple items (files or grep lines) one by one, or `<C-a>` (Control-A) to select *all* visible items. When you then use the `aider_add` or `aider_search` keymaps, all selected items will be sent to Aider at once!
