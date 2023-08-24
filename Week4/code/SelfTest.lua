table1 = {}

function table1:foo()
    print("foo")
end


function table1:test()
    print(self:foo())
end

print(table1)
print(table1:test())