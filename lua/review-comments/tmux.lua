local M = {}

local export = require("review-comments.export")
local store = require("review-comments.store")

local DELIMITER = "\t"

local recent_panes = {}
local picker_popup = nil
local picker_prev_win = nil

local function notify(msg, level)
  vim.notify(msg, level, { title = "review-comments.nvim" })
end

local function default_runner(argv, input)
  local output
  if input ~= nil then
    output = vim.fn.systemlist(argv, input)
  else
    output = vim.fn.systemlist(argv)
  end
  return vim.v.shell_error == 0, output, vim.v.shell_error
end

local command_runner = default_runner

local function run(argv, input)
  return command_runner(argv, input)
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function pane_display(pane)
  local location = string.format("%s.%s", pane.window_index ~= "" and pane.window_index or "?", pane.pane_index ~= "" and pane.pane_index or "?")
  local window_name = pane.window_name ~= "" and pane.window_name or "-"
  local command = pane.command ~= "" and pane.command or "-"
  local path = pane.path ~= "" and pane.path or "-"
  return string.format("%s  %s  %s  %s  %s", pane.id, location, window_name, command, path)
end

local function parse_pane_line(line)
  local parts = vim.split(line or "", DELIMITER, { plain = true })
  if #parts < 6 or parts[1] == "" then
    return nil
  end

  local pane = {
    id = parts[1],
    window_index = parts[2] or "",
    pane_index = parts[3] or "",
    window_name = parts[4] or "",
    command = parts[5] or "",
    path = table.concat(parts, DELIMITER, 6),
  }
  pane.display = pane_display(pane)
  return pane
end

local function remember_pane(pane_id)
  if not pane_id or pane_id == "" then
    return
  end

  local next_recent = { pane_id }
  for _, existing in ipairs(recent_panes) do
    if existing ~= pane_id then
      table.insert(next_recent, existing)
    end
  end
  recent_panes = next_recent
end

local function sort_panes_by_recent(panes)
  local by_id = {}
  for _, pane in ipairs(panes) do
    by_id[pane.id] = pane
  end

  local sorted = {}
  local seen = {}
  for _, pane_id in ipairs(recent_panes) do
    local pane = by_id[pane_id]
    if pane then
      table.insert(sorted, pane)
      seen[pane_id] = true
    end
  end

  for _, pane in ipairs(panes) do
    if not seen[pane.id] then
      table.insert(sorted, pane)
    end
  end

  return sorted
end

function M.current_session()
  local ok, lines = run({ "tmux", "display-message", "-p", "#S" })
  if not ok then
    return nil, "Could not query current tmux session"
  end

  local session = trim(lines and lines[1])
  if session == "" then
    return nil, "Could not determine current tmux session"
  end

  return session
end

function M.list_panes()
  local session, err = M.current_session()
  if not session then
    return nil, err
  end

  local format = table.concat({
    "#{pane_id}",
    "#{window_index}",
    "#{pane_index}",
    "#{window_name}",
    "#{pane_current_command}",
    "#{pane_current_path}",
  }, DELIMITER)

  local ok, lines = run({ "tmux", "list-panes", "-s", "-t", session, "-F", format })
  if not ok then
    return nil, "Could not list tmux panes"
  end

  local panes = {}
  for _, line in ipairs(lines or {}) do
    local pane = parse_pane_line(line)
    if pane then
      table.insert(panes, pane)
    end
  end

  return sort_panes_by_recent(panes)
end

function M.send_to_pane(pane, markdown, send_enter)
  if not pane or not pane.id then
    return false, "No tmux pane selected"
  end

  local buffer_name = "review-comments-" .. tostring(vim.fn.getpid())
  local ok = run({ "tmux", "load-buffer", "-b", buffer_name, "-" }, markdown)
  if not ok then
    return false, "Could not load tmux buffer"
  end

  ok = run({ "tmux", "paste-buffer", "-b", buffer_name, "-t", pane.id })
  run({ "tmux", "delete-buffer", "-b", buffer_name })
  if not ok then
    return false, "Could not paste tmux buffer"
  end

  if send_enter then
    ok = run({ "tmux", "send-keys", "-t", pane.id, "Enter" })
    if not ok then
      return false, "Could not send Enter to tmux pane"
    end
  end

  remember_pane(pane.id)
  return true
