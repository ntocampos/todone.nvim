local helpers = require("helpers")

local M = {}


function M.open()
  local lines = read_file_lines("~/Documents/Vaults/alloy/notes/dailies/2024-11-27.md")
  create_floating_window({ lines = lines })
  helpers.create_floating_window({ lines = lines })
end

function M.setup()
  -- TODO: Add keymaps, check if dir exists.
end

M.open()

return M
