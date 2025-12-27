local M = {}

local storage = require('colorscheme-picker.storage')
local manager = require('colorscheme-picker.manager')

-- Sample code for preview
local sample_code = {
  '-- Lua function example',
  'local function greet(name)',
  '  local message = "Hello, " .. name',
  '  print(message)',
  '  return message',
  'end',
  '',
  '-- String and numbers',
  'local text = "Sample text"',
  'local number = 42',
  'local boolean = true',
  '',
  '-- Conditional',
  'if number > 10 then',
  '  print("Greater than 10")',
  'else',
  '  print("Less or equal")',
  'end',
  '',
  '-- Table',
  'local config = {',
  '  name = "example",',
  '  count = 100,',
  '  enabled = true,',
  '}',
  '',
  '-- Function call',
  'greet("World")',
}

-- Categorize colorschemes into groups
local function categorize_colorschemes(colorschemes)
  local categories = {
    configured = {}, -- From managed plugins
    builtin = {},    -- Neovim built-ins
    external = {},   -- Other sources
  }

  for _, name in ipairs(colorschemes) do
    if manager.is_managed_colorscheme(name) then
      table.insert(categories.configured, name)
    elseif manager.is_builtin_colorscheme(name) then
      table.insert(categories.builtin, name)
    else
      table.insert(categories.external, name)
    end
  end

  -- Sort each category alphabetically
  table.sort(categories.configured)
  table.sort(categories.builtin)
  table.sort(categories.external)

  return categories
end

-- Format a colorscheme name with plugin attribution
-- Returns: { display = "formatted string", name = "colorscheme-name" }
local function format_colorscheme_item(name, max_name_len, plugin_repo)
  local padding = string.rep(' ', max_name_len - #name + 2)
  local plugin_display

  if plugin_repo == '__builtin__' then
    plugin_display = 'Built-in'
  elseif plugin_repo:match('^__external__:') then
    local external_name = plugin_repo:match('^__external__:(.+)$')
    plugin_display = external_name or 'External'
  elseif plugin_repo == '__external__' then
    plugin_display = 'External'
  else
    plugin_display = plugin_repo
  end

  return {
    display = name .. padding .. '[' .. plugin_display .. ']',
    name = name,
  }
end

-- Build formatted picker items with sections
local function build_picker_items(colorschemes)
  local categories = categorize_colorschemes(colorschemes)
  local items = {}
  local item_map = {} -- Maps index to actual colorscheme name
  local max_name_len = 0

  -- Calculate max name length across all categories
  for _, name in ipairs(colorschemes) do
    max_name_len = math.max(max_name_len, #name)
  end

  -- Helper to add items from a category
  local function add_category(category_name, colorscheme_list)
    if #colorscheme_list == 0 then
      return
    end

    -- Add section separator
    local separator = string.rep('─', 10) .. ' ' .. category_name .. ' ' .. string.rep('─', 10)
    table.insert(items, separator)
    table.insert(item_map, nil) -- Separators map to nil

    -- Add colorschemes
    for _, name in ipairs(colorscheme_list) do
      local plugin = manager.get_colorscheme_plugin(name)
      local item = format_colorscheme_item(name, max_name_len, plugin)
      table.insert(items, item.display)
      table.insert(item_map, name) -- Map to actual colorscheme name
    end
  end

  -- Build sections
  add_category('Configured Themes', categories.configured)
  add_category('Built-in Themes', categories.builtin)
  add_category('External Themes', categories.external)

  return items, item_map
end

-- Open the colorscheme picker with live preview
function M.open()
  local ok, MiniPick = pcall(require, 'mini.pick')
  if not ok then
    vim.notify('mini.pick is required for colorscheme-picker', vim.log.levels.ERROR)
    return
  end

  -- Build colorscheme mapping on first open
  if not manager.mapping_built then
    manager.build_colorscheme_mapping()

    -- Debug: Show what was found
    local managed_count = 0
    for repo, schemes in pairs(manager.colorscheme_mapping.by_plugin) do
      if manager.themes[repo] then
        managed_count = managed_count + #schemes
        vim.notify('Found ' .. #schemes .. ' themes in ' .. repo, vim.log.levels.INFO)
      end
    end
    vim.notify('Total managed themes: ' .. managed_count, vim.log.levels.INFO)
  end

  -- Get all available colorschemes
  local all_colorschemes = vim.fn.getcompletion('', 'color')

  -- Build formatted items with sections
  local display_items, item_map = build_picker_items(all_colorschemes)

  local original = vim.g.colors_name
  local selected = nil
  local last_item_idx = nil

  -- Find the index of the current colorscheme in display items
  local current_idx = nil
  if original then
    for i, colorscheme_name in ipairs(item_map) do
      if colorscheme_name == original then
        current_idx = i
        break
      end
    end
  end

  -- Create timer for live preview
  local timer = vim.loop.new_timer()

  -- Set initial position after picker starts using MiniPickStart event
  if current_idx then
    local augroup = vim.api.nvim_create_augroup('ColorschemePickerInitPos', { clear = true })
    vim.api.nvim_create_autocmd('User', {
      group = augroup,
      pattern = 'MiniPickStart',
      once = true,
      callback = function()
        vim.schedule(function()
          if MiniPick.is_picker_active() then
            MiniPick.set_picker_match_inds({ current_idx }, 'current')
          end
        end)
      end,
    })
  end

  -- Function to check and apply current item
  local function update_preview()
    if not MiniPick.is_picker_active() then
      return
    end

    local matches = MiniPick.get_picker_matches()
    if matches and matches.current_ind and matches.current_ind ~= last_item_idx then
      last_item_idx = matches.current_ind

      -- Get actual colorscheme name from item_map
      local colorscheme_name = item_map[last_item_idx]

      -- Skip if it's a separator (nil in item_map)
      if colorscheme_name then
        pcall(vim.cmd, 'colorscheme ' .. colorscheme_name)
      end
    end
  end

  -- Start polling timer (check every 50ms)
  timer:start(0, 50, vim.schedule_wrap(update_preview))

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = display_items,
      name = 'Colorschemes',
      choose = function(item)
        -- Extract colorscheme name from the selected display item
        -- Find the item in display_items to get its index
        local idx = nil
        for i, display in ipairs(display_items) do
          if display == item then
            idx = i
            break
          end
        end

        -- Get actual colorscheme name from item_map
        if idx then
          selected = item_map[idx]
          -- Skip if separator was somehow selected
          if not selected then
            return
          end
        end

        timer:stop()
        timer:close()
      end,
      preview = function(buf_id, item)
        -- Show sample code in preview buffer
        if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, sample_code)
          vim.bo[buf_id].filetype = 'lua'
          vim.bo[buf_id].bufhidden = 'wipe'
        end
      end,
    },
  })

  -- Stop timer if still running
  if not timer:is_closing() then
    timer:stop()
    timer:close()
  end

  -- Handle result
  if result and selected then
    -- Theme was selected with Enter - apply and save it
    pcall(vim.cmd, 'colorscheme ' .. selected)
    storage.save_current(selected)
    vim.notify('Applied colorscheme: ' .. selected, vim.log.levels.INFO)
  elseif original then
    -- Cancelled with Escape - restore original
    pcall(vim.cmd, 'colorscheme ' .. original)
  end
end

return M
