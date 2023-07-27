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