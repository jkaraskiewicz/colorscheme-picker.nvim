local M = {}

local data_path = vim.fn.stdpath('data')
local current_file = data_path .. '/colorscheme-picker-current.txt'
local favorites_file = data_path .. '/colorscheme-picker-favorites.json'

-- Save current colorscheme
function M.save_current(colorscheme)
  local file = io.open(current_file, 'w')
  if file then
    file:write(colorscheme)
    file:close()
    return true
  end
  return false
end

-- Load saved colorscheme
function M.load_current()
  local file = io.open(current_file, 'r')
  if file then
    local content = file:read('*all')
    file:close()
    return content:match('^%s*(.-)%s*$') -- trim whitespace
  end
  return nil
end

-- Load favorites
function M.load_favorites()
  local file = io.open(favorites_file, 'r')
  if file then
    local content = file:read('*all')
    file:close()
    local ok, favorites = pcall(vim.json.decode, content)
    if ok and type(favorites) == 'table' then
      return favorites
    end
  end
  return {}
end

-- Save favorites
function M.save_favorites(favorites)
  local file = io.open(favorites_file, 'w')
  if file then
    local content = vim.json.encode(favorites)
    file:write(content)
    file:close()
    return true
  end
  return false
end

-- Toggle favorite
function M.toggle_favorite(colorscheme)
  local favorites = M.load_favorites()
  local index = nil

  for i, fav in ipairs(favorites) do
    if fav == colorscheme then
      index = i
      break
    end
  end

  if index then
    table.remove(favorites, index)
  else
    table.insert(favorites, colorscheme)
  end

  M.save_favorites(favorites)
  return favorites
end

-- Check if colorscheme is favorite
function M.is_favorite(colorscheme)
  local favorites = M.load_favorites()
  for _, fav in ipairs(favorites) do
    if fav == colorscheme then
      return true
    end
  end
  return false
end

return M
