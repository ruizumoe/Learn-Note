local test_add_nil = { 1, a = 5, nil, 3, b = 5 }
test_add_nil[2] = nil
for k, v in pairs(test_add_nil)
do
    print(k, v)
end


local test_resize_table = { 1, nil, nil, nil, 3, nil, nil, nil, nil, nil, 5 }
table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)

test_resize_table.a = "asd"
test_resize_table.b = "asd"
test_resize_table.c = "asd"
test_resize_table.d = "asd"
test_resize_table.e = "asd"
test_resize_table.a = nil
test_resize_table.b = nil
test_resize_table.c = nil
test_resize_table.f = "asd"
test_resize_table.g = "asd"
test_resize_table.h = "asd"
table.insert(test_resize_table, 6)


test_resize_table.i = "asd"
test_resize_table.j = "asd"
test_resize_table.k = "asd"
table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)




table.insert(test_resize_table, 6)

table.insert(test_resize_table, 6)

table.insert(test_resize_table, 6)

table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)
table.insert(test_resize_table, 6)

table.insert(test_resize_table, 6)

