local store = require("review-comments.store")
local marks = require("review-comments.marks")
local config = require("review-comments.config")

describe("marks file_override", function()
  local bufnr

  before_each(function()
    store.clear()
    config.setup()

    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "local M = {}",
      "",
      "function M.hello()",
      "  print('hello')",
      "end",
      "",
      "return M",
    })
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("render_for_buffer with file_override", function()
    it("renders comments using file_override path", function()
      store.add("src/app.lua", 3, "issue", "Fix this")

      -- Buffer has no name, but file_override provides the path
      marks.render_for_buffer(bufnr, "src/app.lua")

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(1, #extmarks)
      assert.equals(2, extmarks[1][2])
    end)

    it("renders comments with file_override even when buffer name is unusable", function()
      vim.api.nvim_buf_set_name(bufnr, "term://review-comments")

      store.add("src/app.lua", 3, "note", "A note")

      marks.render_for_buffer(bufnr, "src/app.lua")

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(1, #extmarks)
    end)

    it("normalizes file_override path (strips leading ./)", function()
      store.add("src/app.lua", 3, "issue", "Fix")

      marks.render_for_buffer(bufnr, "./src/app.lua")

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(1, #extmarks)
    end)

    it("normalizes file_override path (strips trailing slashes)", function()
      store.add("src/app.lua", 3, "issue", "Fix")

      marks.render_for_buffer(bufnr, "src/app.lua/")

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(1, #extmarks)
    end)

    it("renders nothing when file_override has no matching comments", function()
      store.add("other_file.lua", 3, "issue", "Fix")

      marks.render_for_buffer(bufnr, "src/app.lua")

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(0, #extmarks)
    end)

    it("falls back to buffer name when file_override is nil", function()
      vim.api.nvim_buf_set_name(bufnr, "src/fallback.lua")

      store.add("src/fallback.lua", 3, "issue", "Fallback test")

      marks.render_for_buffer(bufnr)

      local ns_id = vim.api.nvim_create_namespace("review_comments")
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

      assert.equals(1, #extmarks)
    end)
  end)
end)
