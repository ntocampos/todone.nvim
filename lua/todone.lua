local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local conf = require("telescope.config").values

local M = {}
M.config = {}
M.loaded = false

--- @param mode string
--- @param key string
--- @param cmd string | function
--- @param buf number
local function set_buffer_keymap(mode, key, cmd, buf)
  buf = buf or 0
  vim.keymap.set(mode, key, cmd, { buffer = buf })
end

--- @param path string
--- @return string, number
local function replace_tilde(path)
  local home = os.getenv("HOME") or ""
  return path:gsub("^~", home)
end

--- @param path string
--- @return string, number
local function replace_home_path(path)
  local home = os.getenv("HOME") or ""
  return path:gsub(home, "~")
end


--- @param file_path string
--- @return string[]
local function read_file_lines(file_path)
  file_path = replace_tilde(file_path)

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

--- @param opts {
---   width: number,
---   height: number,
---   lines: string[],
---   file_path: string,
---   title: string,
--- }
local function create_floating_window(opts)
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
        vim.api.nvim_command("silent write!")
      end
    end,
  })
  vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
  vim.api.nvim_set_option_value("number", true, { win = win_id })

  local close_win = function()
    vim.api.nvim_win_close(win_id, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  set_buffer_keymap("n", "q", close_win, buf)

  local lines = opts.lines or {}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- @param dir string
--- @return boolean
local function check_dir_exists(dir)
  ---@diagnostic disable-next-line: undefined-field
  local stat = vim.loop.fs_stat(dir)
  return stat and stat.type == "directory"
end

--- @param file_path string
--- @return boolean
local function check_file_exists(file_path)
  ---@diagnostic disable-next-line: undefined-field
  local stat = vim.loop.fs_stat(file_path)
  return stat and stat.type == "file"
end

--- @param date_table osdate|string
--- @return string
local function get_note_metadata(date_table)
  ---@diagnostic disable-next-line: param-type-mismatch
  local formatted_date = os.date("%Y-%m-%d", os.time(date_table))
  ---@diagnostic disable-next-line: param-type-mismatch
  local formatted_title = os.date("%B %d, %Y", os.time(date_table))
  return "---\n" ..
      "id: \"" .. formatted_date .. "\"\n" ..
      "aliases:\n" ..
      "  - \"" .. formatted_title .. "\"\n" ..
      "tags:\n" ..
      "  - daily-notes\n" ..
      "---\n" ..
      "\n"
end

--- @param date_table osdate|string
--- @return string
local function get_note_header(date_table)
  ---@diagnostic disable-next-line: param-type-mismatch
  local formatted_title = os.date("%A, %B %d, %Y", os.time(date_table))
  return "# " .. formatted_title .. "\n\n"
end

--- @param file_path string
--- @param date_table osdate|string
--- @param opts { include_metadata: boolean }
local function create_file(file_path, date_table, opts)
  opts = opts or {}
  local include_metadata = opts.include_metadata or false

  local file = io.open(file_path, "w")
  if not file then
    vim.notify("Failed to create file: " .. file_path, vim.log.levels.ERROR)
    return
  end
  local metadata = get_note_metadata(date_table)
  local header = get_note_header(date_table)

  if include_metadata then
    file:write(metadata)
  end

  file:write(header)
  file:close()
end

--- @param name string
--- @param fn function
--- @param opts? table
local function create_command(name, fn, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, fn, opts)
end

--- @param date_string string
--- @return osdate|string
local function parse_date(date_string)
  local year, month, day = date_string:match("(%d+)-(%d+)-(%d+)")
  return {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
  }
end

local function create_telescope_picker(files, title)
  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table {
      results = files,
      entry_maker = function(entry)
        local date = entry:match(".*/(%d+-%d+-%d+).md")
        local file_name = date .. ".md"
        return {
          value = entry,
          display = file_name,
          ordinal = file_name,
          date = date,
        }
      end,
    },
    sorter = conf.file_sorter(),
    previewer = conf.file_previewer({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = require("telescope.actions.state").get_selected_entry()
        print(vim.inspect(selection))
        local date = selection.date
        M.open({ date = date })
      end)
      return true
    end,
  }):find()
