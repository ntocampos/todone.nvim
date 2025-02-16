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

--- @return string[]
local function get_priority_lines()
  local today_formatted = os.date("%Y-%m-%d")
  local file_path = M.config.root_dir .. "/" .. today_formatted .. ".md"
  local lines = read_file_lines(file_path)
  local priority_lines = {}
  for _, line in ipairs(lines) do
    if line:find("- %[% %]") then
      table.insert(priority_lines, line)
      break
    end
  end
  return priority_lines
end

--- @param lines string[]
--- @return {
---  relative: string,
---  width: number,
---  height: number,
---  row: number,
---  col: number,
---  style: string,
---  border: string,
---  title: string,
---  title_pos: string,
--- }
local function get_priority_win_opts(lines)
  local first_line = lines[1] or ""
  local width = math.min(vim.o.columns * 0.4, #first_line)
  local wrap_amunt = math.ceil(#first_line / width)
  local height = math.min(vim.o.lines * 0.2, wrap_amunt)
  local float_position = M.config.float_position
  local row, col = 0, 0
  if float_position == "bottomright" then
    row = vim.o.lines - height - 2
    col = vim.o.columns - width - 2
  elseif float_position == "topright" then
    row = 1
    col = vim.o.columns - width - 2
  end

  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "  Priority  ",
    title_pos = "center",
  }
end

--- @return boolean
local function check_telescope_installed()
  if not pcall(require, "telescope") then
    return false
  end
  return true
end

--- @return boolean
local function check_snacks_installed()
  if not pcall(require, "snacks.picker") then
    return false
  end
  return true
end

local function render_priority_window()
  if not M.float_buf then
    M.float_buf = vim.api.nvim_create_buf(false, true)
  end
  local priority_lines = get_priority_lines()
  if #priority_lines == 0 then
    priority_lines = { "No pending tasks for today 🎉" }
  end

  vim.api.nvim_buf_set_lines(M.float_buf, 0, -1, false, priority_lines)
  local win_opts = get_priority_win_opts(priority_lines)

  M.float_win_id = vim.api.nvim_open_win(M.float_buf, false, win_opts)
  vim.api.nvim_set_option_value("wrap", true, { win = M.float_win_id })
end

local function update_priority_window()
  if not M.float_win_id or not M.float_buf then
    return
  end

  local priority_lines = get_priority_lines()
  if #priority_lines == 0 then
    priority_lines = { "No pending tasks for today 🎉" }
  end

  vim.api.nvim_buf_set_lines(M.float_buf, 0, -1, false, priority_lines)
  local win_opts = get_priority_win_opts(priority_lines)
  vim.api.nvim_win_set_config(M.float_win_id, win_opts)
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
  end

  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_set_option_value('undofile', false, { buf = buf })

  -- Set the lines in the buffer without triggering undo history
  local lines = opts.lines or {}
  vim.api.nvim_buf_call(buf, function()
    local old_undolevels = vim.api.nvim_get_option_value("undolevels", { buf = buf })
    -- Temporarily disable undo
    vim.api.nvim_set_option_value("undolevels", -1, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- Re-enable undo
    vim.api.nvim_set_option_value("undolevels", old_undolevels, { buf = buf })
  end)

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
        update_priority_window()
      end
    end,
  })
  vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
  vim.api.nvim_set_option_value("number", true, { win = win_id })
  vim.api.nvim_set_option_value("relativenumber", true, { win = win_id })
  vim.api.nvim_set_option_value("wrap", true, { win = win_id })

  local close_win = function()
    vim.api.nvim_win_close(win_id, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  local toggle_task = function()
    local line = vim.api.nvim_get_current_line()
    local new_line = ""
    if line:find("- %[% %]") then
      new_line = line:gsub("- %[% %]", "- [x]")
    elseif line:find("- %[x%]") then
      new_line = line:gsub("- %[x%]", "- [ ]")
    else
      new_line = line
    end
    vim.api.nvim_set_current_line(new_line)
  end

  set_buffer_keymap("n", "q", close_win, buf)
  set_buffer_keymap("n", "<enter>", toggle_task, buf)
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

local telescopeAttachMappings = function(prompt_bufnr, _)
  local actions = require "telescope.actions"
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    local selection = require("telescope.actions.state").get_selected_entry()
    local filename = selection.filename
    local date = filename:match("(%d+-%d+-%d+).md")
    M.open({ date = date })
  end)
  return true
end

--- @class PickerOptions
--- @field title string
--- @field type "files" | "grep"
--- @field pattern? string

