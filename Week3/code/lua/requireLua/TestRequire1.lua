local testRequire1Table = {}

print("this is testRequire1.lua")

function testRequire1Table:setA(num)
    self.a = num;
end 

function testRequire1Table:getA()
    return self.a
end 

return testRequire1Table