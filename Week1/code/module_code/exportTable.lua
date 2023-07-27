module = {}

module.cont = 1      -- 全局变量可以访问

function module.fun1()
    return "this is func1"
end

local function func2()      -- 私有函数，外部不可访问
    return "this is local func2"
end

function module.func3()
    return func2()
end

return module