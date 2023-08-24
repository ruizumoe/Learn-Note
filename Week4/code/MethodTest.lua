
function b(num)
    print("this is b", num)
end

a = function(num)
    return b(num)
end

print(a)

print(a(123))

table2 = {[1] = "call Sys method from Panel 05:14	",[2] = "TestNew Msg",[3] = 14,[4] = 0x561b4bbb06b0,}

cnt = select("#", table2)

