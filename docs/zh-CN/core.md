# 运行时核心

[English](../core.md) · [Bahasa Indonesia](../id/core.md) · [简体中文](core.md)

Feybrume 可使用 Roblox 服务，也可接收自定义宿主。核心模块负责清理资源、分发信号、执行可取消任务，以及发布经过校验的状态。

## 在 Studio 中安装

在仓库根目录运行 `rojo serve`，并连接 Studio 的 Rojo 插件。项目将 `src` 映射到 `ReplicatedStorage.Feybrume`。手动安装时，用 `src/init.luau` 创建名为 `Feybrume` 的 ModuleScript，在其下建立 `core` 和 `engine` 文件夹，再按文件名将两组模块放入对应文件夹。

在 StarterPlayerScripts 中加入以下 LocalScript 并运行。

```luau
local storage = game:GetService("ReplicatedStorage")
local Fey = require(storage:WaitForChild("Feybrume"))
local runtime = Fey.Runtime.Create()
local store = runtime:CreateStore({ opened = false })

runtime.Scope:Give(store:Observe({ "opened" }, function(state, change)
    print(state.opened, change.revision)
end))

assert(store:Set("opened", true, "user").ok)
assert(runtime:GetCapabilities()["host.client"].state == "available")

local job = runtime:Spawn(function()
    return "ready"
end)
local result = job:Await(5)
assert(result.ok and result.value == "ready")

runtime:Dispose()
assert(runtime.Scope:GetCounts().resources == 0)
```

预期输出为 `true 1`，任务完成后资源计数为 0。可在桌面 Studio、设备模拟器和获准的手机测试体验中重复检查。Studio 与真机测试尚未执行，自动化测试使用 Luau CLI 和可控的测试宿主。

| 模块 | 用途 |
|---|---|
| Runtime、Services | 创建运行时和资源作用域，缓存服务查询，探测 Studio、客户端和服务器能力 |
| Janitor、Signal | 按登记顺序逆向清理资源，分发事件，也可等待事件或超时 |
| Promise、Clock、Throttle | 启动可取消任务、安排定时回调和控制回调频率 |
| Result、Error、Logger | 返回结构化结果，过滤诊断信息并写入有容量上限的日志 |
| Schema、Store、Computed | 校验数据，原子提交批量修改，并按依赖关系更新计算值 |
| Flags、Serializer | 管理命名空间内的标记，按版本序列化和迁移数据 |

事务、校验器、事件监听器和清理函数须同步执行。任务可以让出执行权，并通过取消令牌检查状态或注册清理函数。状态接受有限数值和树形数据。保存 Color3 等数据时请先转为普通数据结构。序列化时应明确列出允许保存的字段。

[完整 API 表（英文）](../core.md#api) · [核心测试记录](../../evidence/phase1-checks.json)
