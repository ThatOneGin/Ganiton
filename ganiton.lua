---@diagnostic disable: undefined-field
local success, socket = pcall(require, "socket")

-- yes, recursive error report
local function ganiton_error(msg)
  if msg == nil then
    ganiton_error("Internal error, expected parameter `msg` for error message to be a string, not nil.")
  end
  print("Error: ".. msg)
  os.exit(1)
end

local function ensure(expr, errmsg)
	if not expr then
		ganiton_error(errmsg)
	end
end

if not success then
  ganiton_error("couldn't find `socket` module with require which is required by `ganiton.Socket` module")
end

local Ganiton = {
  JSON = {},
  Socket = {},
  IO = {},
  --[[
  The Gton preprocessor allows to write lua inside html.

  how to setup a Gton base file:
  ```lua
  local ganiton = require("ganiton")
  ganiton.Preprocessor.Gton("<your-file.gton>")
  ```
  ]]
  Preprocessor = {}
}
local private = {gton_output_file=io.stdout}
local nochildren = {
  ["img"] = true,
  ["br"] = true,
  ["hr"] = true,
  ["input"] = true,
  ["meta"] = true,
  ["link"] = true,
}

local nosanitize = {
  ["script"] = true,
  ["style"] = true,
}

---@class HTMLNode
local node_metatable = {
  __call = function(self, attr)
    local new = private.create_node(self.tag, self.attributes, self.children)

    if type(attr) == "table" then
      for i, v in pairs(attr) do
        if type(i) == "number" then
          table.insert(new.children, v)
        else
          new.attributes[i] = v
        end
      end
    else
      new.children[#new.children + 1] = attr
    end

    return new
  end
}

private.sanitize = function(str)
  return (str:gsub("[<>&]", {
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ["&"] = "&amp;"
  }))
end

private.sanitizeattr = function(str)
  return (private.sanitize(str):gsub("\"", "&quot;"):gsub("'", "&#39;"))
end

---@param node HTMLNode
private.node_to_string = function(node)
  local str = "<" .. node.tag

  for k, v in pairs(node.attributes) do
    str = str .. string.format(' %s="%s"', k, private.sanitizeattr(v))
  end

  str = str .. ">"

  if not nochildren[node.tag] then
    for _, child in ipairs(node.children) do
      if type(child) == "table" and getmetatable(child) == node_metatable then
        str = str .. private.node_to_string(child)
      elseif type(child) == "function" then
        -- assuming its a coroutine
        local f = coroutine.wrap(child)
        for elm in f do
          str = str .. private.node_to_string(elm)
        end
      else
        if not nosanitize[node.tag] then
          str = str .. private.sanitize(tostring(child))
        else
          str = str .. tostring(child)
        end
      end
    end

    str = str .. "</" .. node.tag .. ">"
  end

  return str
end

---@param tag string
---@param attr table?
---@param children table?
---@return HTMLNode
private.create_node = function(tag, attr, children)
  return setmetatable({
    tag = tag,
    attributes = attr or {},
    children = children or {},
  }, node_metatable)
end

--[[
Creates a table that is convertable to html when indexing.

Example:
```lua
local ganiton = require("ganiton")

local doc = ganiton.html.h1 "Hello, world!"

print(doc) -- will print <h1>Hello, world!</h1>
```
]]
Ganiton.HTML = setmetatable({}, {
  ---@param tag string
  ---@return table
  __index = function(_, tag)
    return private.create_node(tag)
  end
})

Ganiton.raw = function(...)
  return tostring(...):gsub("[\n\t]", {
    ["\n"] = "",
    ["\t"] = "",
  }):gsub("%s+", " ")
end

Ganiton.nochildren = function(tagname)
  nochildren[tagname] = true
end

Ganiton.nosanitize = function(tagname)
  nosanitize[tagname] = true
end

node_metatable.__tostring = private.node_to_string

--[[ JSON
got JSON parsing implementation from:
  - https://gist.github.com/tylerneylon/59f4bcf316be525b30ab


this module is from the above gist, but with two modifications:
  - function support (assume all given functions are coroutines)
  - different error information using ganiton_error function (not a big modification)

i also didn't modify the comments because they are helpful when modifying later.
]]

local json = {}

local function type_of(obj)
  local obj_type = type(obj)
  if obj_type ~= "table" then return obj_type end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return "table" end
  end
  if i == 1 then return "table" else return "array" end
end

local function escape_str(s)
  local in_char  = {"\\", "\"", "/", "\b", "\f", "\n", "\r", "\t"}
  local out_char = {"\\", "\"", "/",  "b",  "f",  "n",  "r",  "t"}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, "\\" .. out_char[i])
  end
  return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match("^%s*", pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      ganiton_error("Expected " .. delim .. " near position " .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
  val = val or ""
  local early_end_error = "End of input found while parsing string."
  if pos > #str then ganiton_error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == "\""  then return val, pos + 1 end
  if c ~= "\\" then return parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = {b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then ganiton_error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number"s final character.
local function parse_num_val(str, pos)
  local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  local val = tonumber(num_str)
  if not val then ganiton_error("Error parsing number at position " .. pos .. ".") end
  return val, pos + #num_str
end

--[[
Returns a string containing JSON code.

Example:
```lua
local doc = html.html {
  html.head {
    html.meta {charset="UTF-8"},
    html.meta {name="viewport", content="width=device-width, initial-scale=1.0"},
    html.title "Document"
  },
  html.body {
    html.h1 "Hello, world!"
  }
}
local json_string = json.stringify(doc)
print(json_string)
```
]]
---@param obj any
---@param as_key boolean?
---@return string
function json.stringify(obj, as_key)
  local s = {}  -- We"ll build the string as an array of strings to be concatenated.
  local kind = type_of(obj)  -- This is "array" if it"s an array or type(obj) otherwise.
  if kind == "array" then
    if as_key then ganiton_error("Can\"t encode array as key.") end
    s[#s + 1] = "["
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ", " end
      s[#s + 1] = json.stringify(val)
    end
    s[#s + 1] = "]"
  elseif kind == "table" then
    if as_key then ganiton_error("Can\"t encode table as key.") end
    s[#s + 1] = "{"
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ", " end
      s[#s + 1] = json.stringify(k, true)
      s[#s + 1] = ":"
      s[#s + 1] = json.stringify(v)
    end
    s[#s + 1] = "}"
  elseif kind == "string" then
    return "\"" .. escape_str(obj) .. "\""
  elseif kind == "number" then
    if as_key then return "\"" .. tostring(obj) .. "\"" end
    return tostring(obj)
  elseif kind == "boolean" then
    return tostring(obj)
  elseif kind == "nil" then
    return "null"
  elseif kind == "function" then
    local f = coroutine.wrap(obj)
    for ch in f do
      s[#s+1] = json.stringify(ch)
      s[#s+1] = ", "
    end
  else
    ganiton_error("Unjsonifiable type: " .. kind .. ".")
  end
  return table.concat(s)
end

json.null = {} -- This is a one-off table to represent the null value.

--[[
Parses a json string and returns the lua equivalent.
example:
```lua
local json_string = "{\"name\": \"john\", \"age\": 23}"
local json_obj = json.parse(json_string)

print(json_obj.name, json_obj.age)
```
]]
---@param str string
---@param pos number?
---@param end_delim string?
---@return boolean|number|table|unknown|nil
---@return number|unknown
function json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then ganiton_error("Reached unexpected end of input.") end
  local pos = pos + #str:match("^%s*", pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == "{" then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      ---@diagnostic disable-next-line: cast-local-type
      key, pos = json.parse(str, pos, "}")
      if key == nil then return obj, pos end
      if not delim_found then ganiton_error("Comma missing between object items.") end
      pos = skip_delim(str, pos, ":", true)  -- true -> error if missing.
      ---@diagnostic disable-next-line: need-check-nil
      obj[key], pos = json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ",")
    end
  elseif first == "[" then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      ---@diagnostic disable-next-line: cast-local-type
      val, pos = json.parse(str, pos, "]")
      if val == nil then return arr, pos end
      if not delim_found then ganiton_error("Comma missing between array items.") end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ",")
    end
  elseif first == "\"" then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == "-" or first:match("%d") then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {["true"] = true, ["false"] = false, ["null"] = json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = "position " .. pos .. ": " .. str:sub(pos, pos + 10)
    ganiton_error("Invalid json syntax starting at " .. pos_info_str)
  end
  return {}, 0
end

--[[ Sockets ]]

--[[
Opens a web socket and displays static HTML or JSOn into it.

example:
```lua
local ganiton = require("ganiton")

local doc = ganiton.html.html {lang="pt-br"} {
  ganiton.html.head {
    ganiton.html.meta {charset="UTF-8"},
    ganiton.html.meta {name="viewport", content="width=device-width, initial-scale=1.0"}
  },
  ganiton.html.body {
    ganiton.html.h1 "Hello, world!"
  }
}

ganiton.Socket.host("close", "text/html", tostring(doc))
```
]]
---@param connection string?
---@param content_type string?
---@param content string?
---@param response_code string?
---@param port integer?
function private.host(connection, content_type, response_code, content, port)
  if not content_type then
    content_type = "text/plain"
  end
  if not connection then
    connection = "close"
  end
  if not response_code then
    response_code = "200 OK"
  end
  if not content then
    content = "Hello, Ganiton!"
  end
  if not port then
    port = 8080
  end

  local server = assert(socket.bind("*", port))
  server:settimeout(0)

  print(string.format("Server is listening on port %d...", port))

  while true do
    local client = server:accept()

    if client then
      client:settimeout(10)

      local request, err = client:receive("*l")

      if request then
        print("Request received: " .. request)

        local response = string.format([[
HTTP/1.1 200 OK
Content-Type: %s
Connection: %s

%s]], content_type, connection, content)

        client:send(response)
      else
        print("Error receiving request: " .. err)
      end

      client:close()
    end

    -- avoid high usage of CPU as the server is non blocking
    socket.sleep(0.01)
  end
end

--[[
Unlike ```Socket.host```, ```Socket.host_with_response``` allows to threat 
HTTP requests instead of just printing them.

example:
```lua
local ganiton = require("ganiton")

local doc = ganiton.html.html {lang="pt-br"} {
  ganiton.html.head {
    ganiton.html.meta {charset="UTF-8"},
    ganiton.html.meta {name="viewport", content="width=device-width, initial-scale=1.0"}
  },
  ganiton.html.body {
    ganiton.html.h1 "Hello, world!"
  }
}

local function handle_request(req)
  return "<!DOCTYPE html>" .. tostring(doc)
end

ganiton.Socket.host_with_response(
  "close",
  "text/html",
  handle_request,
  3000)
```
]]
---@param connection string?
---@param content_type string?
---@param response_code string?
---@param response_fn function
---@param port integer?
function private.host_with_response(connection, content_type, response_code, response_fn, port)
  if not content_type then
    content_type = "text/plain"
  end
  if not connection then
    connection = "close"
  end
  if not response_code then
    response_code = "200 OK"
  end
  if not port then
    port = 8080
  end

  local server = assert(socket.bind("*", port))
  server:settimeout(0)

  while true do
    print(string.format("Server is listening on port %d...", port))
    local client = server:accept()

    if client then
      client:settimeout(10)

      local request, err = client:receive("*l")

      if request then
        print("Request received: " .. request)

        local response = response_fn(request)

        client:send(response)
      else
        print("Error receiving request: " .. err)
      end

      client:close()
    end

    socket.sleep(0.01)
  end
end

--[[
Returns a piece of a HTTP header.

]]
---@param code string
---@param content_type string
---@param connection string
---@return string
function private.HTTP_header(code, content_type, connection)
  return string.format("HTTP/1.1 %s\nContent-Type: %s\nConnection: %s\n",
    code,
    content_type,
    connection
  )
end

--[[
Get the source of a file link (e.g. .js, .css and .html).

incase of failure, returns the error message

example:
```lua
local ganiton = require("ganiton")
local style = ganiton.IO.Get_source_content("style.css")

local doc = ganiton.html.html {
  ganiton.html.head {
    ganiton.html.style(style)
  }
}
```
]]
---@param path string
---@return string
---@return boolean
function private.Get_source_content(path)
  local f, errmsg = io.open(path, "r")
  if f ~= nil then
    local fc = f:read("a")
    f:close()
    return fc, true
  end
  return errmsg ~= nil and errmsg or "Couldn't open file.", false
end

--[[
Dumps html to file without indentation.

example:
```lua
local ganiton = require("ganiton")

local doc = -- ... html code

ganiton.IO.Html_to_file(tostring(doc))
```
]]
---@param doc string
function private.Dump_html_to_file(doc)
  local f = io.open("index.html", "w")
  assert(f)
  f:write(doc)
  f:close()
end

--[[ DB ]]--

function private.serialize_table(tbl)
  local result = ""
  for key, value in pairs(tbl) do
      if type(value) == "table" then
          result = result .. private.serialize_table(value)
      else
          result = result .. key .. "=" .. tostring(value) .. "\n"
      end
  end
  return result
end

function private.parse_table(data_str)
  local tbl = {}
  for line in data_str:gmatch("[^\n]+") do
      local key, value = line:match("([^=]+)=([^=]+)")
      tbl[key] = value
  end
  return tbl
end

---@param filename string
---@param data_table table
function private.load_to_file(filename, data_table)
  local f, errmsg = io.open(filename, "w+")
  assert(f, "Couldn't open file " .. (errmsg or ""))
  local data_str = private.serialize_table(data_table)
  f:write(data_str)
  f:flush()
  f:close()
end

---@param filename string
---@return table
function private.load_from_file(filename)
  local data_table = private.Get_source_content(filename)
  return private.parse_table(data_table)
end

---@class DB
local db = {dir="", tables={}}
db.__index = db

--[[
Returns a new database object.
dir must be a valid directory

example:
```lua
local mydb = ganiton.DB:new("./db")
```
]]
---@param dir string
---@return DB
function db:new(dir)
  local newdb = setmetatable({}, self)
  newdb.dir = dir
  newdb.tables = {}
  return newdb
end

--[[
if the table of given name exists, returns its content, true and a success message.
Otherwise, an empty table, false and an error message

example:
```lua
local tbl = mydb:get_table("user_preferences")
```
]]
---@param table_name string
---@return table
---@return boolean
---@return string
function db:get_table(table_name)
  local t = self.tables[table_name]
  if not t or t == nil then
    return {}, false, string.format("Table %s is nonexistent", table_name)
  end
  return t, true, "success"
end

--[[
puts a new table inside a db object.

example:
```lua
mydb:new_table("user_preferences", {theme="dark",notifications="false"})
```
]]
---@param table_name string
---@param table_content table?
function db:new_table(table_name, table_content)
  self.tables[table_name] = table_content or {}
end

--[[
gets an element of given table name.
returns nil, false and an error message on fail.

example:
```lua
local theme = mydb:get("user_preferences", "theme")
```
]]
---@param table_name string
---@param index string
---@return any
---@return boolean
---@return string
function db:get(table_name, index)
  local t, success, errmsg = self:get_table(table_name)
  if not success then
    print(errmsg)
    return nil, false, errmsg
  end
  local elm = t[index]
  if not elm then
    return nil, false, string.format("Element at index %s is nonexistent", index)
  end
  return elm, true, "success"
end

--[[
Sets an element to given table_name at given index.
returns nil, false and error message on fail

example:
```lua
mydb:set("user_preferences", "theme", "dark")
```
]]
---@param table_name string
---@param index string
---@param value any
---@return nil
---@return boolean
---@return string
function db:set(table_name, index, value)
  local t, success, errmsg = self:get_table(table_name)
  if not success then
    print(errmsg)
    return nil, false, errmsg
  end
  t[index] = value
  return nil, true, "success"
end

--[[
write every table to its corresponding file.

example:
```lua
mydb:load_to_file("json")
mydb:load_to_file("key-value pair")
```
]]
function db:load_to_file(encoding)
  if encoding == "key-value pair" then
    for i, v in pairs(self.tables) do
      local f, errmsg = io.open(self.dir.."/"..i, "w+")
      assert(f, errmsg)
      f:write(private.serialize_table(v))
      f:close()
    end
  elseif encoding == "json" then
    local f, errmsg = io.open(self.dir.."/page.json", "w+")
    assert(f, errmsg)
    f:write(json.stringify(self.tables))
    f:close()
  end
end

--[[
Parses given table from file.

example:
```lua
mydb:load_table_from_file("user_preferences")
```
]]
---@param table_name string
function db:load_table_from_file(table_name)
  local dir_end = self.dir:sub(#self.dir, #self.dir)
  local dir = self.dir

  if dir_end ~= "/" then
    dir = dir .. "/"
  end

  self.tables[table_name] = private.load_from_file(dir..table_name)
end

--[[ end db ]]--

--[[
concatenates given array of html nodes.
example:

```lua
return ganiton.doc_concat(doc, "\n")
```
]]
---@param node HTMLNode[]
---@return string
Ganiton.doc_concat = function(node, delim)
	delim = delim or ""
	local out = ""
	for i, child in pairs(node) do
  	out = out .. tostring(child) .. delim
	end
  out = out:sub(1, #out-#delim)
	return out
end

Ganiton.Socket.HTTP_header = private.HTTP_header
Ganiton.Socket.sleep = socket.sleep
Ganiton.Socket.Host = private.host
Ganiton.Socket.Host_with_response = private.host_with_response
Ganiton.JSON = json
Ganiton.IO.Get_source_content = private.Get_source_content
Ganiton.IO.Dump_html_to_file = private.Dump_html_to_file
Ganiton.DB = db

--[[ GTON ]]

local gton_env = {
  tostring = tostring,
  tonumber = tonumber,
  print = print,
  ganiton = Ganiton,
  table = table,
  math = math,
  string = string,
  coroutine = coroutine
}

---@param src string
---@return string
local function get_gton_tag(src)
  local gton_tag = src:match("<gton(.-)>")
  if gton_tag == nil then
    return ""
  end
  local gton_tag_content = gton_tag:gsub("[\n\r]", "")
  return gton_tag_content
end

---@param src string
---@return string
local function eval_gton_src(src)
  local out = load(src, "gton_eval", "t", gton_env)()
  return out == nil and "" or out
end

---@param src string
---@param out string
local function subst_tag_to_output(src, out)
  return src:gsub("<gton(.-)>", out)
end

local function eval_gton_file(file)
  local f, errmsg = io.open(file, "r")
  if f == nil then
    ensure(false, string.format("Couldn't open output file: %s", errmsg))
    os.exit(1)
  end
  local src = f:read("a")
  f:close()
  local gton_tag = get_gton_tag(src)
  local out = eval_gton_src(gton_tag)
  local tmp_src, n = subst_tag_to_output(src, tostring(out))
  if n > 1 then
    ganiton_error("multiple <gton> tags is not supported yet.")
  end
  private.gton_output_file:write(tmp_src)
end

---@param file file*
local function gton_redirect_output(file)
  private.gton_output_file = file
end

Ganiton.Preprocessor.Redirect_output = gton_redirect_output
Ganiton.Preprocessor.Gton = eval_gton_file

return Ganiton
