# Ganiton

### A library that has HTML generation, preprocessing and JSON parsing

**Disclaimer: this library is inspired by [LuaXMLGenerator](https://github.com/TheLuaOSProject/LuaXMLGenerator/)**

# Dependencies

  - luasocket (required for socket module)

# Installation

Copy and paste ganiton.lua in whatever folder you want and import it.

```lua
  local ganiton = require("path.to.ganiton")
  -- very cool stuff here
```

# Modules

- [Socket](./docs/socket.md) Test things in a localhost.

- [JSON](./docs/json.md) JSON parsing.

- [HTML](./docs/html.md) HTML generation.

- [IO](./docs/io.md) Input output functions.

- [DB](./docs/db.md) Read and write data from disk.

- [Gton](./docs/preprocessor.md) Write Lua inside HTML.

# Todos

  1. Lua tables to Cascading style sheets.

  2. Support for multiple preprocessor tags.

  3. More examples.