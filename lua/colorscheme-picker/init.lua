local M = {}

local storage = require('colorscheme-picker.storage')
local picker = require('colorscheme-picker.picker')

-- Store theme configs for before functions
M.theme_configs = {}
M.default_colorscheme = nil

-- Process a theme spec and normalize it
local function process_theme_spec(spec)
  if type(spec) == 'string' then
    return { spec }
  elseif type(spec) == 'table' then
    local processed = { spec[1] or spec.url }

    -- Copy other fields
    for k, v in pairs(spec) do
      if k ~= 1 and k ~= 'url' and k ~= 'before' then
        processed[k] = v
      end
    end

    -- Store before function separately
    if spec.before then
      local theme_name = spec.name or (spec[1] or spec.url):match('([^/]+)$')
      M.theme_configs[theme_name] = { before = spec.before }
    end

    return processed
  end
  return nil
end

-- Setup function that processes the theme list
function M.setup(opts)
  opts = opts or {}

  -- Handle two cases:
  -- 1. opts is a list of themes (themify-style API: { 'theme1', 'theme2', default = 'x' })
  -- 2. opts is a config table with named fields (opts = { default = 'x', themes = {...} })

  local theme_list = {}

  -- Extract default if present
  if opts.default then
    M.default_colorscheme = opts.default
  end

  -- Check if opts is an array (list of themes)
  if #opts > 0 then
    -- Extract all numeric indices (the themes)
    for i = 1, #opts do
      table.insert(theme_list, opts[i])
    end
  elseif opts.themes then
    -- Standard config format
    theme_list = opts.themes
  end

  -- Process theme list and store before functions
  for _, theme_spec in ipairs(theme_list) do
    local _ = process_theme_spec(theme_spec)
  end

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

  -- Call before function if it exists
  local theme_config = M.theme_configs[colorscheme]
  if theme_config and theme_config.before then
    local ok, err = pcall(theme_config.before, colorscheme)
    if not ok then
      vim.notify('Error in before function for ' .. colorscheme .. ': ' .. tostring(err), vim.log.levels.WARN)
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
  -- Call before function if it exists
  local theme_config = M.theme_configs[colorscheme]
  if theme_config and theme_config.before then
    local ok, err = pcall(theme_config.before, colorscheme)
    if not ok then
      vim.notify('Error in before function for ' .. colorscheme .. ': ' .. tostring(err), vim.log.levels.WARN)
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
