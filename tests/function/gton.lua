local ganiton = require("ganiton")
local f, errmsg = io.open("index.html", "w+")
assert(f, string.format("Couldn't open output file: %s", errmsg))

ganiton.Preprocessor.Redirect_output(f)
ganiton.Preprocessor.Gton("test.gton")
f:close()