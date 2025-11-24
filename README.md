# colorscheme-picker.nvim

A lightweight Neovim colorscheme manager with live preview, persistence, and favorites support.

## Features

- 🎨 **Live Preview** - Preview themes as you navigate through them
- 💾 **Persistence** - Your selected theme is saved and restored across sessions
- ⭐ **Favorites** - Mark your favorite themes for quick access
- 🔧 **Theme Management** - Automatically manages theme installations as lazy.nvim dependencies
- 🚀 **Zero Config** - Works out of the box with sensible defaults
- 🎯 **Before Hooks** - Run setup functions before applying specific themes

## Requirements

- Neovim >= 0.9.0
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [mini.pick](https://github.com/echasnovski/mini.nvim) (for the picker UI)

## Installation

### Basic Setup

```lua
local themes = {
  'catppuccin/nvim',
  'folke/tokyonight.nvim',
  'ellisonleao/gruvbox.nvim',
  'rose-pine/neovim',
  -- Add more themes...
}

return {
  'jkaraskiewicz/colorscheme-picker.nvim',
  lazy = false,
  priority = 1000,
  dependencies = themes,
  config = function()
    local config = vim.deepcopy(themes)
    config.default = 'catppuccin'
    require('colorscheme-picker').setup(config)
  end,
  keys = {
    { '<leader>mc', ':ColorschemePickerOpen<cr>', desc = 'Colorschemes' },
  },
}
```

### With Before Hooks

Some themes require setup before activation:

```lua
local themes = {
  'catppuccin/nvim',
  {
    'datsfilipe/vesper.nvim',
    before = function(theme)
      require('vesper').setup({
        italics = {
          comments = false,
          keywords = false,
          functions = false,
        },
      })
    end,
  },
  -- Add more themes...
}

return {
  'jkaraskiewicz/colorscheme-picker.nvim',
  lazy = false,
  priority = 1000,
  dependencies = themes,
  config = function()
    local config = vim.deepcopy(themes)
    config.default = 'catppuccin'
    require('colorscheme-picker').setup(config)
  end,
  keys = {
    { '<leader>mc', ':ColorschemePickerOpen<cr>', desc = 'Colorschemes' },
  },
}
```

## Usage

### Opening the Picker

```vim
:ColorschemePickerOpen
```

Or use the configured keymap (default: `<leader>mc`)

### Picker Keymaps

- `<CR>` - Apply and save the selected theme
- `<Esc>` - Cancel and restore the original theme
- `<C-f>` - Toggle favorite for current theme
- `<C-o>` - Toggle showing only favorites

### Programmatic API

```lua
local picker = require('colorscheme-picker')

-- Open the picker
picker.open()

-- Apply a specific colorscheme
picker.apply('tokyonight')

-- Load saved colorscheme (usually called automatically)
picker.load_colorscheme()
```

## Configuration

### Options

The plugin accepts a config table with themes and an optional `default` field:

```lua
config.default = 'catppuccin'  -- Default colorscheme if none saved
```

### Theme Specification Format

Themes can be specified in two ways:

**Simple string:**
```lua
'catppuccin/nvim'
```

**Table with options:**
```lua
{
  'user/repo',
  name = 'custom-name',
  branch = 'dev',
  before = function(theme)
    -- Setup code here
  end,
}
```

## Data Storage

- **Current theme:** `~/.local/share/nvim/colorscheme-picker-current.txt`
- **Favorites:** `~/.local/share/nvim/colorscheme-picker-favorites.json`

## Comparison with themify.nvim

This plugin was inspired by [themify.nvim](https://github.com/lmantw/themify.nvim) but addresses some limitations:

- ✅ No memory leaks
- ✅ Cleaner implementation
- ✅ Better mini.pick integration
- ✅ Favorites support
- ✅ Theme persistence across sessions

## License

MIT
