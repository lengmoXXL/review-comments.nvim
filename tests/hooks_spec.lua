local hooks = require("review.hooks")
local store = require("review.store")
local config = require("review.config")

describe("review.hooks buffer provider", function()
  local bufnr

  before_each(function()
    store.clear()
    config.setup()

    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "local M = {}",
      "return M",
    })
    vim.api.nvim_buf_set_name(bufnr, "hooks_test.lua")
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    hooks.cleanup()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it("attaches normal file buffers", function()
    assert.is_true(hooks.attach_buffer(bufnr))
  end)

  it("skips non-file buffers", function()
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    assert.is_false(hooks.attach_buffer(bufnr))
  end)

  it("returns cursor file and line", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local file, line = hooks.get_cursor_position()
    assert.equals("hooks_test.lua", file)
    assert.equals(2, line)
  end)

  it("renders comments when attaching", function()
    store.add("hooks_test.lua", 1, "note", "Attached")

    hooks.attach_buffer(bufnr)

    local ns_id = vim.api.nvim_create_namespace("review")
    local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
    assert.equals(1, #extmarks)
  end)
end)
