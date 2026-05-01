local M = {}

local utils = require("review.utils")

local data_dir = vim.fn.stdpath("data") .. "/review"

---@param str string
---@return string
local function hash(str)
  local h = 0
  for i = 1, #str do
    h = ((h * 31) + string.byte(str, i)) % 2147483647
  end
  return string.format("%x", h)
end

---@return string|nil
function M.get_storage_path()
  local project_root = utils.get_project_root()
  local project_hash = hash(project_root)

  -- Ensure directory exists (pcall to suppress error if exists)
  pcall(vim.fn.mkdir, data_dir, "p")

  return string.format("%s/%s.json", data_dir, project_hash)
end

---@param comments table
function M.save(comments)
  local path = M.get_storage_path()
  if not path then
    return
  end

  local data = vim.fn.json_encode(comments)
  local file = io.open(path, "w")
  if file then
    file:write(data)
    file:close()
  end
end

local EXPIRY_SECONDS = 7 * 24 * 60 * 60
local cleanup_done = false

function M.cleanup_expired()
  if cleanup_done then
    return
  end
  cleanup_done = true

  vim.defer_fn(function()
    local files = vim.fn.glob(data_dir .. "/*.json", false, true)
    local now = os.time()
    for _, filepath in ipairs(files) do
      local mtime = vim.fn.getftime(filepath)
      if mtime > 0 and (now - mtime) > EXPIRY_SECONDS then
        os.remove(filepath)
      end
    end
  end, 0)
end

---@return table
function M.load()
  M.cleanup_expired()

  local path = M.get_storage_path()
  if not path then
    return {}
  end

  local file = io.open(path, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and data then
      return data
    end
  end

  return {}
end

function M.clear()
  local path = M.get_storage_path()
  if path then
    os.remove(path)
  end
end

return M
