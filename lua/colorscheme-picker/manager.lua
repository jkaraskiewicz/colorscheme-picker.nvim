local M = {}

local storage = require('colorscheme-picker.storage')

-- Directory where themes are stored
M.themes_path = vim.fn.stdpath('data') .. '/colorscheme-picker/themes'

-- Installed themes
M.themes = {}

-- Colorscheme mapping data
M.colorscheme_mapping = {
  by_name = {},    -- colorscheme -> plugin repo
  by_plugin = {},  -- plugin repo -> colorschemes array
}
M.mapping_built = false

-- Built-in Neovim colorschemes (fallback list)
local BUILTIN_THEMES = {
  'blue',
  'darkblue',
  'default',
  'delek',
  'desert',
  'elflord',
  'evening',
  'habamax',
  'industry',
  'koehler',
  'lunaperche',
  'morning',
  'murphy',
  'pablo',
  'peachpuff',
  'quiet',
  'ron',
  'shine',
  'slate',
  'torte',
  'vim',
  'zellner',
}

-- Scan a plugin directory for colorscheme files
-- Returns array of colorscheme names (without .vim/.lua extension)
local function scan_plugin_colorschemes(plugin_path)
  local colorschemes = {}
  local colors_dir = plugin_path .. '/colors'

  -- Check if colors directory exists
  if vim.fn.isdirectory(colors_dir) == 0 then
    return colorschemes
  end

  -- Get all files in colors directory
  local files = vim.fn.readdir(colors_dir)

  -- Extract colorscheme names (filter and remove extensions)
  for _, file in ipairs(files) do
    -- Check if it's a .vim or .lua file
    if file:match('%.vim$') or file:match('%.lua$') then
      local name = file:match('(.+)%.vim$') or file:match('(.+)%.lua$')
      if name then
        table.insert(colorschemes, name)
      end
    end
  end

  return colorschemes
end

-- Parse repository string to get author/name
local function parse_repo(repo)
  if repo:match('^https://') then
    -- Full URL
    local author, name = repo:match('https://[^/]+/([^/]+)/([^/]+)')
    return author, name
  else
    -- GitHub shorthand (author/name)
    local author, name = repo:match('([^/]+)/([^/]+)')
    return author, name
  end
end

-- Get theme directory path
local function get_theme_path(repo)
  local author, name = parse_repo(repo)
  if author and name then
    return M.themes_path .. '/' .. author .. '-' .. name
  end
  return nil
end

-- Check if theme is installed
function M.is_installed(repo)
  local path = get_theme_path(repo)
  return path and vim.fn.isdirectory(path) == 1
end

-- Install a theme
function M.install_theme(repo, branch)
  local path = get_theme_path(repo)
  if not path then
    vim.notify('Invalid repository: ' .. repo, vim.log.levels.ERROR)
    return false
  end

  if M.is_installed(repo) then
    return true -- Already installed
  end

  -- Create themes directory if it doesn't exist
  vim.fn.mkdir(M.themes_path, 'p')

  -- Build git clone command
  local url = repo:match('^https://') and repo or ('https://github.com/' .. repo)
  local cmd = { 'git', 'clone', '--depth=1' }

  if branch then
    table.insert(cmd, '--branch')
    table.insert(cmd, branch)
  end

  table.insert(cmd, url)
  table.insert(cmd, path)

  -- Clone the repository
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to install ' .. repo .. ': ' .. result, vim.log.levels.ERROR)
    return false
  end

  -- Add to rtp
  vim.opt.rtp:append(path)

  return true
end

-- Add theme to rtp if installed
function M.load_theme_path(repo)
  if M.is_installed(repo) then
    local path = get_theme_path(repo)
    vim.opt.rtp:append(path)
    return true
  end
  return false
end

-- Clean up themes not in config
function M.clean_unused_themes()
  -- Check if themes directory exists
  if vim.fn.isdirectory(M.themes_path) == 0 then
    return
  end

  -- Get all installed theme directories
  local installed = vim.fn.readdir(M.themes_path)

  for _, dir in ipairs(installed) do
    local full_path = M.themes_path .. '/' .. dir

    -- Check if this directory corresponds to a theme in our config
    local is_used = false
    for repo, _ in pairs(M.themes) do
      local theme_path = get_theme_path(repo)
      if theme_path == full_path then
        is_used = true
        break
      end
    end

    -- Remove unused theme
    if not is_used then
      vim.schedule(function()
        vim.notify('Removing unused theme: ' .. dir, vim.log.levels.INFO)
        vim.fn.delete(full_path, 'rf')
      end)
    end
  end
end

