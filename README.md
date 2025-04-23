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
* **Consistency:** Provides a consistent workflow (sending
  selections/diagnostics, diffing, reversing changes and creating prompts)
  across different tools.
* **Leverages Existing Tools:** Benefits from the features and updates of the
  underlying CLI tools themselves.

This plugin is ideal for users who prefer terminal-based AI interaction and
want a single, configurable way to manage them within Neovim.

## ✨ Features

### ⚙️ Generic Features (Works with any terminal-based AI agent)

* **🔌 Configurable Terminal Integration:** Define and manage terminals for
  various AI CLI tools (e.g., Claude, Goose, Aider, Kode, custom scripts)
  through a simple configuration table. Uses `Snacks` for terminal window
  management.
* **🔄 Diff View & Revert:**
  * **Track Changes:** See modifications made to your project files since the
    last time an AI terminal was opened.
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
  path and language type included.

  *Tip:* After sending the selection, ai-terminal doesn't send the enter key so
  you can add custom prompts to the selection. This is a goto way of sending
  prompts with context so the LLM knows which code the prompt pertains to
  (similar to the add comment command for Aider).

  The format of the visual selection in the terminal will look a bit strange
  (e.g. shows ^I in-place of tabs). This is because it's using bracketed paste
  mode which is a uniform way of sending multi-line text (without "\n"
  submitting the prompt).
* **🩺 Send Diagnostics:** Send diagnostics (errors, warnings, etc.) for the
  current buffer or visual selection to the AI terminal, formatted with
  severity, line/column numbers, messages, and the corresponding source code
  lines.
* **🚀 Run Command and Send Output:** Execute an arbitrary shell command and send
  its standard output along with the exit code to the active AI terminal. This
  is useful for running tests, linters, or other tools and feeding the results
  directly to the AI.

### 🔥 Aider Specific Features

While the generic features work well with Aider, this plugin includes
additional helpers specifically for Aider:

* **➕ Add Files:** Quickly add the current file or a list of files to the Aider
  chat context using `/add` or `/read-only`.
* **➕ Add Buffers:** Add all currently listed buffers to the Aider chat context.
* **💬 Add Comments:** Insert comments above the current line with a custom
  prefix (e.g., `AI!`, `AI?`). This automatically starts the Aider terminal, if
  it's not already running, and brings it to the forefront.

## ⚠️ Prerequisites

This plugin integrates with existing command-line AI tools. You need to install
the specific tools you want to use *before* configuring them in this plugin.

Here are links to some of the tools mentioned in the default configuration:

