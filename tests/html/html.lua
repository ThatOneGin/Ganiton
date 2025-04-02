local ganiton = require("ganiton")
local html = ganiton.HTML

local doc = html.html {
  html.head {
    html.meta {charset="UTF-8"},
    html.meta {name="viewport", content="width=device-width, initial-scale=1.0"},
    html.title "Document"
  },
  html.body {
    function ()
      for i=1, 9 do
        coroutine.yield(html.h1{string.format("Counter: %d", i)})
      end
    end
  }
}

local html_doc = "<!DOCTYPE html>" .. tostring(doc)
print(html_doc)

return "<!DOCTYPE html>" .. tostring(doc)