--- @param opts PickerOptions
local function create_telescope_picker(opts)
  local title = opts.title or "Todone Files"
  local type = opts.type or "files"
  local pattern = opts.pattern or ""

  if type == "files" then
    require('telescope.builtin').find_files({
      cwd = M.config.root_dir,
      prompt_title = title,
      attach_mappings = telescopeAttachMappings,
    })
  end

  if type == "grep" then
    require('telescope.builtin').grep_string({
      prompt_title = title,
      cwd = M.config.root_dir,
      search = pattern,
      attach_mappings = telescopeAttachMappings,
    })
  end
end

local function create_snacks_picker(opts)
  local title = opts.title or "Todone Files"
  local type = opts.type or "files"
  local pattern = opts.pattern or ""
  local snacks_picker = require("snacks.picker")
  pattern = pattern:gsub("%[", "\\["):gsub("%]", "\\]")

  local confirm = function(picker, item, _)
    local date = item.file:match("(%d+-%d+-%d+).md")
    picker:close()
    M.open({ date = date })
  end

  if type == "files" then
    snacks_picker.files({
      finder = "files",
      format = "file",
      title = title,
      show_empty = true,
      hidden = false,
      ignored = false,
      follow = false,
      supports_live = true,
      cwd = M.config.root_dir,
      matcher = { sort_empty = true },
      sort = { fields = { "file:desc" } },
      confirm = confirm,
    })
  end

  if type == "grep" then
    snacks_picker.grep_word({
      finder = "grep",
      format = "file",
      title = title,
      show_empty = true,
      search = pattern,
      live = false,
      supports_live = true,
      dirs = { M.config.root_dir },
      sort_empty = true,
      confirm = confirm,
    })
  end
end

local function create_picker(opts)
  opts = opts or {}
  if check_telescope_installed() then
    create_telescope_picker(opts)
  elseif check_snacks_installed() then
    create_snacks_picker(opts)
  else
    vim.notify("Neither Telescope nor Snacks is installed", vim.log.levels.ERROR)
  end
end

local function get_float_position(position)
  if position == "topright" or position == "bottomright" then
    return position
  end
  return "topright"
end

local function ensure_dir_exists(dir)
  if not check_dir_exists(dir) then
    local success, _ = vim.fn.mkdir(dir, "p")
    if not success then
      vim.notify("Failed to create directory: " .. dir, vim.log.levels.ERROR)
    end
  end
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
  local file_path = M.config.root_dir .. "/" .. date_formatted .. ".md"
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

  local today_formatted = os.date("%Y-%m-%d")
  M.open({ date = today_formatted })
end

function M.list()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local files = vim.fn.glob(M.config.root_dir .. "/*.md", false, true)
  local parsed_files = {}
  for _, file in ipairs(files) do
    local date = file:match(".*/(%d+-%d+-%d+).md")
    local file_name = date .. ".md"
    table.insert(parsed_files, { value = date, display = file_name, ordinal = file_name })
  end
  create_picker({ title = "Todone – Files", type = "files" })
end

function M.grep()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end
  if not check_telescope_installed() then
    return
  end

  local files = vim.fn.glob(M.config.root_dir .. "/*.md", false, true)
  local parsed_files = {}
  for _, file in ipairs(files) do
    local date = file:match(".*/(%d+-%d+-%d+).md")
    local file_name = date .. ".md"
    table.insert(parsed_files, { value = date, display = file_name, ordinal = file_name })
  end
  local actions = require "telescope.actions"
  -- Open Telescope's live grep
  require('telescope.builtin').live_grep({
    prompt_title = "Todone Live Grep",
    search_dirs = { M.config.root_dir },
    cwd = M.config.root_dir,
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = require("telescope.actions.state").get_selected_entry()
        local filename = selection.filename
        local date = filename:match(".*/(%d+-%d+-%d+).md")
        M.open({ date = date })
      end)
      return true
    end,
  })
end

function M.list_pending()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  create_picker({
    title = "Todone – Pending tasks",
    type = "grep",
    pattern = "- [ ]"
  })
end

function M.toggle_float_priority()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  if M.float_win_id then
    vim.api.nvim_win_close(M.float_win_id, true)
    vim.api.nvim_buf_delete(M.float_buf, { force = true })
    M.float_win_id = nil
    M.float_buf = nil
    return
  end

  render_priority_window()
end

function M.setup(opts)
  opts = opts or {}
  M.config.root_dir = replace_tilde(opts.root_dir or "~/todone")
  M.config.include_metadata = opts.include_metadata or false
  M.config.float_position = get_float_position(opts.float_position)

  ensure_dir_exists(M.config.root_dir)

  create_command("TodoneToday", M.open_today)
  create_command("TodoneOpen", function(args)
    local date = args.fargs[1]
    M.open({ date = date })
  end)
  create_command("TodoneList", M.list)
  create_command("TodoneGrep", M.grep)
  create_command("TodonePending", M.list_pending)
  create_command("TodoneToggleFloat", M.toggle_float_priority)

  M.loaded = true
end

return M