end

local function close_picker()
  if picker_popup then
    picker_popup:unmount()
    picker_popup = nil
  end

  if picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win) then
    vim.api.nvim_set_current_win(picker_prev_win)
  end
  picker_prev_win = nil
end

function M.open_picker(panes, on_submit)
  close_picker()

  if #panes == 0 then
    notify("No tmux panes found", vim.log.levels.WARN)
    return
  end

  local ok, Popup = pcall(require, "nui.popup")
  if not ok then
    notify("nui.nvim is required for tmux pane picker", vim.log.levels.ERROR)
    return
  end

  local lines = {}
  local max_width = 0
  for _, pane in ipairs(panes) do
    local line = pane.display or pane_display(pane)
    table.insert(lines, line)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  local columns = vim.o.columns > 0 and vim.o.columns or 80
  local rows = vim.o.lines > 0 and vim.o.lines or 24
  local width = math.min(math.max(max_width + 2, 50), math.max(columns - 4, 20))
  local height = math.min(#lines, math.max(rows - 4, 1))

  picker_prev_win = vim.api.nvim_get_current_win()
  picker_popup = Popup({
    position = "50%",
    size = { width = width, height = height },
    border = {
      style = "rounded",
      text = {
        top = " tmux panes ",
        top_align = "center",
        bottom = " Enter paste | C-s paste+send ",
        bottom_align = "center",
      },
    },
    buf_options = {
      modifiable = false,
      buftype = "nofile",
      bufhidden = "wipe",
    },
    win_options = {
      cursorline = true,
      wrap = false,
    },
  })

  picker_popup:mount()

  local buf = picker_popup.bufnr
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_current_win(picker_popup.winid)

  local function submit(send_enter)
    if not picker_popup then
      return
    end
    local row = vim.api.nvim_win_get_cursor(picker_popup.winid)[1]
    local pane = panes[row]
    close_picker()
    if pane then
      on_submit(pane, send_enter)
    end
  end

  local map_opts = { noremap = true, nowait = true }
  picker_popup:map("n", "<CR>", function() submit(false) end, map_opts)
  picker_popup:map("n", "<C-s>", function() submit(true) end, map_opts)
  picker_popup:map("n", "q", close_picker, map_opts)
  picker_popup:map("n", "<Esc>", close_picker, map_opts)
end

function M.send_current_review()
  local count = store.count()
  if count == 0 then
    notify("No comments to send", vim.log.levels.WARN)
    return
  end

  local panes, err = M.list_panes()
  if not panes then
    notify(err or "Could not list tmux panes", vim.log.levels.ERROR)
    return
  end

  M.open_picker(panes, function(pane, send_enter)
    local ok, send_err = M.send_to_pane(pane, export.generate_markdown(), send_enter)
    if not ok then
      notify(send_err or "Could not send comments to tmux pane", vim.log.levels.ERROR)
      return
    end

    local suffix = send_enter and " and pressed Enter" or ""
    notify(string.format("Sent %d comment(s) to tmux pane %s%s", count, pane.id, suffix), vim.log.levels.INFO)
  end)
end

M._test = {
  parse_pane_line = parse_pane_line,
  pane_display = pane_display,
  remember_pane = remember_pane,
  sort_panes_by_recent = sort_panes_by_recent,
  reset_recent = function()
    recent_panes = {}
  end,
  set_runner = function(runner)
    command_runner = runner
  end,
  reset_runner = function()
    command_runner = default_runner
  end,
}

return M