-- Discover colorschemes provided by a theme repo
-- Updates M.colorscheme_mapping
local function discover_theme_colorschemes(repo)
  local path = get_theme_path(repo)
  if not path or vim.fn.isdirectory(path) == 0 then
    return
  end

  local colorschemes = scan_plugin_colorschemes(path)

  -- Update bidirectional mapping
  M.colorscheme_mapping.by_plugin[repo] = colorschemes
  for _, name in ipairs(colorschemes) do
    M.colorscheme_mapping.by_name[name] = repo
  end
end

-- Identify and mark built-in Neovim colorschemes
local function identify_builtin_themes()
  local vimruntime = vim.env.VIMRUNTIME
  if not vimruntime then
    -- Fallback to hardcoded list
    M.colorscheme_mapping.by_plugin['__builtin__'] = BUILTIN_THEMES
    for _, name in ipairs(BUILTIN_THEMES) do
      M.colorscheme_mapping.by_name[name] = '__builtin__'
    end
    return
  end

  -- Scan runtime colors directory
  local builtins = scan_plugin_colorschemes(vimruntime)

  M.colorscheme_mapping.by_plugin['__builtin__'] = builtins
  for _, name in ipairs(builtins) do
    M.colorscheme_mapping.by_name[name] = '__builtin__'
  end
end

-- Scan all runtime paths to discover colorschemes from external plugins
-- (plugins not managed by colorscheme-picker but in runtimepath)
local function discover_runtimepath_colorschemes()
  -- Get all runtime paths
  local rtps = vim.api.nvim_list_runtime_paths()

  for _, rtp in ipairs(rtps) do
    -- Skip paths we already know about
    local is_managed = false
    for repo, _ in pairs(M.themes) do
      if rtp == get_theme_path(repo) then
        is_managed = true
        break
      end
    end

    -- Skip VIMRUNTIME (handled separately)
    if rtp == vim.env.VIMRUNTIME then
      is_managed = true
    end

    if not is_managed then
      local colorschemes = scan_plugin_colorschemes(rtp)
      if #colorschemes > 0 then
        -- Extract plugin name from path (best effort)
        local plugin_name = rtp:match('/([^/]+)$') or 'Unknown'
        local external_key = '__external__:' .. plugin_name

        M.colorscheme_mapping.by_plugin[external_key] = colorschemes
        for _, name in ipairs(colorschemes) do
          -- Only map if not already mapped
          if not M.colorscheme_mapping.by_name[name] then
            M.colorscheme_mapping.by_name[name] = external_key
          end
        end
      end
    end
  end
end

-- Build complete colorscheme mapping
function M.build_colorscheme_mapping()
  -- Reset mapping
  M.colorscheme_mapping = {
    by_name = {},
    by_plugin = {},
  }

  -- 1. Discover managed themes
  for repo, _ in pairs(M.themes) do
    discover_theme_colorschemes(repo)
  end

  -- 2. Identify built-in themes
  identify_builtin_themes()

  -- 3. Discover external plugins in runtimepath
  discover_runtimepath_colorschemes()

  M.mapping_built = true
end

-- Process theme list and install all themes
function M.process_themes(themes_config)
  -- First, process all themes in config
  for _, theme_spec in ipairs(themes_config) do
    if type(theme_spec) == 'string' then
      -- Simple string: 'author/repo'
      M.themes[theme_spec] = { before = nil }
      if not M.is_installed(theme_spec) then
        vim.schedule(function()
          M.install_theme(theme_spec)
        end)
      else
        M.load_theme_path(theme_spec)
      end
    elseif type(theme_spec) == 'table' and theme_spec[1] then
      -- Table: { 'author/repo', before = function, branch = 'x' }
      local repo = theme_spec[1]
      M.themes[repo] = {
        before = theme_spec.before,
        branch = theme_spec.branch,
      }
      if not M.is_installed(repo) then
        vim.schedule(function()
          M.install_theme(repo, theme_spec.branch)
        end)
      else
        M.load_theme_path(repo)
      end
    end
  end

  -- Then clean up unused themes
  vim.schedule(function()
    M.clean_unused_themes()
  end)
end

-- Get plugin source for a colorscheme name
-- Returns: plugin repo string or special marker
function M.get_colorscheme_plugin(colorscheme_name)
  return M.colorscheme_mapping.by_name[colorscheme_name] or '__external__'
end

-- Get all colorschemes from a plugin
function M.get_plugin_colorschemes(plugin_repo)
  return M.colorscheme_mapping.by_plugin[plugin_repo] or {}
end

-- Check if colorscheme is from managed plugin
function M.is_managed_colorscheme(colorscheme_name)
  local plugin = M.get_colorscheme_plugin(colorscheme_name)
  return M.themes[plugin] ~= nil
end

-- Check if colorscheme is built-in
function M.is_builtin_colorscheme(colorscheme_name)
  return M.get_colorscheme_plugin(colorscheme_name) == '__builtin__'
end

return M
