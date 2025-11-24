local M = {}

local storage = require('colorscheme-picker.storage')

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

-- Open the colorscheme picker with live preview
function M.open()
  local ok, MiniPick = pcall(require, 'mini.pick')
  if not ok then
    vim.notify('mini.pick is required for colorscheme-picker', vim.log.levels.ERROR)
    return
  end

  -- Get all available colorschemes
  local colorschemes = vim.fn.getcompletion('', 'color')
  local original = vim.g.colors_name
  local selected = nil
  local last_item = nil

  -- Find the index of the current colorscheme
  local current_idx = nil
  if original then
    for i, scheme in ipairs(colorschemes) do
      if scheme == original then
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
    if matches and matches.current and matches.current ~= last_item then
      last_item = matches.current
      pcall(vim.cmd, 'colorscheme ' .. matches.current)
    end
  end

  -- Start polling timer (check every 50ms)
  timer:start(0, 50, vim.schedule_wrap(update_preview))

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = colorschemes,
      name = 'Colorschemes',
      choose = function(item)
        -- Save the selection and stop timer
        selected = item
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