* **Aider:** [Aider](https://github.com/paul-gauthier/aider)
* **Claude CLI:** [Claude CLI](https://github.com/anthropics/claude-cli)
* **Goose:** [Goose](https://github.com/aweis89/goose)
* **AI Chat:** [AI Chat](https://github.com/sigoden/aichat)
* **Kode:** [Kode](https://github.com/dnakov/anon-kode)
* **Delta (Optional, for diffing):** [Delta](https://github.com/dandavison/delta)

Make sure these (or your chosen alternatives) are installed and accessible in
your system's `PATH`.

## 🔗 Dependencies

* [Snacks.nvim](https://github.com/folke/snacks.nvim): Required for terminal
  window management. 🍬

## 🔧 Configuration

You can optionally configure the plugin using the `setup` function. This allows
you to define your own terminals or override the default commands and settings.

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
        -- Use a different theme based on background
        return string.format("aider --watch-files --%s-mode --theme %s", vim.o.background, vim.o.background)
      end,
    },
    -- Example: Add a new terminal for a custom script
    my_custom_ai = {
      cmd = "/path/to/my/ai_script.sh --interactive",
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
})
```

The `cmd` field for each terminal can be a `string` or a `function` that returns
a string. Using a function allows the command to be generated dynamically *just
before* the terminal is opened (e.g., to check `vim.o.background` at invocation
time).

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
        },
        aichat = {
          cmd = function()
            return string.format(
              "AICHAT_LIGHT_THEME=%s aichat -r %%functions%% --session",
              -- Convert boolean to string "true" or "false"
              tostring(vim.o.background == "light")
            )
          end,
        },
        claude = {
          cmd = function()
            return string.format("claude config set -g theme %s && claude", vim.o.background)
          end,
        },
        kode = {
          cmd = function()
            return string.format("kode config set -g theme %s && kode", vim.o.background)
          end,
        },
        aider = {
          cmd = function()
            return string.format("aider --watch-files --%s-mode", vim.o.background)
          end,
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
      -- 'aider', 'aichat', 'kode')
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
      {
        "<leader>al", -- Mnemonic: AI add Local file
        function()
          -- add current file (path conversion happens inside)
          require("ai-terminals").aider_add_files(vim.fn.expand("%"))
        end,
        desc = "Add current file to Aider (/add)",
      },
      {
        "<leader>aR", -- Mnemonic: AI add Read-only
        function()
          -- add current file as read-only (path conversion happens inside)
          require("ai-terminals").aider_add_files(vim.fn.expand("%"), { read_only = true })
        end,
        desc = "Add current file to Aider (read-only)",
      },
      {
        "<leader>aL", -- Mnemonic: AI add Listed buffers
        function() require("ai-terminals").aider_add_buffers() end,
        desc = "Add all listed buffers to Aider",
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
      -- Kode Keymaps
      {
        "<leader>atk",
        function() require("ai-terminals").toggle("kode") end,
        mode = { "n", "v" },
        desc = "Toggle Kode terminal (sends selection in visual mode)",
      },
      {
        "<leader>adk",
        function() require("ai-terminals").send_diagnostics("kode") end,
        mode = { "n", "v" },
        desc = "Send diagnostics to Kode",
      },
      -- Run Command and Send Output
      {
        "<leader>ar", -- Mnemonic: AI Run command
        function()
          -- Prompts user for command, then sends output to Aider
          require("ai-terminals").send_command_output("aider")
        end,
        desc = "Run command (prompts) and send output to Aider terminal",
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
        vim.keymap.set({"n", "v"}, "<leader>atc", function() require("ai-terminals").toggle("claude") end, { desc = "Toggle Claude terminal (sends selection)" })
        vim.keymap.set({"n", "v"}, "<leader>adc", function() require("ai-terminals").send_diagnostics("claude") end, { desc = "Send diagnostics to Claude" })

        -- Goose Keymaps
        vim.keymap.set({"n", "v"}, "<leader>atg", function() require("ai-terminals").toggle("goose") end, { desc = "Toggle Goose terminal (sends selection)" })
        vim.keymap.set({"n", "v"}, "<leader>adg", function() require("ai-terminals").send_diagnostics("goose") end, { desc = "Send diagnostics to Goose" })

        -- Aider Keymaps
        vim.keymap.set({"n", "v"}, "<leader>ata", function() require("ai-terminals").toggle("aider") end, { desc = "Toggle Aider terminal (sends selection)" })
        vim.keymap.set("n", "<leader>ac", function() require("ai-terminals").aider_comment("AI!") end, { desc = "Add 'AI!' comment above line" })
        vim.keymap.set("n", "<leader>aC", function() require("ai-terminals").aider_comment("AI?") end, { desc = "Add 'AI?' comment above line" })
        vim.keymap.set("n", "<leader>al", function() require("ai-terminals").aider_add_files(vim.fn.expand("%")) end, { desc = "Add current file to Aider (/add)" })
        vim.keymap.set("n", "<leader>aR", function() require("ai-terminals").aider_add_files(vim.fn.expand("%"), { read_only = true }) end, { desc = "Add current file to Aider (read-only)" })
        vim.keymap.set("n", "<leader>aL", function() require("ai-terminals").aider_add_buffers() end, { desc = "Add all listed buffers to Aider" })
        vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

        -- aichat Keymaps
        vim.keymap.set({"n", "v"}, "<leader>ati", function() require("ai-terminals").toggle("aichat") end, { desc = "Toggle AI Chat terminal (sends selection)" })
        vim.keymap.set({"n", "v"}, "<leader>adi", function() require("ai-terminals").send_diagnostics("aichat") end, { desc = "Send diagnostics to AI Chat" })

        -- Kode Keymaps
        vim.keymap.set({"n", "v"}, "<leader>atk", function() require("ai-terminals").toggle("kode") end, { desc = "Toggle Kode terminal (sends selection)" })
        vim.keymap.set({"n", "v"}, "<leader>adk", function() require("ai-terminals").send_diagnostics("kode") end, { desc = "Send diagnostics to Kode" })

        -- Example: Run a command and send output to a specific terminal
        vim.keymap.set("n", "<leader>ar", function() require("ai-terminals").send_command_output("aider") end, { desc = "Run command (prompts) and send output to Aider" })
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
    vim.keymap.set("n", "<leader>al", function() require("ai-terminals").aider_add_files(vim.fn.expand("%")) end, { desc = "Add current file to Aider (/add)" })
    vim.keymap.set("n", "<leader>aR", function() require("ai-terminals").aider_add_files(vim.fn.expand("%"), { read_only = true }) end, { desc = "Add current file to Aider (read-only)" })
    vim.keymap.set("n", "<leader>aL", function() require("ai-terminals").aider_add_buffers() end, { desc = "Add all listed buffers to Aider" })
    vim.keymap.set({"n", "v"}, "<leader>ada", function() require("ai-terminals").send_diagnostics("aider") end, { desc = "Send diagnostics to Aider" })

    -- aichat Keymaps
    vim.keymap.set({"n", "v"}, "<leader>ati", function() require("ai-terminals").toggle("aichat") end, { desc = "Toggle AI Chat terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adi", function() require("ai-terminals").send_diagnostics("aichat") end, { desc = "Send diagnostics to AI Chat" })

    -- Kode Keymaps
    vim.keymap.set({"n", "v"}, "<leader>atk", function() require("ai-terminals").toggle("kode") end, { desc = "Toggle Kode terminal (sends selection)" })
    vim.keymap.set({"n", "v"}, "<leader>adk", function() require("ai-terminals").send_diagnostics("kode") end, { desc = "Send diagnostics to Kode" })

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

#### 🤝 Integrating with a File Picker (e.g., snacks.nvim)

You can integrate the `aider_add_files` function with file pickers like
`snacks.nvim` to easily add selected files to the Aider context.

Here's an example of how you might configure `snacks.nvim` to add actions for
sending files to Aider:

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)
local snacks = require("snacks")
local ai_terminals = require("ai-terminals") -- Make sure ai-terminals is loaded

-- Helper function to get selected file paths from the picker
local function add_files_from_picker(picker, read_only)
  local selected_items = picker:get_selected_items()
  if not selected_items or #selected_items == 0 then
    vim.notify("No files selected in picker", vim.log.levels.WARN)
    return
  end

  local files_to_add = {}
  for _, item in ipairs(selected_items) do
    -- Assuming item.filename holds the full path
    if item.filename then
      table.insert(files_to_add, item.filename)
    end
  end

  if #files_to_add > 0 then
    ai_terminals.aider_add_files(files_to_add, { read_only = read_only })
  else
    vim.notify("Could not extract filenames from selected items", vim.log.levels.WARN)
  end
end

-- Define actions for Snacks
local actions = {
  aider_add = function(picker)
    add_files_from_picker(picker, false) -- Add normally
  end,
  aider_read_only = function(picker)
    add_files_from_picker(picker, true) -- Add as read-only
  end,
}

-- Configure Snacks sources to use these actions
snacks.setup({
  -- ... your other snacks config ...
  sources = {
    files = {
      -- ... your files source config ...
      actions = {
        ["<leader><space>a"] = actions.aider_add,
        ["<leader><space>r"] = actions.aider_read_only,
      },
    },
    git_status = {
      -- ... your git_status source config ...
      actions = {
        ["<leader><space>a"] = actions.aider_add,
        ["<leader><space>r"] = actions.aider_read_only,
      },
    },
    -- ... other sources ...
  },
})

-- Optional: Add keymaps to open Snacks with these sources
-- vim.keymap.set("n", "<leader>pf", function() snacks.show("files") end, { desc = "Pick Files (Snacks)" })
-- vim.keymap.set("n", "<leader>pg", function() snacks.show("git_status") end, { desc = "Pick Git Status (Snacks)" })
```

This setup defines two actions, `aider_add` and `aider_read_only`, which use the
helper function `add_files_from_picker` to collect selected file paths from the
picker and pass them to `require("ai-terminals").aider_add_files`. Keymaps are
then added to specific picker sources (like `files` and `git_status`) to
trigger these actions.

##### 🔍 Sending Grep Results to Aider

Similarly, you can configure Snacks to send selected lines from a grep search
directly to the Aider terminal.

```lua
-- In your snacks.nvim configuration (e.g., lua/plugins/snacks.lua)
local snacks = require("snacks")
local ai_terminals = require("ai-terminals") -- Ensure ai-terminals is loaded

-- Helper function to send selected grep lines to Aider
local function send_search_results_to_aider(picker)
  local selected_items = picker:get_selected_items()
  if not selected_items or #selected_items == 0 then
    vim.notify("No lines selected in picker", vim.log.levels.WARN)
    return
  end

  local lines_to_send = {}
  for _, item in ipairs(selected_items) do
    -- Assuming item.text holds the grep line content
    if item.text then
      table.insert(lines_to_send, item.text)
    end
  end

  if #lines_to_send > 0 then
    -- Send the concatenated lines to the *active* or *last used* Aider
    -- terminal. Note: This uses the generic 'send' function, assuming Aider
    -- is the target. You might need to adjust if you have multiple terminals
    -- open.
    ai_terminals.send_term("aider", table.concat(lines_to_send, "\n"))
    -- Optionally focus the aider terminal after sending
    -- ai_terminals.focus()
  else
    vim.notify("Could not extract text from selected items", vim.log.levels.WARN)
  end
end

-- Define an action for sending search results
local actions = {
  aider_search = function(picker)
    send_search_results_to_aider(picker)
  end,
  -- Include your aider_add and aider_read_only actions from the previous
  -- example if needed
}

-- Configure the grep source in Snacks
snacks.setup({
  -- ... your other snacks config ...
  sources = {
    grep = {
      -- ... your grep source config ...
      actions = {
        ["<leader><space>s"] = actions.aider_search, -- Mnemonic: Send Search
      },
    },
    -- Include your files and git_status sources with their actions here
  },
})

-- Optional: Add a keymap to open the grep source
-- vim.keymap.set("n", "<leader>ps", function() snacks.show("grep") end, { desc = "Pick Grep (Snacks)" })

-- Example of overriding default grep options if needed
-- local overrides = {
--   grep = {
--     cmd = "rg",
--     args = function(opts)
--       return { "--vimgrep", "--no-heading", "--smart-case", opts.query }
--     end,
--     -- Add your actions here as well if overriding the whole source table
--     actions = {
--       ["<leader><space>s"] = actions.aider_search,
--     },
--   },
-- }
-- return vim.tbl_deep_extend("force", opts or {}, overrides)
```

This adds a `send_search` helper function that extracts the text lines from the
selected items in the picker (typically grep results) and sends them
concatenated together to the Aider terminal using
`require("ai-terminals").send`. An `aider_search` action is defined to use this
helper, and a keymap (`<leader><space>s`) is added to the `grep` source to
trigger this action.

💡 **Tip:** You can use `<Tab>` in the Snacks picker to select multiple items
(files or grep lines) one by one, or `<C-a>` (Control-A) to select *all*
visible items. When you then use the `aider_add` or `aider_search` keymaps, all
selected items will be sent to Aider at once!

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Please feel free to
check the [issues page](https://github.com/aweis89/ai-terminals.nvim/issues).

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.
