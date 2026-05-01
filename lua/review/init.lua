local M = {}

local config = require("review.config")
local highlights = require("review.highlights")
local hooks = require("review.hooks")
local keymaps = require("review.keymaps")
local store = require("review.store")
local export = require("review.export")
local comments = require("review.comments")

local initialized = false
local augroup = nil

local function attach_current_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if hooks.attach_buffer(bufnr) then
    keymaps.setup_buffer(bufnr)
  end
end

---@param opts? ReviewConfig
function M.setup(opts)
  config.setup(opts)
  highlights.setup()
  store.load()

  if initialized then
    attach_current_buffer()
    return
  end

  augroup = vim.api.nvim_create_augroup("review", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = augroup,
    callback = function()
      vim.schedule(attach_current_buffer)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(args)
      if hooks.is_file_buffer(args.buf) then
        hooks.refresh_buffer(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function(args)
      if args.buf then
        keymaps.clear_buffer(args.buf)
      end
    end,
  })

  vim.schedule(attach_current_buffer)
  initialized = true
end

function M.attach()
  attach_current_buffer()
end

function M.export()
  export.to_clipboard()
end

function M.preview()
  export.preview()
end

function M.clear()
  store.clear()
  require("review.marks").clear_all()
  vim.notify("All comments cleared", vim.log.levels.INFO, { title = "review.nvim" })
end

function M.count()
  return store.count()
end

function M.add_note()
  comments.add_at_cursor("note")
end

function M.add_suggestion()
  comments.add_at_cursor("suggestion")
end

function M.add_issue()
  comments.add_at_cursor("issue")
end

function M.add_praise()
  comments.add_at_cursor("praise")
end

function M.cleanup()
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    augroup = nil
  end
  keymaps.cleanup()
  hooks.cleanup()
  initialized = false
end

return M
