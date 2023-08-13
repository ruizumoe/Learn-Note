using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using XLua;

namespace Script.CShrap.CSCallLua
{
    public class CSCallLua : MonoBehaviour
    {
        private LuaEnv _luaEnv;

        private void Start()
        {
            _luaEnv = new LuaEnv();
            _luaEnv.DoString("require 'requireFile.requireLuaFile'");
            _luaEnv.DoString("require 'CShrap.CSCallLua.CSCallLua'");
            // 1.获得基本元素
            // 值映射
            var a = _luaEnv.Global.Get<int>("a");
            var b = _luaEnv.Global.Get<string>("b");
            var c = _luaEnv.Global.Get<bool>("c");
            Debug.Log($"GlobalData a = {a}");
            Debug.Log($"GlobalData b = {b}");
            Debug.Log($"GlobalData c = {c}");

            // 2.将table映射到class
            // table的内容可以多余或少于class的内容
            // class为生成引用，而struct为值映射
            var D = _luaEnv.Global.Get<DClass>("d");
            Debug.Log($"class D info ::: {D.f1} :: {D.f2}");

            // 3.轻量级的值映射
            // 只获取其中的键值对
            // 值映射
            var dDict = _luaEnv.Global.Get<Dictionary<string, double>>("d");
            Debug.Log($"dict D info ::: {dDict["f1"]} :: {dDict["f2"]} :: {dDict.Count}");

            // 获得数组内容
            var dList = _luaEnv.Global.Get<List<int>>("d");
            Debug.Log($"list D info ::: {dList.Count}");

            // 4.基于代码生成的interface映射
            // 该方法将生成一个interface的实例，是个引用类型的,
            // 该interface上必须标注[CSharpCallLua]即将接口写入生成代码的列表，并手动生成代码
            var t2C = _luaEnv.Global.Get<ItableToClass>("d");
            t2C.f2 = 30123;
            // --> interface D info ::: 10 :: 30123 :: 92 ::: XLua.CSObjectWrap.ScriptCShrapCSCallLuaCSCallLuaItableToClassBridge
            Debug.Log($"interface D info ::: {t2C.f1} :: {t2C.f2} :: {t2C.add(33, 59)} ::: {t2C.GetType()}");
            
            
            // 5.将table映射到专门的LuaTable类中
            // 获取内部内容的方法，依旧是通过get<type>(key)的方式
            // by ref
            LuaTable lt = _luaEnv.Global.Get<LuaTable>("d");
            Debug.Log($"luaTable D info :::{lt.Get<int>("f1")}");
            
            
            // 6.获取全局function
            // 将方法映射到一个委托中，该方法需要标记[CSharpCallLua]，并生代码
            // delegate可以自己定义，如果自己定义，则每个function的参数需要对应到delegate的输入参数
            // 如果table的function有多个返回值，就需要从左往右映射到c#的输出参数，输出参数包括返回值，out参数，ref参数
            
            // 使用默认Action接受函数
            Action luaFunctionE = _luaEnv.Global.Get<Action>("e");
            luaFunctionE();
            
            
            // 自定义delegate接受function数据
            FDelegateFunction fFun = _luaEnv.Global.Get<FDelegateFunction>("f");
            DClass f_ret_class;
            int f_retNum = fFun(100, "Tom", out f_ret_class);
            Debug.Log($"f delegate info ::: {f_retNum}, {f_ret_class.f1} , {f_ret_class.f2}");
            // ==> f delegate info ::: 1, 1024 , 0  如果类的结果不匹配，则返回默认值
            
            
            // 返回值同样是一个delegate, 即返回了另一个function
            GetEFunction ret_e = _luaEnv.Global.Get<GetEFunction>("ret_e");
            Action e = ret_e();
            e();
            // ===> ret_e called
            // ===> this is function e
            
            // 7. 获取全局function，并用LuaFunction进行接受
            // 该方法性能更差, 需要手动去调用
            LuaFunction luaFunction_e = _luaEnv.Global.Get<LuaFunction>("e");
            luaFunction_e.Call();
            // ===> this is function e
        }   

        private void Update()
        {
            if (_luaEnv != null) _luaEnv.Tick();
        }

        private void OnDestroy()
        {
            _luaEnv.Dispose();
        }

        public class DClass
        {
            public int f1;
            public int f2;
        }

        [CSharpCallLua]
        public interface ItableToClass
        {
            int f1 { get; set; }
            int f2 { get; set; }
            int add(int a, int b);
        }
        
        // 使用Delegate接受function,
        // 由于有多返回值，因此第一位为输出结果，后续内容用out接收
        [CSharpCallLua]
        public delegate int FDelegateFunction(int a, string b, out DClass c);
        
        
        [CSharpCallLua]
        public delegate Action GetEFunction();
        
        
    }
}