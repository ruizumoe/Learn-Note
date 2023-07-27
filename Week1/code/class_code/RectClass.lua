Rectangle = {area = 0, length = 0, breath = 0}

function Rectangle:new (origin, length, breadth)
    origin = origin or {}
    setmetatable(origin, self)
    self.__index = self
    origin.length = length or 0
    origin.breadth = breadth or 0
    origin.area = origin.length * origin.breadth;
    return origin
end

function Rectangle:showArea()
    return self.area
end

r = Rectangle:new(nil,60,20)
r2 = Rectangle:new(nil,40,50)

---- 继承 ----
ChildClass = Rectangle:new()        -- 子类

function ChildClass:new(obj, para1, para2)
    obj = obj or Rectangle:new(nil, para1, para2)
    -- 将ChildClass类作为其对象Obj的元表，能够访问成员函数
    setmetatable(obj, self)
    self.__index = self
    return obj
end

child1 = ChildClass:new(nil, 20, 40)
print(child1:showArea())



