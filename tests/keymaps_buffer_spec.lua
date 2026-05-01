local keymaps = require("review.keymaps")
local config = require("review.config")

describe("review.keymaps buffer setup", function()
  local bufnr

  before_each(function()
    config.setup()
    bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    keymaps.cleanup()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  local function has_key(lhs)
    local localleader = vim.g.maplocalleader or "\\"
    lhs = lhs:gsub("<localleader>", localleader)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
      if map.lhs == lhs then
        return true
      end
    end
    return false
  end

  it("sets leader-style comment keymaps", function()
    keymaps.setup_buffer(bufnr)
    assert.is_true(has_key("<localleader>cc"))
    assert.is_true(has_key("<localleader>cd"))
    assert.is_true(has_key("<localleader>ce"))
  end)

  it("does not set single-key edit-mode mappings", function()
    keymaps.setup_buffer(bufnr)
    assert.is_false(has_key("i"))
    assert.is_false(has_key("d"))
    assert.is_false(has_key("e"))
    assert.is_false(has_key("q"))
  end)
end)
