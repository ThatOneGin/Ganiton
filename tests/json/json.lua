local ganiton = require("ganiton")
local json = ganiton.JSON
local html = ganiton.HTML

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