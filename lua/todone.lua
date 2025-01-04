local M = {}

--- @param mode string
--- @param key string
--- @param cmd string | function
--- @param buf number
local set_keymap = function(mode, key, cmd, buf)
  buf = buf or 0
  vim.keymap.set(mode, key, cmd, { buffer = buf })
end

--- @param file_path string
--- @return string[]
local read_file_lines = function(file_path)
  local home = os.getenv("HOME") or ""
  file_path = file_path:gsub("^~", home)

  local file = io.open(file_path, "r")
  if not file then
    print("File not found")
    return {}
  end

  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  return lines
end

--- @param opts { width: number, height: number, lines: string[] }
local create_floating_window = function(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"

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
    title = "  Todone  ",
    title_pos = "center",
  })
  local close_win = function()
    vim.api.nvim_win_close(win_id, true)
  end

  set_keymap("n", "q", close_win, buf)

  local lines = opts.lines or {}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function M.open()
  local lines = read_file_lines("~/Documents/Vaults/alloy/notes/dailies/2024-11-27.md")
  create_floating_window({ lines = lines })
end

function M.setup()
  -- TODO: Add keymaps, check if dir exists.
end

M.open()

return M
