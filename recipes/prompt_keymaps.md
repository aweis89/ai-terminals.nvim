# Recipes: Creating Keymaps for Predefined Prompts

This recipe demonstrates how to define a set of common prompts and dynamically create keymaps to send these prompts to specific AI terminals managed by `ai-terminals.nvim`. This allows for quick execution of frequent instructions tailored to different AI agents.

## 📝 Defining Prompts and Mappings

First, define your prompts in a Lua table. Then, create another table that maps keybindings to specific terminals and prompts.

```lua
-- In your Neovim configuration (e.g., lua/config/keymaps.lua or similar)
local ai_terminals = require("ai-terminals")

-- 1. Define your common prompts
local common_prompts = {
  explain_code = "Explain the selected code snippet.",
  refactor_code = "Refactor the selected code snippet for clarity and efficiency.",
  find_bugs = "Analyze the selected code snippet for potential bugs or issues.",
  write_tests = "Write unit tests for the selected code snippet.",
  summarize = "Summarize the provided text or code.",
}

-- 2. Define mappings: { key, terminal_name, prompt_key, description }
--    'prompt_key' refers to a key in the 'common_prompts' table.
local prompt_mappings = {
  -- Aider Mappings
  { "<leader>ape", "aider", "explain_code", "Aider: Explain selection" },
  { "<leader>apr", "aider", "refactor_code", "Aider: Refactor selection" },
  { "<leader>apb", "aider", "find_bugs", "Aider: Find bugs in selection" },
  { "<leader>apt", "aider", "write_tests", "Aider: Write tests for selection" },

  -- Claude Mappings (Example using a different terminal)
  { "<leader>cpe", "claude", "explain_code", "Claude: Explain selection" },
  { "<leader>cps", "claude", "summarize", "Claude: Summarize selection" },

  -- You can add mappings for other terminals (goose, aichat, kode, custom) here
}

-- 3. Create the keymaps dynamically
for _, mapping in ipairs(prompt_mappings) do
  local key = mapping
  local term_name = mapping
  local prompt_key = mapping
  local description = mapping

  -- Retrieve the actual prompt text
  local prompt_text = common_prompts[prompt_key]

  if prompt_text then
    vim.keymap.set("v", key, function()
      -- Get visual selection (optional, if your prompt implies using it)
      local selection = ai_terminals.get_visual_selection_with_header(0) -- 0 for current buffer

      -- Construct the final message (e.g., prompt + selection)
      -- Adjust this logic based on how you want to combine the prompt and selection
      local message_to_send
      if selection and selection ~= "" then
        message_to_send = prompt_text .. "\n\n" .. selection
      else
        -- If no selection, just send the prompt (or handle differently)
        message_to_send = prompt_text
        vim.notify("No visual selection found. Sending prompt only.", vim.log.levels.INFO)
      end

      -- Send the combined message to the specified terminal
      -- `send_term` will open the terminal if it's not already open.
      ai_terminals.send_term(term_name, message_to_send)

      -- Optional: Focus the terminal after sending
      -- ai_terminals.focus()
    end, { desc = description })
  else
    vim.notify("Invalid prompt key '" .. prompt_key .. "' for mapping: " .. key, vim.log.levels.ERROR)
  end
end

print("AI Terminals prompt keymaps created.")

```

## How it Works

1.  **`common_prompts` Table:** Stores reusable prompt strings with descriptive keys.
2.  **`prompt_mappings` Table:** Defines each keymap. It includes:
    *   The keybinding (e.g., `<leader>ape`).
    *   The target terminal name (must match a name configured in `ai-terminals`, like `aider` or `claude`).
    *   The key from `common_prompts` to use for the prompt text.
    *   A description for the keymap.
3.  **Dynamic Keymap Creation:** The code iterates through `prompt_mappings`. For each entry:
    *   It retrieves the prompt text from `common_prompts`.
    *   It creates a visual mode keymap (`vim.keymap.set("v", ...)`). You could adapt this for normal mode (`"n"`) if your prompts don't rely on selections.
    *   The keymap's function:
        *   Optionally gets the current visual selection using `ai_terminals.get_visual_selection_with_header()`.
        *   Constructs the final message, potentially combining the predefined prompt with the selection.
        *   Uses `ai_terminals.send_term(term_name, message_to_send)` to send the message. This function automatically handles opening the correct terminal if it's not already running.
        *   Includes error handling for invalid prompt keys.

This approach makes it easy to manage and extend your AI prompt workflows within Neovim.
