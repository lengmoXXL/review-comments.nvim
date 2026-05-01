local M = {}

local config = require("review-comments.config")
local comments = require("review-comments.comments")
local export = require("review-comments.export")

---@type table<number, {string, string}[]>
local keymapped_buffers = {}

---@param key string|false|nil
---@return boolean
local function is_enabled(key)
  return key ~= nil and key ~= false and key ~= ""
end

---@param bufnr number
---@param mode string
---@param lhs string|nil
local function del_keymap(bufnr, mode, lhs)
  if lhs and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
  end
end

---@param bufnr number
local function clear_buffer_keymaps(bufnr)
  local tracked = keymapped_buffers[bufnr]
  if not tracked then
    return
  end

  for _, entry in ipairs(tracked) do
    del_keymap(bufnr, entry[1], entry[2])
  end
  keymapped_buffers[bufnr] = nil
end

---@param key string
---@return string
local function format_key(key)
  local inner = key:match("^<(.+)>$")
  if not inner then return key end
  if inner:lower() == "leader" or inner:lower() == "localleader" then return key end
  inner = inner:gsub("^C%-", "Ctrl-")
  return inner
end

---@param entries {key: string, desc: string}[]
---@param title string
---@param lines string[]
---@param max_key_width number
local function add_section(entries, title, lines, max_key_width)
  if #entries == 0 then return end
  table.insert(lines, "")
  table.insert(lines, "  " .. title)
  for _, entry in ipairs(entries) do
    local padding = string.rep(" ", max_key_width - #entry.key + 3)
    table.insert(lines, "   " .. entry.key .. padding .. entry.desc)
  end
end

local help_popup = nil

local function close_help()
  if help_popup then
    help_popup:unmount()
    help_popup = nil
  end
end

local function show_help()
  if help_popup then
    close_help()
    return
  end

  local cfg = config.get()
  local km = cfg.keymaps
  local comment_entries = {}
  local nav_entries = {}
  local action_entries = {}

  local function entry(key_name, desc, tbl)
    local key = km[key_name]
    if not is_enabled(key) then return end
    table.insert(tbl, { key = format_key(key), desc = desc })
  end

  entry("add_comment", "Add comment (pick type)", comment_entries)
  entry("add_note", "Add note", comment_entries)
  entry("add_suggestion", "Add suggestion", comment_entries)
  entry("add_issue", "Add issue", comment_entries)
  entry("add_praise", "Add praise", comment_entries)
  entry("add_file_comment", "File comment", comment_entries)
  entry("edit_comment", "Edit comment", comment_entries)
  entry("delete_comment", "Delete comment", comment_entries)

  entry("next_comment", "Next comment", nav_entries)
  entry("prev_comment", "Previous comment", nav_entries)
  entry("list_comments", "List comments", nav_entries)

  entry("export_clipboard", "Export to clipboard", action_entries)
  entry("send_sidekick", "Send to sidekick", action_entries)
  entry("clear_comments", "Clear all", action_entries)
  entry("show_help", "This help", action_entries)

  local all_entries = {}
  vim.list_extend(all_entries, comment_entries)
  vim.list_extend(all_entries, nav_entries)
  vim.list_extend(all_entries, action_entries)

  local max_key_width = 0
  for _, e in ipairs(all_entries) do
    max_key_width = math.max(max_key_width, #e.key)
  end

  local lines = {}
  add_section(comment_entries, "ReviewComments", lines, max_key_width)
  add_section(nav_entries, "Navigation", lines, max_key_width)
  add_section(action_entries, "Actions", lines, max_key_width)
  table.insert(lines, "")

  local max_line_width = 0
  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, #line)
  end

  local Popup = require("nui.popup")
  help_popup = Popup({
    position = "50%",
    size = { width = math.max(max_line_width + 2, 30), height = #lines },
    border = {
      style = "rounded",
      text = {
        top = " ReviewComments Keymaps ",
        top_align = "center",
      },
    },
    buf_options = {
      modifiable = false,
      buftype = "nofile",
    },
  })

  help_popup:mount()

  local buf = help_popup.bufnr
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_current_win(help_popup.winid)

  local map_opts = { noremap = true, nowait = true }
  help_popup:map("n", "?", close_help, map_opts)
  help_popup:map("n", "q", close_help, map_opts)
  help_popup:map("n", "<Esc>", close_help, map_opts)
end

---@param bufnr number
function M.setup_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  clear_buffer_keymaps(bufnr)

  local km = config.get().keymaps
  local mapped = {}

  local function set(lhs, rhs, desc)
    if is_enabled(lhs) then
      vim.keymap.set("n", lhs, rhs, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = desc })
      table.insert(mapped, { "n", lhs })
    end
  end

  local function set_visual(lhs, rhs, desc)
    if is_enabled(lhs) then
      vim.keymap.set("x", lhs, rhs, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = desc })
      table.insert(mapped, { "x", lhs })
    end
  end

  set(km.add_comment, function() comments.add_with_menu() end, "Add comment (pick type)")
  set_visual(km.add_comment, ":<C-u>lua require('review-comments.comments').add_for_range()<CR>", "Add comment for selection")
  set(km.add_note, function() comments.add_at_cursor("note") end, "Add note")
  set_visual(km.add_note, ":<C-u>lua require('review-comments.comments').add_for_range('note')<CR>", "Add note for selection")
  set(km.add_suggestion, function() comments.add_at_cursor("suggestion") end, "Add suggestion")
  set_visual(km.add_suggestion, ":<C-u>lua require('review-comments.comments').add_for_range('suggestion')<CR>", "Add suggestion for selection")
  set(km.add_issue, function() comments.add_at_cursor("issue") end, "Add issue")
  set_visual(km.add_issue, ":<C-u>lua require('review-comments.comments').add_for_range('issue')<CR>", "Add issue for selection")
  set(km.add_praise, function() comments.add_at_cursor("praise") end, "Add praise")
  set_visual(km.add_praise, ":<C-u>lua require('review-comments.comments').add_for_range('praise')<CR>", "Add praise for selection")
  set(km.add_file_comment, function() comments.file_comment() end, "File comment")
  set(km.delete_comment, function() comments.delete_at_cursor() end, "Delete comment")
  set(km.edit_comment, function() comments.edit_at_cursor() end, "Edit comment")
  set(km.next_comment, function() comments.goto_next() end, "Next comment")
  set(km.prev_comment, function() comments.goto_prev() end, "Previous comment")
  set(km.list_comments, function() comments.list() end, "List all comments")
  set(km.export_clipboard, function() export.to_clipboard() end, "Export to clipboard")
  set(km.send_sidekick, function() export.to_sidekick() end, "Send to sidekick")
  set(km.clear_comments, function() require("review-comments").clear() end, "Clear all comments")
  set(km.show_help, show_help, "Show help")

  keymapped_buffers[bufnr] = mapped
end

function M.clear_keymaps()
  for bufnr in pairs(keymapped_buffers) do
    clear_buffer_keymaps(bufnr)
  end
  keymapped_buffers = {}
end

---@param bufnr number
function M.clear_buffer(bufnr)
  clear_buffer_keymaps(bufnr)
end

function M.cleanup()
  close_help()
  M.clear_keymaps()
end

M._test = {
  format_key = format_key,
  add_section = add_section,
  is_enabled = is_enabled,
}

return M
