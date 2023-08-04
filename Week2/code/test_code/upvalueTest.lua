function Create(n)
    local function foo1()
        print(n)
    end
    local function foo2()
        n = n + 10
    end
    return foo1, foo2
end

f1, f2 = Create(2015)
f1() -- 打印2015

f2()
f1() -- 打印2025

f2()
f1() -- 打印2035
