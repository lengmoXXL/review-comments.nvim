local M = {}

---@class ReviewCommentsConfig
---@field comment_types table<string, CommentType>
---@field keymaps ReviewCommentsKeymaps

---@class CommentType
---@field key string
---@field name string
---@field icon string
---@field hl string
---@field line_hl string

---@class ReviewCommentsKeymaps
---@field add_comment string|false
---@field add_note string|false
---@field add_suggestion string|false
---@field add_issue string|false
---@field add_praise string|false
---@field delete_comment string|false
---@field edit_comment string|false
---@field next_comment string|false
---@field prev_comment string|false
---@field list_comments string|false
---@field export_clipboard string|false
---@field send_sidekick string|false
---@field send_tmux string|false
---@field clear_comments string|false
---@field add_file_comment string|false
---@field popup_submit string|false
---@field popup_cancel string|false
---@field show_help string|false
---@field popup_cycle_type string|false

---@type ReviewCommentsConfig
M.defaults = {
  comment_types = {
    note = { key = "n", name = "Note", icon = "📝", hl = "ReviewCommentsNote", line_hl = "ReviewCommentsNoteLine" },
    suggestion = { key = "s", name = "Suggestion", icon = "💡", hl = "ReviewCommentsSuggestion", line_hl = "ReviewCommentsSuggestionLine" },
    issue = { key = "i", name = "Issue", icon = "⚠️", hl = "ReviewCommentsIssue", line_hl = "ReviewCommentsIssueLine" },
    praise = { key = "p", name = "Praise", icon = "✨", hl = "ReviewCommentsPraise", line_hl = "ReviewCommentsPraiseLine" },
  },
  keymaps = {
    -- Edit mode (leader-based)
    add_comment = "<localleader>cc",
    add_note = "<localleader>cn",
    add_suggestion = "<localleader>cs",
    add_issue = "<localleader>ci",
    add_praise = "<localleader>cp",
    add_file_comment = "<localleader>cf",
    delete_comment = "<localleader>cd",
    edit_comment = "<localleader>ce",
    -- Navigation
    next_comment = "]n",
    prev_comment = "[n",
    -- Common actions
    list_comments = "<localleader>cl",
    export_clipboard = "<localleader>cx",
    send_sidekick = "<localleader>cS",
    send_tmux = "<localleader>ct",
    clear_comments = "<localleader>cX",
    -- Help
    show_help = "<localleader>c?",
    -- Popup keymaps
    popup_submit = "<C-s>",
    popup_cancel = "q",
    popup_cycle_type = "<Tab>",
  },
}

---@type ReviewCommentsConfig
M.config = vim.deepcopy(M.defaults)

---@param opts? ReviewCommentsConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---@return ReviewCommentsConfig
function M.get()
  return M.config
end

return M
