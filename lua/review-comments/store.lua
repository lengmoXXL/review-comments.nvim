local M = {}

local storage = require("review-comments.storage")

---@class Comment
---@field id string
---@field file string
---@field line number
---@field line_end? number
---@field type "note"|"suggestion"|"issue"|"praise"
---@field text string
---@field created_at number

---@type table<string, Comment[]>
M.comments = {}

local id_counter = 0
local loaded = false

---@return string
local function generate_id()
  id_counter = id_counter + 1
  return string.format("comment_%d_%d", os.time(), id_counter)
end

local function persist()
  storage.save(M.comments)
end

local function normalize_loaded_comments(raw_comments)
  local normalized = {}

  for file, comments in pairs(raw_comments or {}) do
    if type(comments) == "table" then
      for _, comment in ipairs(comments) do
        if type(comment) == "table" then
          normalized[file] = normalized[file] or {}
          table.insert(normalized[file], {
            id = comment.id,
            file = comment.file or file,
            line = comment.line,
            line_end = comment.line_end,
            type = comment.type,
            text = comment.text,
            created_at = comment.created_at,
          })
        end
      end
    end
  end

  return normalized
end

function M.reset()
  M.comments = {}
  id_counter = 0
  loaded = false
end

function M.load()
  if loaded then
    return
  end
  M.comments = normalize_loaded_comments(storage.load())
  -- Update id_counter to avoid collisions
  for _, comments in pairs(M.comments) do
    for _, comment in ipairs(comments) do
      local num = tonumber(comment.id:match("comment_%d+_(%d+)"))
      if num and num > id_counter then
        id_counter = num
      end
    end
  end
  loaded = true
end

---@param file string
---@param line number
---@param type "note"|"suggestion"|"issue"|"praise"
---@param text string
---@param line_end? number
---@return Comment
function M.add(file, line, type, text, line_end)
  if not M.comments[file] then
    M.comments[file] = {}
  end

  local comment = {
    id = generate_id(),
    file = file,
    line = line,
    line_end = (line_end and line_end ~= line) and line_end or nil,
    type = type,
    text = text,
    created_at = os.time(),
  }

  table.insert(M.comments[file], comment)
  persist()
  return comment
end

---@param id string
---@return Comment|nil
function M.get(id)
  for _, comments in pairs(M.comments) do
    for _, comment in ipairs(comments) do
      if comment.id == id then
        return comment
      end
    end
  end
  return nil
end

---@param file string
---@return Comment[]
function M.get_for_file(file)
  return M.comments[file] or {}
end

---@param file string
---@return Comment|nil
function M.get_file_comment(file)
  local comments = M.comments[file] or {}
  for _, comment in ipairs(comments) do
    if comment.line == 0 then
      return comment
    end
  end
  return nil
end

---@param file string
---@param line number
---@return Comment|nil
function M.get_at_line(file, line)
  local comments = M.comments[file] or {}
  for _, comment in ipairs(comments) do
    local line_end = comment.line_end or comment.line
    if line >= comment.line and line <= line_end then
      return comment
    end
  end
  return nil
end

---@param file string
---@param start_line number
---@param end_line number
---@return Comment|nil
function M.get_overlapping(file, start_line, end_line)
  local comments = M.comments[file] or {}
  for _, comment in ipairs(comments) do
    local c_end = comment.line_end or comment.line
    if comment.line <= end_line and c_end >= start_line then
      return comment
    end
  end
  return nil
end

---@param id string
---@param text string
---@param new_type? "note"|"suggestion"|"issue"|"praise"
---@return boolean
function M.update(id, text, new_type)
  for _, comments in pairs(M.comments) do
    for _, comment in ipairs(comments) do
      if comment.id == id then
        comment.text = text
        if new_type then
          comment.type = new_type
        end
        persist()
        return true
      end
    end
  end
  return false
end

---@param id string
---@return boolean
function M.delete(id)
  for file, comments in pairs(M.comments) do
    for i, comment in ipairs(comments) do
      if comment.id == id then
        table.remove(comments, i)
        if #comments == 0 then
          M.comments[file] = nil
        end
        persist()
        return true
      end
    end
  end
  return false
end

---@return Comment[]
function M.get_all()
  local all = {}
  for _, comments in pairs(M.comments) do
    for _, comment in ipairs(comments) do
      table.insert(all, comment)
    end
  end
  table.sort(all, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.line < b.line
  end)
  return all
end

---@return table<string, Comment[]>
function M.get_all_by_file()
  return M.comments
end

---@return number
function M.count()
  local count = 0
  for _, comments in pairs(M.comments) do
    count = count + #comments
  end
  return count
end

function M.clear()
  M.reset()
  storage.clear()
end

return M
