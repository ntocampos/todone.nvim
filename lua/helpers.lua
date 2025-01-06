local helpers = {}

--- @param mode string
--- @param key string
--- @param cmd string | function
--- @param buf number
function helpers.set_keymap(mode, key, cmd, buf)
  buf = buf or 0
  vim.keymap.set(mode, key, cmd, { buffer = buf })
end

--- @param file_path string
--- @return string[]
function helpers.read_file_lines(file_path)
  file_path = helpers.replace_home_path(file_path)

  local file = io.open(file_path, "r")
  if not file then
    vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
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
function helpers.create_floating_window(opts)
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
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  helpers.set_keymap("n", "q", close_win, buf)

  local lines = opts.lines or {}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function helpers.replace_home_path(path)
  local home = os.getenv("HOME") or ""
  return path:gsub("^~", home)
end

function helpers.check_dir_exists(dir)
  local stat = vim.loop.fs_stat(dir)
  return stat and stat.type == "directory"
end

return helpers
