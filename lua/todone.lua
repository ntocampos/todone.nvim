local M = {}

local set_keymap = function(mode, key, cmd, buf)
  buf = buf or 0
  vim.keymap.set(mode, key, cmd, { buffer = buf })
end

local create_floating_window = function(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  local float_width = opts.width or 80
  local float_height = opts.height or 20
  local float_row = (vim.o.lines - float_height) / 2
  local float_col = (vim.o.columns - float_width) / 2
  local win_id = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = float_width,
    height = float_height,
    row = float_row,
    col = float_col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hello, world!" })
  local close_buf = function()
    vim.api.nvim_win_close(win_id, true)
  end

  set_keymap("n", "q", close_buf, buf)
end

create_floating_window({})

return M