end

--- Plugin API

function M.open(opts)
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local date = opts.date
  if not date then
    vim.notify("No date provided", vim.log.levels.ERROR)
    return
  end

  local date_table = parse_date(date)
  ---@diagnostic disable-next-line: param-type-mismatch
  local date_formatted = os.date("%Y-%m-%d", os.time(date_table))
  local file_path = M.config.dir .. "/" .. date_formatted .. ".md"
  if not check_file_exists(file_path) then
    create_file(file_path, date_table, { include_metadata = M.config.include_metadata })
  end
  local lines = read_file_lines(file_path)
  create_floating_window({
    lines = lines,
    file_path = file_path,
    title = replace_home_path(file_path)
  })
end

function M.open_today()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local today_table = os.date("*t")
  ---@diagnostic disable-next-line: param-type-mismatch
  local today_formatted = os.date("%Y-%m-%d", os.time(today_table))

  local file_path = M.config.dir .. "/" .. today_formatted .. ".md"
  if not check_file_exists(file_path) then
    create_file(file_path, today_table, { include_metadata = M.config.include_metadata })
  end

  local lines = read_file_lines(file_path)
  create_floating_window({
    lines = lines,
    file_path = file_path,
    title = replace_home_path(file_path)
  })
end

function M.list()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local files = vim.fn.glob(M.config.dir .. "/*.md", false, true)
  local parsed_files = {}
  print(vim.inspect(files))
  for _, file in ipairs(files) do
    local date = file:match(".*/(%d+-%d+-%d+).md")
    local file_name = date .. ".md"
    table.insert(parsed_files, { value = date, display = file_name, ordinal = file_name })
  end
  print(vim.inspect(parsed_files))
  create_telescope_picker(files, "Todone Files")
end

function M.grep()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local files = vim.fn.glob(M.config.dir .. "/*.md", false, true)
  local parsed_files = {}
  for _, file in ipairs(files) do
    local date = file:match(".*/(%d+-%d+-%d+).md")
    local file_name = date .. ".md"
    table.insert(parsed_files, { value = date, display = file_name, ordinal = file_name })
  end
  -- Open Telescope's live grep
  require('telescope.builtin').live_grep({
    prompt_title = "Todone Live Grep",
    search_dirs = { M.config.dir },
    cwd = M.config.dir,
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = require("telescope.actions.state").get_selected_entry()
        print(vim.inspect(selection))
        local filename = selection.filename
        local date = filename:match(".*/(%d+-%d+-%d+).md")
        M.open({ date = date })
      end)
      return true
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  local dir = replace_tilde(opts.dir or "~/todone")
  M.config.dir = dir
  M.config.include_metadata = opts.include_metadata or false
  local keys = opts.keys or {}

  if not check_dir_exists(M.config.dir) then
    vim.notify("Directory not found: " .. M.config.dir, vim.log.levels.ERROR)
    return
  end

  create_command("TodoneToday", M.open_today)
  if keys.open_today then
    vim.keymap.set("n", keys.open_today, M.open_today, {
      desc = "Open Todone in today's view",
      silent = true
    })
  end

  create_command("TodoneOpen", function(args)
    local date = args.fargs[1]
    M.open({ date = date })
  end)

  create_command("TodoneList", M.list)
  if keys.list then
    vim.keymap.set("n", keys.list, M.list, {
      desc = "List Todone files",
      silent = true
    })
  end

  create_command("TodoneGrep", M.grep)
  if keys.grep then
    vim.keymap.set("n", keys.grep, M.grep, {
      desc = "Grep Todone files",
      silent = true
    })
  end

  M.loaded = true
end

-- TODO: remove this setup call
M.setup {
  dir = "~/Developer/Work/todone",
  keys = {
    open_today = "<leader>tt",
    list = "<leader>tl",
    grep = "<leader>tg",
  },
}

return M
