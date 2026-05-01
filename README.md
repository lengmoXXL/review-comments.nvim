# review-comments.nvim

Code review comments for normal Neovim file buffers, optimized for AI feedback loops.

Forked from [georgeguimaraes/review.nvim](https://github.com/georgeguimaraes/review.nvim) and remove the use of codediff.nvim

## Features

- Add comments to specific lines in normal file buffers (Note, Suggestion, Issue, Praise)
- Multi-line comment support with box-style virtual text display
- File-level comments for whole-file feedback
- Comments displayed as signs, line highlights, and virtual lines
- Comments persist per project in Neovim's XDG data directory: `~/.local/share/nvim/review-comments/`
- Export comments as structured Markdown for AI conversations
- Send comments directly to [sidekick.nvim](https://github.com/folke/sidekick.nvim)
- Send comments to a selected pane in the current tmux session

## Requirements

- Neovim >= 0.9
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- tmux (optional, only for tmux pane sending)

## Installation

Using lazy.nvim:

```lua
{
  "lengmoXXL/review-comments.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {},
}
```

## Usage

Call `setup()` and open a normal file buffer. review-comments.nvim automatically attaches buffer-local keymaps and renders any saved comments for that file.

```lua
require("review-comments").setup()
```

Management commands:

```vim
:ReviewComments export       " Export comments to clipboard
:ReviewComments preview      " Preview exported markdown in split
:ReviewComments sidekick     " Send comments to sidekick.nvim
:ReviewComments tmux         " Send comments to a tmux pane
:ReviewComments list         " List all comments and jump to one
:ReviewComments clear        " Clear all comments
```

When you spot something worth commenting on, use `<localleader>cc` on the line and pick a comment type from the menu. For multi-line comments, visually select the range first then press `<localleader>cc`. For file-level comments that apply to the whole file, press `<localleader>cf`.

Use `]n` and `[n` to jump between comments in the current file, `<localleader>ce` to edit, and `<localleader>cd` to delete. `<localleader>cl` lists comments across the project and opens the selected file.

## Keybindings

All keymaps are buffer-local to normal file buffers. Set any keymap to `false` to disable it.

| Key | Action |
|-----|--------|
| `<localleader>cc` | Add comment (pick type) |
| `<localleader>cn` | Add note |
| `<localleader>cs` | Add suggestion |
| `<localleader>ci` | Add issue |
| `<localleader>cp` | Add praise |
| `<localleader>cf` | Add/edit file-level comment |
| `<localleader>cd` | Delete comment at cursor |
| `<localleader>ce` | Edit comment at cursor |
| `]n` | Jump to next comment |
| `[n` | Jump to previous comment |
| `<localleader>cl` | List all comments |
| `<localleader>cx` | Export to clipboard |
| `<localleader>cS` | Send to sidekick.nvim |
| `<localleader>ct` | Send to tmux pane |
| `<localleader>cX` | Clear all comments |
| `<localleader>c?` | Show help |

Comment popup:

| Key | Action |
|-----|--------|
| `Enter` | Insert newline |
| `Ctrl+s` | Submit comment |
| `Tab` | Cycle comment type |
| `Esc` / `q` | Cancel in normal mode |

Tmux pane picker:

Pane rows are displayed as `TITLE  LOC  WINDOW  COMMAND  PATH`.

| Key | Action |
|-----|--------|
| `Enter` | Paste comments into the selected pane |
| `Ctrl+s` | Paste comments and press Enter |
| `Esc` / `q` | Cancel |

## Configuration

```lua
require("review-comments").setup({
  comment_types = {
    note = { key = "n", name = "Note", icon = "📝", hl = "ReviewCommentsNote", line_hl = "ReviewCommentsNoteLine" },
    suggestion = { key = "s", name = "Suggestion", icon = "💡", hl = "ReviewCommentsSuggestion", line_hl = "ReviewCommentsSuggestionLine" },
    issue = { key = "i", name = "Issue", icon = "⚠️", hl = "ReviewCommentsIssue", line_hl = "ReviewCommentsIssueLine" },
    praise = { key = "p", name = "Praise", icon = "✨", hl = "ReviewCommentsPraise", line_hl = "ReviewCommentsPraiseLine" },
  },
  keymaps = {
    add_comment = "<localleader>cc",
    add_note = "<localleader>cn",
    add_suggestion = "<localleader>cs",
    add_issue = "<localleader>ci",
    add_praise = "<localleader>cp",
    add_file_comment = "<localleader>cf",
    delete_comment = "<localleader>cd",
    edit_comment = "<localleader>ce",
    next_comment = "]n",
    prev_comment = "[n",
    list_comments = "<localleader>cl",
    export_clipboard = "<localleader>cx",
    send_sidekick = "<localleader>cS",
    send_tmux = "<localleader>ct",
    clear_comments = "<localleader>cX",
    show_help = "<localleader>c?",
  },
})
```

## Export Format

Comments are exported as Markdown optimized for AI consumption:

```markdown
I reviewed your code and have the following comments. Please address them.

Comment types: ISSUE (problems to fix), SUGGESTION (improvements), NOTE (observations), PRAISE (positive feedback)

1. **[ISSUE]** `src/components/Button.tsx:23` - Wrapping onClick creates a new function every render
2. **[SUGGESTION]** `src/utils/api.ts:45-51` - This block can be simplified
3. **[PRAISE]** `src/hooks/useAuth.ts` - Clean module structure
```

Range comments use `start-end` notation. File-level comments omit the line number.

## Running Tests

```bash
make test
```

## License

Copyright 2025 George Guimaraes

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
