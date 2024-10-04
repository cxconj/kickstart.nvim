require('CopilotChat').open()
require('CopilotChat').close()

-- 指定されたファイルタイプのバッファを取得する関数
local function get_buffers_by_filetype(filetype)
  local buffers = vim.api.nvim_list_bufs() -- すべてのバッファを取得
  local matching_buffers = {}

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      if buf_filetype == filetype then
        table.insert(matching_buffers, buf)
      end
    end
  end

  return matching_buffers
end

local function get_copilotchat_buffer()
  local copilotchat_buffers = get_buffers_by_filetype('copilot-chat')
  return copilotchat_buffers[1]
end

-- viewer, prompt のバッファを作成
-- local viewer_buf = vim.api.nvim_create_buf(false, true)
local prompt_buf = vim.api.nvim_create_buf(false, true)

local prompt_win = -1 -- prompt ウィンドウの ID
local viewer_win = -1 -- viewer ウィンドウの ID

-- ウィンドウが非表示かどうかのフラグ
local is_windows_hidden = true

local viewer_width_ratio = 0.6
local viewer_height_ratio = 0.5

-- エディタのサイズを取得
local width = vim.api.nvim_get_option('columns') -- エディタの横幅
local height = vim.api.nvim_get_option('lines') -- エディタの縦幅

-- viewer のウィンドウのサイズを設定（横幅60%、縦幅50%）
local viewer_width = math.floor(width * viewer_width_ratio)
local viewer_height = math.floor(height * viewer_height_ratio)

-- prompt のウィンドウのサイズを設定（同じ横幅、縦幅は3行分）
local prompt_width = viewer_width
local prompt_height = 3

-- viewer のウィンドウの位置を計算（中央に配置）
local viewer_col = math.floor((width - viewer_width) / 2)
local viewer_row = math.floor((height - viewer_height) * 0.1)

-- prompt のウィンドウの位置を計算（1つ目のウィンドウの下に配置）
local row2 = viewer_row + viewer_height + 2 -- 1つ目のウィンドウの下に配置

local viewer_win_opts = {
  relative = 'editor',
  width = viewer_width,
  height = viewer_height,
  col = viewer_col,
  row = viewer_row,
  style = 'minimal',
  border = 'single',
}

local prompt_win_opts = {
  relative = 'editor',
  width = prompt_width,
  height = prompt_height,
  col = viewer_col,
  row = row2,
  style = 'minimal',
  border = 'single',
}

-- 関数を定義して特定のバッファの表示範囲を変更
local function scroll_to_bottom(bufnr)
  -- バッファの行数を取得
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count < viewer_row then
    return
  end
  -- ウィンドウIDを取得
  local win_id = vim.fn.bufwinid(bufnr)
  if win_id ~= -1 then
    -- カーソルを最終行に移動
    vim.api.nvim_set_current_win(win_id)
    vim.api.nvim_win_set_cursor(win_id, { line_count, 0 })
    -- vim.cmd('normal! z.')
    vim.cmd('normal! zt')
  end
end

local function ask_copilot(pt_buf)
  local mode = vim.fn.mode()
  -- prompt の内容を取得
  local lines = vim.api.nvim_buf_get_lines(pt_buf, 0, -1, false)
  local data = table.concat(lines, '\n')

  if data ~= '' then
    scroll_to_bottom(get_copilotchat_buffer())

    require('CopilotChat').ask(data)

    vim.cmd(':CopilotChatClose')
  end

  -- prompt の内容をクリア
  vim.api.nvim_buf_set_lines(pt_buf, 0, -1, false, {})
  vim.api.nvim_set_current_win(prompt_win)
  vim.api.nvim_win_set_cursor(prompt_win, { 1, 0 })
  if mode == 'i' then
    vim.cmd('normal! i')
  end
end

vim.api.nvim_set_keymap('n', '<C-S>', ':echo "Ctrl-Enter pressed"<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-S>', ':echo "Ctrl-Enter pressed"<CR>', { noremap = true, silent = true })
-- prompt の挿入モードで CTRL-ENTER が押されたら prompt の内容を viewer に送り、prompt の内容を消す
vim.api.nvim_buf_set_keymap(prompt_buf, 'i', '<C-CR>', '', {
  noremap = true,
  silent = true,
  callback = function()
    ask_copilot(prompt_buf)
  end,
})
vim.api.nvim_buf_set_keymap(prompt_buf, 'i', '<C-S>', '', {
  noremap = true,
  silent = true,
  callback = function()
    ask_copilot(prompt_buf)
  end,
})
vim.api.nvim_buf_set_keymap(prompt_buf, 'n', '<CR>', '', {
  noremap = true,
  silent = true,
  callback = function()
    ask_copilot(prompt_buf)
  end,
})

-- ウィンドウを再表示する関数
local function hide_windows()
  if not is_windows_hidden then
    vim.api.nvim_win_hide(prompt_win)
    vim.api.nvim_win_hide(viewer_win)
    is_windows_hidden = true
  end
end

-- 非表示のウィンドウを再表示する関数
local function show_windows()
  if is_windows_hidden then
    -- viewer ウィンドウを再表示
    viewer_win = vim.api.nvim_open_win(get_copilotchat_buffer(), false, viewer_win_opts)

    -- prompt ウィンドウを再表示
    prompt_win = vim.api.nvim_open_win(prompt_buf, true, prompt_win_opts)

    -- ウィンドウにタイトルを設定
    vim.api.nvim_win_set_config(viewer_win, {
      title = ' GitHub Copilot Chat',
    })
    vim.api.nvim_win_set_config(prompt_win, {
      title = ' User Prompt',
    })

    vim.api.nvim_buf_set_keymap(get_copilotchat_buffer(), 'n', '<Esc>', '', {
      noremap = true,
      silent = true,
      callback = hide_windows,
    })
    vim.api.nvim_buf_set_keymap(get_copilotchat_buffer(), 'n', 'q', '', {
      noremap = true,
      silent = true,
      callback = hide_windows,
    })

    is_windows_hidden = false -- ウィンドウが再表示されたことを記録
  end
end

-- <leader>o でウィンドウを再表示する
vim.api.nvim_set_keymap('n', '<leader>o', '', {
  noremap = true,
  silent = true,
  callback = show_windows,
})

-- ウィンドウを非表示にする
vim.api.nvim_buf_set_keymap(prompt_buf, 'n', '<Esc>', '', {
  noremap = true,
  silent = true,
  callback = hide_windows,
})
vim.api.nvim_buf_set_keymap(prompt_buf, 'n', 'q', '', {
  noremap = true,
  silent = true,
  callback = hide_windows,
})
