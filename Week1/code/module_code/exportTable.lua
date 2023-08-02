module = {}

function module.fun1(self)
    return self.cont
end

module.cont = 1      -- 全局变量可以访问

module.method1 = function(obj, name)
    print(name)
end



local function func2()      -- 私有函数，外部不可访问
    return "this is local func2"
end

function module.func3()
    return func2()
end

return module