local M = {}

local storage = require('colorscheme-picker.storage')

-- Directory where themes are stored
M.themes_path = vim.fn.stdpath('data') .. '/colorscheme-picker/themes'

-- Installed themes
M.themes = {}

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

return M
