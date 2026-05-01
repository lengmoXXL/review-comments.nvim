local M = {}

local store = require("review-comments.store")
local config = require("review-comments.config")
local utils = require("review-comments.utils")

local ns_id = vim.api.nvim_create_namespace("review_comments")
local ns_padding = vim.api.nvim_create_namespace("review_comments_padding")

---@param text string
---@param type_name string
---@param hl string
---@return table[] virt_lines
local function build_comment_box(text, type_name, hl)
  local virt_lines = {}
  local text_lines = vim.split(text, "\n")

  local max_text_width = 0
  for _, text_line in ipairs(text_lines) do
    max_text_width = math.max(max_text_width, vim.fn.strdisplaywidth(text_line))
  end
  local header_text = string.format("[%s]", string.upper(type_name))
  local content_width = math.max(max_text_width, 20)

  local top_dashes = content_width - vim.fn.strdisplaywidth(header_text) + 1
  table.insert(virt_lines, { { "╭─" .. header_text .. string.rep("─", top_dashes) .. "╮", hl } })

  for _, text_line in ipairs(text_lines) do
    local padding = content_width - vim.fn.strdisplaywidth(text_line)
    table.insert(virt_lines, { { "│ " .. text_line .. string.rep(" ", padding) .. " │", hl } })
  end

  table.insert(virt_lines, { { "╰" .. string.rep("─", content_width + 2) .. "╯", hl } })
  return virt_lines
end

---@param bufnr number
---@param file_override? string file path to use directly instead of parsing buffer name
function M.render_for_buffer(bufnr, file_override)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file
  if file_override then
    file = utils.to_comment_path(file_override)
  else
    file = utils.get_buffer_comment_path(bufnr)
  end

  if not file then
    return
  end

  local comments = store.get_for_file(file)

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cfg = config.get()

  for _, comment in ipairs(comments) do
    local type_info = cfg.comment_types[comment.type]
    local icon = type_info and type_info.icon or "●"
    local hl = type_info and type_info.hl or "ReviewCommentsSign"
    local line_hl = type_info and type_info.line_hl
    local name = type_info and type_info.name or comment.type
    local virt_lines = build_comment_box(comment.text, name, hl)

    if comment.line == 0 then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, 0, 0, {
        sign_text = icon,
        sign_hl_group = hl,
        virt_lines = virt_lines,
        virt_lines_above = true,
      })
      -- Scroll windows to reveal virt_lines above row 0
      local virt_line_count = #virt_lines
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
          vim.api.nvim_win_call(win, function()
            local view = vim.fn.winsaveview()
            if view.topline <= 1 then
              view.topfill = virt_line_count
              vim.fn.winrestview(view)
            end
          end)
        end
      end
    else
      local line_start = comment.line - 1
      local line_end_0 = (comment.line_end or comment.line) - 1
      local is_range = line_end_0 ~= line_start

      if line_start >= 0 then
        if is_range then
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_start, 0, {
            sign_text = icon,
            sign_hl_group = hl,
            line_hl_group = line_hl,
          })

          for l = line_start + 1, line_end_0 - 1 do
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, l, 0, {
              line_hl_group = line_hl,
            })
          end

          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_end_0, 0, {
            line_hl_group = line_hl,
            virt_lines = virt_lines,
            virt_lines_above = false,
          })
        else
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_start, 0, {
            sign_text = icon,
            sign_hl_group = hl,
            line_hl_group = line_hl,
            virt_lines = virt_lines,
            virt_lines_above = false,
          })
        end
      end
    end
  end
end

function M.refresh()
  local ok, hooks = pcall(require, "review-comments.hooks")
  if not ok then
    return
  end

  hooks.refresh_current_buffer()
end

function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      vim.api.nvim_buf_clear_namespace(bufnr, ns_padding, 0, -1)
    end
  end
end

return M
