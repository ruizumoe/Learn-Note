local table1 = {}

for i = 1, 52, 1
do
    for j = 1, 5, 1
    do
        table.insert( table1, j )
    end
end

a = table.concat(table1, ',')
print(a)

local a = "test1"

local table2 = {
    [a] = 20
}

for k, v in pairs(table2)
do
    print(k, v)
end
