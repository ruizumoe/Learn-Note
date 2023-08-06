local table1 = {}
local s = ""

local c = 1
for i = 1, 1024, 1
do

    s = s .. c
    c = c + 1
    c = c % 10
end

for i = 1, 3, 1
do
    table.insert(table1, s)
end

a = table.concat(table1, '::::::')
print(a)
