local M = {}

local storage = require('colorscheme-picker.storage')
local picker = require('colorscheme-picker.picker')
local manager = require('colorscheme-picker.manager')

M.default_colorscheme = nil

-- Setup function that processes the theme list
function M.setup(config)
  config = config or {}

  -- Extract default if present
  if config.default then
    M.default_colorscheme = config.default
  end

  -- Extract theme list from explicit themes array
  local theme_list = config.themes or {}

  -- Install and load all themes
  manager.process_themes(theme_list)

  -- Load and apply saved colorscheme
  M.load_colorscheme()

  -- Create user command
  vim.api.nvim_create_user_command('ColorschemePickerOpen', function()
    M.open()
  end, { desc = 'Open colorscheme picker' })
end

-- Load saved colorscheme on startup
function M.load_colorscheme()
  local saved = storage.load_current()
  local colorscheme = saved or M.default_colorscheme or 'default'

  -- Call before function if it exists (from manager)
  for repo, theme_info in pairs(manager.themes) do
    if theme_info.before then
      local ok, err = pcall(theme_info.before, colorscheme)
      if not ok then
        vim.notify('Error in before function: ' .. tostring(err), vim.log.levels.WARN)
      end
    end
  end

  -- Apply colorscheme
  local ok, err = pcall(vim.cmd, 'colorscheme ' .. colorscheme)
  if not ok then
    vim.notify('Failed to load colorscheme ' .. colorscheme .. ': ' .. tostring(err), vim.log.levels.WARN)

    -- Try default if saved colorscheme failed
    if saved and M.default_colorscheme then
      pcall(vim.cmd, 'colorscheme ' .. M.default_colorscheme)
    end
  end
end

-- Open the picker
function M.open()
  picker.open()
end

-- Apply a specific colorscheme
function M.apply(colorscheme)
  -- Call before function if it exists (from manager)
  for repo, theme_info in pairs(manager.themes) do
    if theme_info.before then
      local ok, err = pcall(theme_info.before, colorscheme)
      if not ok then
        vim.notify('Error in before function: ' .. tostring(err), vim.log.levels.WARN)
      end
    end
  end

  -- Apply colorscheme
  local ok, err = pcall(vim.cmd, 'colorscheme ' .. colorscheme)
  if ok then
    storage.save_current(colorscheme)
    return true
  else
    vim.notify('Failed to apply colorscheme ' .. colorscheme .. ': ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

return M
