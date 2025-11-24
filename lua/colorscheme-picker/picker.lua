local M = {}

local storage = require('colorscheme-picker.storage')

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

  -- Setup timer for live preview
  local timer = vim.loop.new_timer()
  local last_item = nil

  -- Continuously check for cursor movement in picker (every 50ms)
  timer:start(0, 50, vim.schedule_wrap(function()
    local matches = MiniPick.get_picker_matches()
    if matches and matches.current and matches.current ~= last_item then
      last_item = matches.current
      pcall(vim.cmd, 'colorscheme ' .. matches.current)
    end
  end))

  -- Start the picker
  local result = MiniPick.start({
    source = {
      items = colorschemes,
      name = 'Colorschemes (live preview)',
      choose = function(item)
        return item
      end,
    },
  })

  -- Stop timer after picker closes
  timer:stop()
  timer:close()

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
