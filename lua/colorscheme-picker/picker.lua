local M = {}

local storage = require('colorscheme-picker.storage')

-- Open the colorscheme picker
function M.open()
  local ok, MiniPick = pcall(require, 'mini.pick')
  if not ok then
    vim.notify('mini.pick is required for colorscheme-picker', vim.log.levels.ERROR)
    return
  end

  -- Get all available colorschemes
  local colorschemes = vim.fn.getcompletion('', 'color')
  local original = vim.g.colors_name

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = colorschemes,
      name = 'Colorschemes',

      choose = function(item)
        return item
      end,

      preview = function(buf_id, item)
        if item then
          pcall(vim.cmd, 'colorscheme ' .. item)
        end
      end,
    },
  })

  -- If a theme was selected, save it
  if result then
    storage.save_current(result)
  elseif original then
    -- Restore original theme if cancelled
    pcall(vim.cmd, 'colorscheme ' .. original)
  end
end

return M
