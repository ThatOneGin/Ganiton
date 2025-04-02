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