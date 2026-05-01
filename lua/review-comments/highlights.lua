local M = {}

function M.setup()
  local links = {
    ReviewCommentsNote = "DiagnosticInfo",
    ReviewCommentsSuggestion = "DiagnosticHint",
    ReviewCommentsIssue = "DiagnosticWarn",
    ReviewCommentsPraise = "DiagnosticOk",
    ReviewCommentsSign = "Comment",
    ReviewCommentsVirtText = "Comment",
  }

  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end

  -- Line highlights (darker background, no underline)
  vim.api.nvim_set_hl(0, "ReviewCommentsNoteLine", { bg = "#0d1f28", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewCommentsSuggestionLine", { bg = "#152015", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewCommentsIssueLine", { bg = "#28250d", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewCommentsPraiseLine", { bg = "#15152a", underline = false, default = true })

  vim.fn.sign_define("ReviewCommentsComment", {
    text = "●",
    texthl = "ReviewCommentsSign",
  })
end

return M
