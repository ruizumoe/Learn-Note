--table
local tab_1 = {}
local tab_2 = { "a", "b", "c" }

-- 如果table没有显示构造key，则用法类似于数组， 且lua的索引从1开始
print(tab_2[1])
tab_2[1] = nil   -- 将"a"删除

local dict = {}
dict["key"] = "value"
dict[10] = 20

for k, v in pairs(dict) do
    -- ..是字符串连接符  使用 + 连接字符串会导致lua直接计算数字
    print(k .. ":" .. v) 
end


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
print(v_test_1, v_test_2)       --   ---> 1, 1
