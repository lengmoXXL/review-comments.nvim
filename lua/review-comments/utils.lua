local M = {}

---Normalize a file path for consistent storage/lookup
---@param path string
---@return string
function M.normalize_path(path)
  if not path then
    return path
  end
  path = path:gsub("^%./", "")
  path = path:gsub("/+$", "")
  return path
end

---@param path string|nil
---@return boolean
function M.is_uri(path)
  return type(path) == "string" and path:match("^[%w+.-]+://") ~= nil
end

---@param path? string file or directory path. Defaults to current working directory.
---@return string|nil git_root absolute normalized path
function M.get_git_root(path)
  local dir = path and path ~= "" and path or vim.fn.getcwd()
  if M.is_uri(dir) then
    return nil
  end

  if vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  while dir ~= "" and vim.fn.isdirectory(dir) == 0 do
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  dir = vim.fn.fnamemodify(dir, ":p")
  local result = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not result[1] or result[1] == "" then
    return nil
  end

  return M.normalize_path(vim.fn.fnamemodify(result[1], ":p"))
end

---@param path? string file or directory path. Defaults to current working directory.
---@return string project root absolute normalized path
function M.get_project_root(path)
  return M.get_git_root(path) or M.normalize_path(vim.fn.fnamemodify(vim.fn.getcwd(), ":p"))
end

---@param path string
---@return string
function M.to_comment_path(path)
  if not path or path == "" or M.is_uri(path) then
    return path
  end

  local abs = M.normalize_path(vim.fn.fnamemodify(path, ":p"))
  local git_root = M.get_git_root(abs)
  if git_root and abs:sub(1, #git_root) == git_root then
    local rel = abs:sub(#git_root + 1)
    rel = rel:gsub("^/", "")
    if rel ~= "" then
      return M.normalize_path(rel)
    end
  end

  return abs
end

---@param bufnr number
---@return string|nil
function M.get_buffer_comment_path(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if not name or name == "" or M.is_uri(name) then
    return nil
  end

  return M.to_comment_path(name)
end

---@param file string
---@return string
function M.resolve_comment_path(file)
  if not file or file == "" or file:sub(1, 1) == "/" then
    return file
  end
  return M.normalize_path(M.get_project_root() .. "/" .. file)
end

return M
