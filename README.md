### Example usage with lazy.nvim

lua```
local plug = function()
  return require("ai-terminals")
end

return {
  {
    "aweis89/ai-terminals.nvim",
    event = "VeryLazy",
    keys = {
      -- Diff Tools
      {
        "<leader>dvo",
        function()
          plug().diff_with_tmp()
        end,
        desc = "Compare with tmp directory backup",
      },
      -- Claude Keymaps
      {
        "<leader>ass",
        function()
          plug().claude_terminal()
        end,
        desc = "Toggle Claude terminal",
      },
      {
        "<leader>ass",
        function()
          plug().send_selection(plug().claude_terminal)
        end,
        desc = "Send selection to Claude",
        mode = { "v" },
      },
      {
        "<leader>asd",
        function()
          local diagnostics = plug().diagnostics()
          plug().claude_terminal()
          plug().send(diagnostics)
        end,
        desc = "Send diagnostics to Claude",
        mode = { "v" },
      },
      -- Goose Keymaps
      {
        "<leader>agg",
        function()
          plug().goose_terminal()
        end,
        desc = "Toggle Goose terminal",
      },
      {
        "<leader>agg",
        function()
          local selection = plug().get_visual_selection_with_header()
          plug().goose_terminal()
          plug().send(selection)
        end,
        desc = "Send selection to Goose",
        mode = { "v" },
      },
      {
        "<leader>agd",
        function()
          local diagnostics = plug().diagnostics()
          plug().goose_terminal()
          plug().send(diagnostics)
        end,
        desc = "Send diagnostics to Goose",
        mode = { "v" },
      },
      -- Aider Keymaps
      {
        "<leader>aa",
        function()
          plug().aider_terminal()
        end,
        desc = "Toggle Aider terminal",
      },
      {
        "<leader>ac",
        function()
          plug().aider_comment("AI!")
        end,
        desc = "Add comment above line",
      },
      {
        "<leader>aC",
        function()
          plug().aider_comment("AI?")
        end,
        desc = "Add comment above line",
      },
      {
        "<leader>al",
        function()
          local current_file = vim.fn.expand("%:p")
          plug().aider_terminal()
          plug().send("/add " .. current_file .. "\n")
        end,
        desc = "Add file to Aider",
      },
      {
        "<leader>aa",
        function()
          local selection = plug().get_visual_selection_with_header()
          plug().aider_terminal()
          plug().send(plug().aider_multiline(selection))
          vim.api.nvim_feedkeys("i", "n", false)
        end,
        desc = "Send selection to Aider",
        mode = { "v" },
      },
      {
        "<leader>ad",
        function()
          local diagnostics = plug().diagnostics()
          plug().aider_terminal()
          plug().send(plug().aider_multiline(diagnostics))
        end,
        desc = "Send diagnostics to Aider",
        mode = { "v" },
      },
    },
  },
}

```lua
```
