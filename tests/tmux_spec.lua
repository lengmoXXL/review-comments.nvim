local store = require("review-comments.store")
local tmux = require("review-comments.tmux")
local t = tmux._test

describe("review-comments.tmux", function()
  local calls
  local original_notify

  before_each(function()
    store.clear()
    calls = {}
    original_notify = vim.notify
    vim.notify = function() end
    t.reset_recent()
    t.set_runner(function(argv, input)
      table.insert(calls, { argv = argv, input = input })
      return true, {}, 0
    end)
  end)

  after_each(function()
    vim.notify = original_notify
    t.reset_recent()
    t.reset_runner()
    store.clear()
  end)

  describe("parse_pane_line", function()
    it("parses tmux pane fields", function()
      local pane = t.parse_pane_line("%1\t2\t0\teditor\tcodex\tnvim\t/workspace/project")

      assert.equals("%1", pane.id)
      assert.equals("2", pane.window_index)
      assert.equals("0", pane.pane_index)
      assert.equals("editor", pane.window_name)
      assert.equals("codex", pane.title)
      assert.equals("nvim", pane.command)
      assert.equals("/workspace/project", pane.path)
      assert.is_nil(pane.display:find("%%1"))
      assert.matches("2%.0", pane.display)
      assert.matches("codex", pane.display)
    end)

    it("ignores malformed rows", function()
      assert.is_nil(t.parse_pane_line(""))
      assert.is_nil(t.parse_pane_line("%1\t2"))
    end)

    it("aligns pane display with the header", function()
      local header = t.header_line()
      local pane = t.parse_pane_line("%12\t10\t3\teditor\tcodex\tnvim\t/workspace/project")

      assert.is_nil(pane.display:find("%%12"))
      assert.equals(header:find("TITLE", 1, true), pane.display:find("codex", 1, true))
      assert.equals(header:find("LOC", 1, true), pane.display:find("10.3", 1, true))
      assert.equals(header:find("WINDOW", 1, true), pane.display:find("editor", 1, true))
      assert.equals(header:find("COMMAND", 1, true), pane.display:find("nvim", 1, true))
      assert.equals(header:find("PATH", 1, true), pane.display:find("/workspace/project", 1, true))
    end)
  end)

  describe("list_panes", function()
    it("lists panes in the current session", function()
      t.set_runner(function(argv, input)
        table.insert(calls, { argv = argv, input = input })
        if argv[2] == "display-message" then
          return true, { "work" }, 0
        end
        return true, {
          "%1\t1\t0\teditor\tcodex\tnvim\t/workspace/review.nvim",
          "%2\t1\t1\tshell\tserver\tbash\t/workspace/review.nvim",
        }, 0
      end)

      local panes = tmux.list_panes()

      assert.equals(2, #panes)
      assert.equals("%1", panes[1].id)
      assert.equals("work", calls[2].argv[5])
    end)
  end)

  describe("recent pane ordering", function()
    it("puts recently used panes first and drops missing panes", function()
      t.remember_pane("%3")
      t.remember_pane("%9")
      t.remember_pane("%1")

      local sorted = t.sort_panes_by_recent({
        { id = "%1" },
        { id = "%2" },
        { id = "%3" },
      })

      assert.equals("%1", sorted[1].id)
      assert.equals("%3", sorted[2].id)
      assert.equals("%2", sorted[3].id)
    end)
  end)

  describe("send_to_pane", function()
    it("loads and pastes markdown without pressing enter", function()
      local ok = tmux.send_to_pane({ id = "%2" }, "review body", false)

      assert.is_true(ok)
      assert.equals("load-buffer", calls[1].argv[2])
      assert.equals("review body", calls[1].input)
      assert.equals("paste-buffer", calls[2].argv[2])
      assert.equals("%2", calls[2].argv[6])
      assert.equals("delete-buffer", calls[3].argv[2])
      assert.is_nil(calls[4])

      local sorted = t.sort_panes_by_recent({ { id = "%1" }, { id = "%2" } })
      assert.equals("%2", sorted[1].id)
    end)

    it("sends enter when requested", function()
      local ok = tmux.send_to_pane({ id = "%3" }, "review body", true)

      assert.is_true(ok)
      assert.equals("send-keys", calls[4].argv[2])
      assert.equals("%3", calls[4].argv[4])
      assert.equals("Enter", calls[4].argv[5])
    end)
  end)

  describe("send_current_review", function()
    it("does not call tmux when there are no comments", function()
      tmux.send_current_review()

      assert.equals(0, #calls)
    end)
  end)

  describe("build_picker_lines", function()
    it("keeps the header separate from selectable pane rows", function()
      local header, lines = t.build_picker_lines({
        { id = "%1", display = "title                 1.0    win               cmd             path" },
      })

      assert.matches("TITLE", header)
      assert.equals(1, #lines)
      assert.not_matches("TITLE", lines[1])
      assert.matches("title", lines[1])
    end)
  end)
end)
