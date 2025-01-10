# Todone

https://github.com/user-attachments/assets/c38009e9-b3fa-4fbb-870c-37739921866c

Todone is a plugin for managing your daily tasks inside Neovim using a simple and intuitive interface.

## Features

1. Create daily notes and edit them in a floating window.
2. Toggle tasks as done or undone.
3. List and search in past notes.
4. List pending tasks.
5. Keep track of your current high priority task.
6. Backup notes however you want (Github, Dropbox, etc).

## Installation 

> [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) is optional, but highly recommended for a better experience.

Using [Lazy](https://github.com/folke/lazy.nvim):
```lua
use {
  'ntocampos/todone.nvim',
  dependencies = { "nvim-telescope/telescope.nvim", optional = true },
  opts = {
    root_dir = "~/todone/",
    float_position = "topright",
  },
  keys = {
    { "<leader>tt", "<cmd>TodoneToday<cr>",       desc = "Open today's notes" },
    { "<leader>tf", "<cmd>TodoneToggleFloat<cr>", desc = "Toggle priority float" },
    -- The commands below require telescope.nvim
    { "<leader>tl", "<cmd>TodoneList<cr>",        desc = "List all notes" },
    { "<leader>tg", "<cmd>TodoneGrep<cr>",        desc = "Search inside all notes" },
    { "<leader>tp", "<cmd>TodonePending<cr>",     desc = "List notes with pending tasks" },
  }
}
```

## Usage

After installing Todone, you can start using the commands or keymaps to interact with it.
When you open a note, it will be created if it doesn't exist, and it will be rendered in a floating window. To exit and save the note, press `q`.
Inside the note, you can press `enter` to toggle a markdown checkbox as done or undone.
The notes are simple markdown files, so you can use all markdown features and also edit them outside Neovim.

### Commands

1. `:TodoneToday` - Open today's note
2. `:TodoneOpen "yyyy-mm-dd"` - Open the note for a specific date, useful for planning ahead
2. `:TodoneToggleFloat` - Toggle the priority float
3. `:TodoneList` - List all notes
4. `:TodoneGrep` - Search inside all notes
5. `:TodonePending` - List notes with pending tasks

## Backing up notes

Todone notes are simple markdown files, so you can backup them however you want. You can use git, Dropbox, or any other service you prefer.
