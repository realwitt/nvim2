-- In lua/custom/modified_buffers.lua
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values

-- Function to find unsaved buffers with diff view in Telescope
local function find_unsaved_buffers()
  -- Get list of modified buffers
  local modified_buffers = {}

  -- Force check of external changes
  vim.cmd('checktime')

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    -- Check if buffer is modified and is a real file (not a scratch buffer)
    if vim.api.nvim_buf_is_valid(bufnr) and
        vim.api.nvim_buf_is_loaded(bufnr) and
        vim.api.nvim_get_option_value('modified', { buf = bufnr }) == true and
        vim.api.nvim_get_option_value('buftype', { buf = bufnr }) == '' then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- Skip unnamed buffers
      if bufname ~= '' then
        table.insert(modified_buffers, {
          bufnr = bufnr,
          filename = bufname,
          display = string.format("%s [+]", vim.fn.fnamemodify(bufname, ":~:.")),
        })
      end
    end
  end

  if #modified_buffers == 0 then
    vim.notify("No modified unwritten buffers found", vim.log.levels.INFO)
    return
  end

  -- Custom previewer to show the diff
  local diff_previewer = previewers.new_buffer_previewer {
    title = "Diff Preview",
    define_preview = function(self, entry, status)
      local bufnr = entry.value.bufnr
      local filename = entry.value.filename

      -- Get buffer content
      local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local buffer_content = table.concat(buffer_lines, "\n") .. "\n"

      -- Get file content from disk
      local file_content = ""
      local file_lines = {}
      local ok, lines = pcall(vim.fn.readfile, filename)
      if ok then
        file_lines = lines
        file_content = table.concat(file_lines, "\n") .. "\n"
      end

      -- Create the diff command output manually
      local header = {
        "--- " .. filename .. " (on disk)",
        "+++ " .. filename .. " (in buffer)",
        "@@ Changes @@"
      }

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, header)

      -- Set filetype to diff for syntax highlighting
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'diff')

      -- Instead of trying to generate our own diff output, use vim's diff mode
      -- First, create a temporary file with the buffer content
      local temp_bufcontent = vim.fn.tempname()
      local temp_file = io.open(temp_bufcontent, "w")
      if temp_file then
        temp_file:write(buffer_content)
        temp_file:close()
      end

      -- Next, create a temporary file with the disk content
      local temp_diskcontent = vim.fn.tempname()
      local temp_disk = io.open(temp_diskcontent, "w")
      if temp_disk then
        temp_disk:write(file_content)
        temp_disk:close()
      end

      -- Run external diff command to get unified diff
      local diff_cmd = "diff -u " ..
          vim.fn.shellescape(temp_diskcontent) .. " " ..
          vim.fn.shellescape(temp_bufcontent)

      local diff_output = vim.fn.systemlist(diff_cmd)

      -- Delete temporary files
      os.remove(temp_bufcontent)
      os.remove(temp_diskcontent)

      -- Update headers to be more readable
      if #diff_output > 2 then
        diff_output[1] = "--- " .. filename .. " (on disk)"
        diff_output[2] = "+++ " .. filename .. " (in buffer)"
      end

      -- Add the diff output to the preview buffer
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, diff_output)
    end
  }

  -- Create the Telescope picker
  pickers.new({}, {
    prompt_title = "Modified Buffers with Diff",
    finder = finders.new_table {
      results = modified_buffers,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
          path = entry.filename,
          bufnr = entry.bufnr,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = diff_previewer,
    attach_mappings = function(prompt_bufnr, map)
      -- Open the selected buffer
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.api.nvim_set_current_buf(selection.bufnr)
      end)

      -- Add additional mappings
      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.api.nvim_buf_delete(selection.bufnr, { force = false })
      end)

      map('n', 'd', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.api.nvim_buf_delete(selection.bufnr, { force = false })
      end)

      -- Diff view toggle
      map('i', '<C-v>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local cmd = string.format("vert diffsplit %s", vim.fn.fnameescape(selection.path))
        vim.cmd(cmd)
        vim.cmd("wincmd p")
        vim.api.nvim_set_current_buf(selection.bufnr)
      end)

      map('n', 'v', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local cmd = string.format("vert diffsplit %s", vim.fn.fnameescape(selection.path))
        vim.cmd(cmd)
        vim.cmd("wincmd p")
        vim.api.nvim_set_current_buf(selection.bufnr)
      end)

      return true
    end,
  }):find()
end

return find_unsaved_buffers

