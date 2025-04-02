# HTML module

this module allows to write lua tables that translate to HTML.

here's a basic example to define a HTML document with it:
```lua
local ganiton = require("ganiton")
local html = ganiton.HTML

local doc = html.html {
  html.head {
    html.meta {charset="UTF-8"},
    html.meta {name="viewport", content="width=device-width, initial-scale=1.0"},
    html.title "Document"
  },
  html.body {
    hmtl.h1 "Hello, world!"
  }
}
```

# Explanation

when you index the `html` magic table, it internally calls a function that creates a HTML element
based on the index name.

## Indexing

When you put an index inside the table, e.g `html.meta {charset="UTF-8"}`, instead of it becaming a child,
it becames an attribute.

But when you put a literal instead a table, it become a child. e.g. `html.h1 "Hello, world!"`

# Important

In this module, there's no check that validates the tag, so if you create a tag that doesn't
exists in HTML, you won't notice until put the transpiled table into a file.

# Utilities

## ganiton.nochildren(tagname)

This function makes that when you create a tag with `tagname` it can't have children.

by default there is these tags:

img
br
hr
input
meta
link

## ganiton.nosanitize(tagname)

At the creation of the element, if the tag name is marked as nosanitize, some symbols that are
special in html, will not be sanitized, like '<', '>' and '&'.

## ganiton.doc_concat(doc, fmt)

concatenates recursively a HTML element or an entire document.

## ganiton.raw(...)

returns sanitized string to use with some tags like script.