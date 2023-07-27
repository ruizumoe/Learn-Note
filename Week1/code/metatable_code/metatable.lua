-- __index
origin_tab = { a = 3 }
sub_tab = { foo = 12 }
-- 定义寻找方法__index
t = setmetatable(origin_tab, { __index = sub_tab })
print(origin_tab.foo)


-- newindex
--定义一个常量 方法1
local const = {}
local temp = {}
local mt = { --创建一个元表
    __newindex = function(t, k, v)
        -- 此处的t处理的是const表
        if not temp[k] then
            temp[k] = v
        else
            error("尝试给 const." .. k .. " 赋值")
        end
    end,

    __index = temp
}
setmetatable(const, mt)
const.test1 = "test1=="
const.test2 = "test2=="
print(const.test1, const.test2)


-- 定义常量 方法2
-- 一开始就规定好常量内容，__index从常量表中获取数据
-- __newindex拦截修改操作
local function readOnly(t) -- t是初始规定的常量Table，作为__index的索引表
    local proxy = {}       -- 实际常量表的代理，防止进行修改
    local metatable = {
        __index = t,       -- 实际都是从t表查询数据
        __newindex = function(t, k, v)
            print("attempt update const table")
        end
    }
    setmetatable(proxy, metatable)
    return proxy
end

local const_meth2 = readOnly { "Enum1", "Enum2" }
print(const_meth2.Enum1)
const_meth2.Enum1 = "Enum3"

-- metatable call方法调用

local metatable_call_origin = { 10 }
local new_call_table = { 10, 20, 30 }
local call_mt = {
    -- 定义call调用，当将初始表作为函数调用时，会走到该部分内容中
    -- origin_tab 为初始表
    -- para为调用时候的参数
    __call = function(origin_tab, para)
        local sum = 0
        for k, v in ipairs(origin_tab)
        do
            sum = sum +  v
        end

        for k, v in ipairs(para)
        do
            sum = sum + v
        end
        return sum
    end
}
setmetatable(metatable_call_origin, call_mt)
print(metatable_call_origin(new_call_table))
