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
  local last_item = nil

  -- Create autocmd for live preview using MiniPickMatch event
  local augroup = vim.api.nvim_create_augroup('ColorschemePickerLivePreview', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'MiniPickMatch',
    callback = function()
      local matches = MiniPick.get_picker_matches()
      if matches and matches.current and matches.current ~= last_item then
        last_item = matches.current
        pcall(vim.cmd, 'colorscheme ' .. matches.current)
      end
    end,
  })

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = colorschemes,
      name = 'Colorschemes (live preview)',
      choose = function(item)
        return item
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

  -- Clean up autocmd
  vim.api.nvim_del_augroup_by_id(augroup)

  -- Handle result
  if result then
    -- Theme was selected with Enter
    storage.save_current(result)
    vim.notify('Applied colorscheme: ' .. result, vim.log.levels.INFO)
  elseif original then
    -- Cancelled with Escape - restore original
    pcall(vim.cmd, 'colorscheme ' .. original)
  end
end

return M
