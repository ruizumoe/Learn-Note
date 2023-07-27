local metatable_call_origin = { 10 }
local new_call_table = { 10, 20, 30 }
local call_mt = {
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
