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

    -- Add colorschemes
    for _, name in ipairs(colorscheme_list) do
      local plugin = manager.get_colorscheme_plugin(name)
      local item = format_colorscheme_item(name, max_name_len, plugin)
      table.insert(items, item.display)
    end
  end

  -- Build sections
  add_category('Configured Themes', categories.configured)
  add_category('Built-in Themes', categories.builtin)
  add_category('External Themes', categories.external)

  return items
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
  end

  -- Get all available colorschemes
  local all_colorschemes = vim.fn.getcompletion('', 'color')

  -- Build formatted items with sections
  local display_items = build_picker_items(all_colorschemes)

  local original = vim.g.colors_name
  local selected = nil
  local selected_plugin = nil
  local last_item_idx = nil

  -- Helper to extract colorscheme name and plugin from display string
  -- Returns: colorscheme_name, plugin_repo
  local function extract_colorscheme_info(display_str)
    if not display_str then
      return nil, nil
    end
    -- Check if it's a separator (contains only dashes and text)
    if display_str:match('^─+') then
      return nil, nil
    end
    -- Extract name before the '[' and trim whitespace
    local name = display_str:match('^(.-)%s*%[')
    -- Extract plugin from within the brackets
    local plugin = display_str:match('%[(.-)%]')

    -- Normalize plugin display back to repo format
    if plugin == 'Built-in' then
      plugin = '__builtin__'
    elseif plugin and plugin ~= 'External' then
      -- Check if it's an external plugin or a real repo
      local is_repo = plugin:match('/')
      if not is_repo then
        -- It's an external plugin name
        plugin = '__external__:' .. plugin
      end
    else
      plugin = '__external__'
    end

    return name, plugin
  end

  -- Apply a colorscheme from a specific plugin
  -- Ensures the correct colorscheme is loaded even with name collisions
  local function apply_colorscheme(name, plugin_repo)
    if not name then
      return
    end

    -- For managed themes, ensure the plugin's path is prioritized in runtimepath
    if plugin_repo and manager.themes[plugin_repo] then
      local plugin_path = manager.themes_path .. '/' .. plugin_repo:gsub('/', '-')
      if vim.fn.isdirectory(plugin_path) == 1 then
        -- Remove the path if it exists in runtimepath
        local rtp = vim.opt.rtp:get()
        local filtered_rtp = {}
        for _, path in ipairs(rtp) do
          if path ~= plugin_path then
            table.insert(filtered_rtp, path)
          end
        end
        -- Prepend the plugin path to ensure it's checked first
        table.insert(filtered_rtp, 1, plugin_path)
        vim.opt.rtp = filtered_rtp
      end
    end

    -- Apply the colorscheme
    pcall(vim.cmd, 'colorscheme ' .. name)
  end

  -- Find the index of the current colorscheme in display items
  local current_idx = nil
  if original then
    for i, display_item in ipairs(display_items) do
      local colorscheme_name, _ = extract_colorscheme_info(display_item)
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
    if matches and matches.current and matches.current ~= last_item_idx then
      last_item_idx = matches.current

      -- Extract colorscheme name and plugin from display string
      local colorscheme_name, plugin_repo = extract_colorscheme_info(matches.current)

      -- Apply if it's a valid colorscheme (not a separator)
      if colorscheme_name then
        apply_colorscheme(colorscheme_name, plugin_repo)
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
        -- Extract colorscheme name and plugin from the display string
        local colorscheme_name, plugin_repo = extract_colorscheme_info(item)

        -- Skip if separator was somehow selected
        if not colorscheme_name then
          return
        end

        selected = colorscheme_name
        -- Store the plugin info for final application
        selected_plugin = plugin_repo

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
    apply_colorscheme(selected, selected_plugin)
    storage.save_current(selected)
    vim.notify('Applied colorscheme: ' .. selected, vim.log.levels.INFO)
  elseif original then
    -- Cancelled with Escape - restore original
    -- We don't know the plugin for the original, but it's already loaded so just apply by name
    pcall(vim.cmd, 'colorscheme ' .. original)
  end
end

return M
