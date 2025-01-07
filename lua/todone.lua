local helpers = require("helpers")

local M = {}
M.config = {}
M.loaded = false

function M.open()
  if not M.loaded then
    vim.notify("todone not loaded", vim.log.levels.ERROR)
    return
  end

  local file_path = M.config.dir .. "/2025-01-05.md"
  local lines = helpers.read_file_lines(file_path)
  helpers.create_floating_window({ lines = lines })
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
  if not helpers.check_file_exists(file_path) then
    helpers.create_file(file_path, today_table)
  end

  local yesterday = os.time() - 86400
  local formatted_date = "" .. os.date("%B %d, %Y", yesterday)

  local lines = helpers.read_file_lines(file_path)
  helpers.create_floating_window({ lines = lines, file_path = file_path, title = formatted_date })
end

function M.setup(opts)
  opts = opts or {}
  local dir = helpers.replace_home_path(opts.dir or "~/todone")
  M.config.dir = dir

  if not helpers.check_dir_exists(M.config.dir) then
    vim.notify("Directory not found: " .. M.config.dir, vim.log.levels.ERROR)
    return
  end

  M.loaded = true
end

M.setup { dir = "~/Developer/Work/todone" }
M.open_today()

return M
