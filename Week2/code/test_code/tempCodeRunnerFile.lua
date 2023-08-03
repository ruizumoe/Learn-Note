local test_add_nil = { 1, a = 5, nil, 3, b = 5 }
test_add_nil[2] = nil
for k, v in pairs(test_add_nil)
do
    print(k, v)
end
