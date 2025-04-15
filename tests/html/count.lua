local ganiton = require("ganiton")
local html = ganiton.HTML

local doc = html.html {
  html.head {
    html.meta {charset="UTF-8"},
    html.meta {name="viewport", content="width=device-width, initial-scale=1.0"},
    html.title "infinite counter, unless integer overflow"
  },
  html.body {
    html.h1 {id="counter", "0"},
    html.button {
      onclick="update_counter()",
      "Click me!"
    },
    html.script [[
      let inner_counter = 0;
      const counter = document.getElementById("counter");
      function update_counter() {
        counter.textContent = `${++inner_counter}`;
      }
    ]]
  }
}

local html_doc = "<!DOCTYPE html>" .. tostring(doc)
print(html_doc)

return "<!DOCTYPE html>" .. tostring(doc)