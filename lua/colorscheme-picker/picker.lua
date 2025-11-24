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
  local last_preview = nil

  -- Create autocmd for live preview on cursor move
  local preview_group = vim.api.nvim_create_augroup('ColorschemePickerPreview', { clear = true })

  local function apply_preview()
    -- Get current picker state
    local picker_matches = MiniPick.get_picker_matches()
    if not picker_matches or not picker_matches.current then
      return
    end

    local current_item = picker_matches.current
    if current_item and current_item ~= last_preview then
      last_preview = current_item
      pcall(vim.cmd, 'colorscheme ' .. current_item)
    end
  end

  -- Set up live preview on cursor move
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = preview_group,
    callback = function()
      vim.schedule(apply_preview)
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
    },
  })

  -- Clean up autocmd
  vim.api.nvim_del_augroup_by_id(preview_group)

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
