-- 被CS代码调用的Lua文件
a = 50
b = 'hello world'
c = true


d = {
    f1 = 10,
    f2 = 20,
    1,2,3,
    add = function(self, a, b)
        print("this is d.add call")
        return a + b
    end
}


function e()
    print('this is function e')
end

function f(a, b)
    print("this is global function f")
    print('a', a, 'b', b)
    return 1, {f1 = 1024}
end

function ret_e()
    print('ret_e called')
    return e
end

