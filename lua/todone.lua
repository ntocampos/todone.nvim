local helpers = require("helpers")
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local conf = require("telescope.config").values

local M = {}
M.config = {}
M.loaded = false

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

  local date_table = helpers.parse_date(date)
  local date_formatted = os.date("%Y-%m-%d", os.time(date_table))
  local file_path = M.config.dir .. "/" .. date_formatted .. ".md"
  if not helpers.check_file_exists(file_path) then
    helpers.create_file(file_path, date_table, { include_metadata = M.config.include_metadata })
  end
  local lines = helpers.read_file_lines(file_path)
  helpers.create_floating_window({
    lines = lines,
    file_path = file_path,
    title = helpers.replace_home_path(file_path)
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
  if not helpers.check_file_exists(file_path) then
    helpers.create_file(file_path, today_table, { include_metadata = M.config.include_metadata })
  end

  local lines = helpers.read_file_lines(file_path)
  helpers.create_floating_window({
    lines = lines,
    file_path = file_path,
    title = helpers.replace_home_path(file_path)
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
  -- Open list of files using Telescope
  pickers.new({}, {
    prompt_title = "Todone Files",
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

function M.setup(opts)
  opts = opts or {}
  local dir = helpers.replace_tilde(opts.dir or "~/todone")
  M.config.dir = dir
  M.config.include_metadata = opts.include_metadata or false

  if not helpers.check_dir_exists(M.config.dir) then
    vim.notify("Directory not found: " .. M.config.dir, vim.log.levels.ERROR)
    return
  end

  helpers.create_command("TodoneToday", M.open_today)
  vim.keymap.set("n", "<leader>tt", M.open_today, {
    desc = "Open Todone in today's view",
    silent = true
  })

  helpers.create_command("TodoneOpen", function(args)
    local date = args.fargs[1]
    M.open({ date = date })
  end)

  helpers.create_command("TodoneList", M.list)
  vim.keymap.set("n", "<leader>tl", M.list, {
    desc = "List Todone files",
    silent = true
  })

  M.loaded = true
end

M.setup {
  dir = "~/Developer/Work/todone",
  keys = {
    open_today = "<leader>tt",
    list = "<leader>tl",
  },

}
-- M.open_today()

return M
