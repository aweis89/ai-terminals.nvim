-- Helper for inserting a prefixed line comment above the cursor.
-- Not part of the public API; modules within this plugin may require it directly.

---@param prefix string|nil Prefix placed before the user's text (default: "AI!")
---@param callback fun(ctx: { bufnr: integer, comment_text: string, prefix: string, formatted_comment: string })|nil
---@return nil
return function(prefix, callback)
  prefix = prefix or "AI!"
  local bufnr = vim.api.nvim_get_current_buf()

  vim.ui.input({ prompt = "Enter comment (" .. prefix .. "): " }, function(comment_text)
    if not comment_text then
      vim.notify("No comment entered")
      return
    end

    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    local cs = vim.bo.commentstring
    local comment_string = (cs and #cs > 0) and cs or "# %s"

    local formatted_prefix = " " .. prefix .. " "
    local formatted_comment
    if comment_string:find("%%s") then
      formatted_comment = comment_string:format(formatted_prefix .. comment_text)
    else
      formatted_comment = comment_string .. formatted_prefix .. comment_text
    end

    vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line - 1, false, { formatted_comment })
    vim.cmd.write()
    vim.cmd.stopinsert()

    if type(callback) == "function" then
      pcall(callback, {
        bufnr = bufnr,
        comment_text = comment_text,
        prefix = prefix,
        formatted_comment = formatted_comment,
      })
    end
  end)
end
