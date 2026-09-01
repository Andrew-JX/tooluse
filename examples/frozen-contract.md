# 冻结契约短样例

> 这是格式样例，不是现行任务规则，也不授予任何操作权限。仅在常驻块的三条件均满足、且用户已授权创建本地提交时使用。

```text
contract SHA：<获批判据提交>
baseline SHA：<实现起点>
candidate SHA：<实施完成后填写>
契约文件路径：contracts/<task>.md
产品正确性的外部锚点：外部规格 · <URL> §3.2（冻结类别与取证方式，实际运行证据由 executor 补）
允许改动文件 · 冻结阶段：contracts/<task>.md
允许改动文件 · 实现阶段：src/route.ts、test/route.test.ts

判据 1：机器 · 对 POST /orders 发真实 HTTP 请求，非法金额返回 422 与规定 error 结构。
  度量：<运行命令>；断言响应状态与 body；不以 service 单测代替。
  已知的假绿灯：service 单测通过，而路由没有注册错误映射。

判据 2：人工 · 验收者用键盘 Tab、Enter、Space 完成提交并观察 URL 与状态变化。
  度量：验收者、步骤、观察点。
  已知的假绿灯：只因使用原生 button 就声称键盘可用。

冲突检查：已通读，无冲突
限定词及运行时来源：该用户 = 认证中间件的 userId；最近 10 条 = SQL 的 ORDER BY + LIMIT 10
```

candidate 改契约即退回重新冻结；无法满足三条件时不启动三件套。
