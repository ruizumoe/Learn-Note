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

