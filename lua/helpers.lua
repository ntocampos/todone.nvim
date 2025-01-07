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

--- @param opts { width: number, height: number, lines: string[], file_path: string, title: string }
function helpers.create_floating_window(opts)
  opts = opts or {}
  local file_path = opts.file_path or ""
  local title = opts.title or "Todone"

  local buf = vim.api.nvim_create_buf(false, false)
  if file_path ~= "" then
    vim.api.nvim_buf_set_name(buf, file_path)
    vim.api.nvim_set_option_value("buftype", "", { buf = buf })
  end

  vim.bo[buf].filetype = "markdown"

  local float_width = opts.width or 80
  local float_height = opts.height or 20
  local float_row = (vim.o.lines - float_height) / 2
  local float_col = (vim.o.columns - float_width) / 2
  local win_opts = {
    relative = "editor",
    width = float_width,
    height = float_height,
    row = float_row,
    col = float_col,
    style = "minimal",
    border = "rounded",
    title = "  " .. title .. "  ",
    title_pos = "center",
  }

  local win_id = vim.api.nvim_open_win(buf, true, win_opts)
  local augroup = vim.api.nvim_create_augroup("FloatingWindowAutoSave", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    buffer = buf,
    callback = function()
      if file_path and vim.fn.filereadable(file_path) == 1 then
        vim.api.nvim_command("write!")
      end
    end,
  })
  vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
  vim.api.nvim_set_option_value("number", true, { win = win_id })

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

function helpers.check_file_exists(file_path)
  local stat = vim.loop.fs_stat(file_path)
  return stat and stat.type == "file"
end

local function get_note_metadata(date_table)
  local formatted_date = os.date("%Y-%m-%d", os.time(date_table))
  local formatted_title = os.date("%B %d, %Y", os.time(date_table))
  return "---\n" ..
      "id: \"" .. formatted_date .. "\"\n" ..
      "aliases:\n" ..
      "  - \"" .. formatted_title .. "\"\n" ..
      "tags:\n" ..
      "  - daily-notes\n" ..
      "---\n" ..
      "\n" ..
      "# " .. formatted_title .. "\n\n"
end

function helpers.create_file(file_path, date_table)
  local file = io.open(file_path, "w")
  if not file then
    vim.notify("Failed to create file: " .. file_path, vim.log.levels.ERROR)
    return
  end
  local metadata = get_note_metadata(date_table)
  file:write(metadata)
  file:close()
end

return helpers
