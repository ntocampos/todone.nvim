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
M.open()

return M
