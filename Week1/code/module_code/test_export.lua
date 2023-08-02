-- package.path = package.path..";E:\\Workspace\\Learning Space\\lua space\\Learn-Note\\Week1\\code\\basic_code\\?.lua"
package.path = package.path..";?.lua"
require("Week1.code.module_code.exportTable")

x = module:fun1()
print(x)
print(module.func3())
module.method1(12, 22)
print(module.cont)