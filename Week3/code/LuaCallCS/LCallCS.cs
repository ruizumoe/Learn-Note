using System;
using XLua;
using UnityEngine;

namespace Script.LuaCallCS
{
    // 基础类
    [LuaCallCSharp]
    public class BaseClass
    {
        public int BaseNorBaseMemPro { get; set; }
        
        public static int BaseClsProp = -1; 
        
        public static void BaseClsStaticFunc()
        {
            Debug.Log("Derived Base Static Func = " + BaseClsProp);
        }

        public void BaseClsMemFunc()
        {
            Debug.Log("Derived Base Member Func = " + BaseNorBaseMemPro);
        }
    }

    public struct Param1
    {
        public int x;
        public string y;
    }

    [LuaCallCSharp()]
    public enum TestEnum
    {
        E1, E2
    }
    
    // 子类
    [LuaCallCSharp]
    public class DerivedClass: BaseClass
    {
        public int DerivedMemVar { get; set; }
        
        [LuaCallCSharp]
        public enum DerivedInnerEnum
        {
            E3, E4
        }

        public void DerivedMemFunc()
        {
            Debug.Log("Derived Member Func = " + DerivedMemVar);
        }

        public double ComplexFunc(Param1 p1, ref int p2, out string s3, Action luaFunc, out Action csfunc)
        {
            Debug.Log("P1 = { x = " + p1.x + "; y = " + p1.y + "} , p2 = " + p2);
            luaFunc();
            p2 *= p1.x;
            s3 = "hello world" + p2;

            csfunc = () =>
            {
                Debug.Log("cs code callback invoked!");
            };

            return 292.123d;
        }
        
        // 测试重载方法
        public void TestOverloadFunc(int i)
        {
            Debug.Log($"TestFunc(int i) {i}");
        }

        public void TestOverloadFunc(string i)
        {
            Debug.Log($"TestFunc(string i) {i}");
        }

        public static DerivedClass operator +(DerivedClass a, DerivedClass b)
        {
            DerivedClass ret = new DerivedClass();
            ret.DerivedMemVar = a.DerivedMemVar + b.DerivedMemVar;
            return ret;
        }

        public void DefaultValueFunc(int a = 100, string b = "abc", string c = null)
        {
            Debug.Log($"now DefaultVal is {a}, {b}, {c}");
        }

        // 注意可变参数需要在参数前加 param标识
        public void VariableParamsFunc(int a, params string[] args)
        {
            string ret = "VariableParamsFunc: a =" + a;
            foreach (var arg in args)
            {
                ret += arg + ", ";
            }
            Debug.Log(ret);
        }
        
        public void GenericMethod<T>()
        {
            Debug.Log("GenericMethod<" + typeof(T) + ">");
        }


        public TestEnum EnumTestFunc(TestEnum e)
        {
            Debug.Log($"EnumTestFunc: e = {e}");
            return TestEnum.E2;
        }
        
        // 注册委托
        // 在Lua代码中可以当属性一样调用，并通过操作符 + - 来添加对应的方法，来增加函数调用
        // 该delegate默认有一个匿名函数调用
        public Action<string> TestDelegate = (param) =>
        {
            Debug.Log("TestDelegate in C#" + param);
        };
        
        
        // 注册事件
        public event Action TestEvent;

        public void CallTestEvent()
        {
            TestEvent?.Invoke();
        }

        public ulong TestLong(long n)
        {
            return (ulong)(n + 1);
        }
        
        
        // 实现接口
        class InnerCalc : ICalc
        {
            public int id = 100;
            public int add(int a, int b)
            {
                return a + b;
            }
        }

        public ICalc GetCalc()
        {
            return new InnerCalc();
        }

    }

    [LuaCallCSharp]
    public interface ICalc
    {
        int add(int a, int b);
    }

    // 对类的拓展方法
    [LuaCallCSharp]
    public static class DerivedClsExtensions
    {
        public static int GetObjData(this DerivedClass obj)
        {
            Debug.Log("GetObjData ret" + obj.DerivedMemVar);
            return obj.DerivedMemVar;
        }

        public static int GetObjBaseData(this DerivedClass obj)
        {
            Debug.Log("GetObjBaseData ret" + obj.BaseNorBaseMemPro);
            return obj.BaseNorBaseMemPro;
        }
        
        public static void GenericMethodOfString(this DerivedClass obj)
        {
            obj.GenericMethod<string>();
        }
    }
    
    
    
    
    // 编写给Lua代码调用的数据结构
    public class LCallCS: MonoBehaviour
    {
        private LuaEnv _luaEnv;

        
        
        
        
        

         private void Start()
         {
             _luaEnv = new LuaEnv();
             _luaEnv.DoString("require 'requireFile.requireLuaFile'");
             _luaEnv.DoString("require 'LuaCallCS.LCallCS'");
         }

         private void Update()
         {
             if (_luaEnv != null)
                 _luaEnv.Tick();
         }

         private void OnDestroy()
         {
             _luaEnv.Dispose();
         }
    }
}