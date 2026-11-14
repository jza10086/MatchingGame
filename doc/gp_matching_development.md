# M13 连连看　B　依赖 G01

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_matching_guide.md)


包：`gp_matching`。定位：[game.gd](../game.gd) 的 `handle_action()`、`_update_controls()`；`board_3d.gd`、`matching_piece.tscn`。

验证：主相机点选、洗牌后旧选择失效、提示次数与私有提示、两端争用同一对、远端游标和结算。

2026-11-07：本包三项完成，G01 公共依赖仍待单独迁移。MCP 脚本诊断、提示发送失败注入、1920×1080 单人及双端 ENet 自动检查通过：点选、洗牌失效、提示扣减与私密性、游标数据同步、争抢消除和 40 对结算。本轮未重新做视觉及真人联机验收。

## 人工验收待办

保留自 2026-11-05 场景审查，后续记录未明确关闭的人工事项：远端游标待人工验收。
