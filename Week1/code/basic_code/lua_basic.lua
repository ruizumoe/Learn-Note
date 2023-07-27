-- function
--  函数可以存于变量
function factorial1(n)
    if n == 0 then
        return 1
    else
        return n * factorial1(n - 1)
    end
end

print(factorial1(5))
local factorial2 = factorial1
print(factorial2(5))


-- 函数可以使用匿名函数的方式 通过参数传递
function testFun(tab, fun)
    for k, v in pairs(tab) do
        print(fun(k, v));
    end
end

local table1 = { key1 = "value1", key2 = "value2", key3 = "value3", key4 = "value4" };
testFun(table1,
    function(key, val)
        return key .. ":" .. val;
    end
);


-- 变量
-- 测试值传递

local v_test_1, v_test_2 = 0, 3
v_test_1, v_test_2 = v_test_1 + 1, v_test_1 + 1
print(v_test_1, v_test_2) --   ---> 1, 1


-- 循环

-- while循环
local while_condition = 10;
while (while_condition < 15)
do
    print(while_condition)
    while_condition = while_condition + 1
end

-- for循环 （测试同名）

local for_condition = 10
function f(x)
    return x + 2;
end

for for_condition = 8, f(for_condition), 1
do
    print(for_condition)
end

-- for 循环 泛型遍历
local for_ipairs = { key1 = "val1", key2 = "val2" }
for k, v in pairs(for_ipairs)
do
    print(k .. "::" .. v)
end


-- 函数 可变参数
local function average_table(...)
    local result = 0;
    local arg = { ... }     -- 将可变参数转化为一个tab
    for i, v in ipairs(arg) -- 等价于ipairs({...})
    do
        result = result + v
    end
    -- select("#", ...) 等价于 #arg
    return result / #arg -- #arg表示求table的数据个数
end

print("平均值为", average_table(1, 2, 3, 4, 5, 6))

-- 函数 select
print(select("#", 1, 3, nil, 5, 9, 11))

-- 运算符
local op_table1 = {}
op_table1[1] = "1"
op_table1[5] = 10
op_table1[6] = nil
print(#op_table1)


tab5 = {}
tab5[1] = "1"
tab5[2] = nil
tab5[3] = "2"
tab5[4] = "3"
tab5[5] = "3"
tab5[6] = nil
tab5[7] = "3"
tab5[7] = "3"
print("tab5的长度", #tab5)



-- 字符串

-- 字符串替换 string.gsub
print(string.gsub("aaxaxazz", "axa", "oozd"));

-- 字符串模式条目
local match_str = "asd(asd(aabd))"
print(string.sub(match_str, string.find(match_str, "%b()")))


-- %f的使用
local f_str = "123 h123 hds45678 fdaga123ad  h123s"
local f_str_iter = string.gmatch(f_str, "%f[%A]%d+%f[%s]")

print(f_str_iter())
print(f_str_iter())
print(f_str_iter())


-- 数组
local arr_1 = { 1, 2, 3 }
print(arr_1[10])


-- 泛型for

local function square(iteratorMaxCount, currentNumber)
    if currentNumber < iteratorMaxCount
    then
        currentNumber = currentNumber + 1
        return currentNumber, currentNumber * currentNumber
    end
end

for i, n in square, 1, 0
do
    print(i, n)
end


-- for 多状态泛型for遍历
local array = { "Google", "Runoob" }

local function elementIterator(collection)
    local index = 0
    local count = #collection
    print("index is ", index)
    -- 闭包函数
    return function()
        index = index + 1
        print(index)
        if index <= count
        then
            --  返回迭代器的当前元素
            return collection[index]
        end
    end
end

for element in elementIterator(array)
do
    print(element)
end

--table基础
local tab_1 = {}
local tab_2 = { "a", "b", "c" }

-- 如果table没有显示构造key，则用法类似于数组， 且lua的索引从1开始
print(tab_2[1])
tab_2[1] = nil -- 将"a"删除

local dict = {}
dict["key"] = "value"
dict[10] = 20

for k, v in pairs(dict) do
    -- ..是字符串连接符  使用 + 连接字符串会导致lua直接计算数字
    print(k .. ":" .. v)
end


-- table API
local tab_api_1 = { "app", "bana", 25, "orgin" }
print(table.concat(tab_api_1, "-", 1, -1))

-- sort
local table_api_sort = { 20, 5, 33, 18, 33, 64 }
table.sort(table_api_sort,
    function(a, b)
        if (a == b)
        then
            return false;
        elseif (a > b) then
            return true
        else
            return false
        end
        return false
    end
)

for k, v in ipairs(table_api_sort)
do
    print(k, v)
end

print(not nil)

-- 自定义去重函数
local tab_api_unique = { "a", "d", "c", "g", "d", "w", "c", "a", "g", "s" }
local new_table = {}
local check = {}
for k, v in ipairs(tab_api_unique)
do
    -- 如果new_table[k] 是nil
    if not check[v]
    then
        check[v] = true
        table.insert(new_table, v)
    end
end

for k ,v in pairs(new_table)
do
    print(k, v)
end
