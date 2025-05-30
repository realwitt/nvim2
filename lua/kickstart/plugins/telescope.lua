return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons',            enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        defaults = {
          -- Add these configuration options to your existing setup

          -- Always make sure the file shows before the filepath (like on 'gr' when viewing references)
          path_display = function(_, path)
            -- Extract the filename from the path
            local tail = require("telescope.utils").path_tail(path)
            -- Format as "filename.ext (path/to/file)"
            return string.format("%s (%s)", tail, path)
          end,
          -- path_display = {
          --   "truncate",
          --   -- or use "smart" to dynamically truncate based on window width
          --   -- or use "absolute" for full paths
          -- },
          -- layout_config = {
          --   -- Adjust width to make more room for filenames
          --   width = 0.9,
          --   -- You can also adjust the height if needed
          --   height = 0.8,
          --   -- Increase preview width for more space for filenames
          --   preview_width = 0.55,
          -- },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Create autocmd to enable line numbers in telescope preview windows
      vim.api.nvim_create_autocmd("User", {
        pattern = "TelescopePreviewerLoaded",
        callback = function()
          -- Enable line numbers for preview window
          vim.wo.number = true
        end,
      })

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local previewers = require 'telescope.previewers'
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

      -- Set up keymaps
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sm', builtin.git_status, { desc = '[S]earch [M]odified files' })

      -- Add the unsaved buffers command, bound to <leader>su
      vim.keymap.set('n', '<leader>su', find_unsaved_buffers, { desc = '[S]earch [U]nsaved buffers with diff' })

      -- Enhanced buffers mapping with delete capability
      vim.keymap.set('n', '<leader><leader>', function()
        builtin.buffers {
          sort_mru = true,
          sort_lastused = true,
          show_all_buffers = true,
          attach_mappings = function(_, map)
            map('n', 'd', actions.delete_buffer)
            map('i', '<C-d>', actions.delete_buffer)
            return true
          end,
        }
      end, { desc = '[ ] Find existing buffers' })

      -- Fuzzy find in current buffer
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- Search in open files
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Search neovim config files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })

      -- Search in open buffers
      vim.keymap.set('n', '<leader>sb', function()
        builtin.live_grep({ grep_open_files = true, prompt_title = 'Search in Open Buffers' })
      end, { desc = '[S]earch in Open [B]uffers' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
