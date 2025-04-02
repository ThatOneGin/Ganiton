# DB

Module to write and read data (made for testing and shouldn't be used with complex data).

Example use:
```lua
local ganiton = require("ganiton")
local db = ganiton.DB

local mydb = db:new("./db")
local data = {name="urmomsofat43", age=539}
local settings = {theme="dark", notifications="true"}

mydb:new_table("user", {data, settings})
mydb:load_to_file()
mydb:load_table_from_file("user")
print(mydb:get("user", "name"))
mydb:set("user", "name", "urmomsofat43")
print(mydb:get("user", "name"))
mydb:load_to_file("key-value pair")
```

a DB object is made of a dir, a valid folder that can store files and tables, various tables to
store key-pair values.

you can use get and set to modify and query values from a table.

and when you is done, you can load to a file and can also use key-value pair encoding or json encoding by just passing the string argument in the function load_to_file.