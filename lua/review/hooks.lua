local M = {}

local marks = require("review.marks")
local utils = require("review.utils")

---@type table<number, boolean>
local attached_buffers = {}

---@param bufnr number
---@return boolean
function M.is_file_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
  if buftype ~= "" then
    return false
  end

  return utils.get_buffer_comment_path(bufnr) ~= nil
end

---@param bufnr? number
---@return string|nil
function M.get_buffer_file(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.is_file_buffer(bufnr) then
    return nil
  end
  return utils.get_buffer_comment_path(bufnr)
end

---@param bufnr? number
---@return boolean
function M.attach_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.is_file_buffer(bufnr) then
    return false
  end

  attached_buffers[bufnr] = true
  M.refresh_buffer(bufnr)
  return true
end

function M.attach_current_buffer()
  return M.attach_buffer(vim.api.nvim_get_current_buf())
end

---@param bufnr? number
function M.refresh_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = M.get_buffer_file(bufnr)
  if not file then
    return
  end
  marks.render_for_buffer(bufnr, file)
end

function M.refresh_current_buffer()
  M.refresh_buffer(vim.api.nvim_get_current_buf())
end

function M.refresh_attached_buffers()
  for bufnr in pairs(attached_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) and M.is_file_buffer(bufnr) then
      M.refresh_buffer(bufnr)
    else
      attached_buffers[bufnr] = nil
    end
  end
end

---@return string|nil file path
---@return number|nil line number
function M.get_cursor_position()
  local file = M.get_buffer_file(vim.api.nvim_get_current_buf())
  if not file then
    return nil, nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  return file, cursor[1]
end

---@return string|nil file path
---@return number|nil start line
---@return number|nil end line
function M.get_visual_range()
  local file = M.get_buffer_file(vim.api.nvim_get_current_buf())
  if not file then
    return nil, nil, nil
  end

  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  return file, start_line, end_line
end

function M.cleanup()
  attached_buffers = {}
end

M._test = {
  attached_buffers = function()
    return attached_buffers
  end,
}

return M
