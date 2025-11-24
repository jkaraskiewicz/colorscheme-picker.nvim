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

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = colorschemes,
      name = 'Colorschemes',
      choose = function(item)
        -- Save the selection
        selected = item
      end,
      preview = function(buf_id, item)
        -- Apply colorscheme live as user navigates
        pcall(vim.cmd, 'colorscheme ' .. item)

        -- Show sample code in preview buffer
        if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, sample_code)
          vim.bo[buf_id].filetype = 'lua'
          vim.bo[buf_id].bufhidden = 'wipe'
        end
      end,
    },
  })

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
