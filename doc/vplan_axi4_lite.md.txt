# AXI4-Lite 验证计划（VPlan）

## 1. 文档目的

本计划用于建立“需求 -> 测试点 -> 覆盖点 -> 结果”闭环，作为回归评审与项目交付依据。

## 2. 范围说明

- DUT：`axi4_lite_dut`
- 协议范围：AXI4-Lite 单次读写（非 burst）
- 当前验证平台：UVM（driver/monitor/scoreboard + directed sequences）

## 3. 映射矩阵（需求 -> 测试点 -> 覆盖点 -> 结果）

| ID | 需求（Requirement） | 测试点（Test Item） | 主要测试用例 | 覆盖点（Coverage Item） | 当前结果 | 备注/后续动作 |
|---|---|---|---|---|---|---|
| RQ-001 | 基础写读功能正确 | 合法地址写入后读回一致 | `axi4_lite_simple_test` | `cp_wr_rd`、读数据一致性检查 | 已实现 | 持续回归 |
| RQ-002 | WSTRB 字节写有效 | 1/2/3/4 字节写组合 | `axi4_lite_wstrb_cov_test` | `cp_wstrb_kind`（one/two/three/four bytes） | 已实现 | 关注交叉覆盖完整性 |
| RQ-003 | 非法 WSTRB 检查 | `WSTRB=0` 非法写路径 | （待补）`axi4_lite_wstrb_illegal_test` | `cp_wstrb_kind.illegal_zero`、响应类型覆盖 | 部分实现 | DUT/seq 需打开该路径 |
| RQ-004 | 响应类型 OKAY | 合法访问返回 OKAY | `simple`/`wstrb_cov`/`boundary` | `cp_resp_write.okay`、`cp_resp_read.okay` | 已实现 | 持续回归 |
| RQ-005 | 响应类型 DECERR | 越界地址访问返回 DECERR | `axi4_lite_error_resp_test` | `cp_resp_write.decerr`、`cp_resp_read.decerr`、`cp_addr_boundary.out_of_range` | 已实现 | 已形成稳定场景 |
| RQ-006 | 响应类型 SLVERR | 非法写事务返回 SLVERR | `axi4_lite_slverr_test` | `cp_resp_write.slverr` | 已实现 | 当前通过 `wstrb=0` 场景触发 |
| RQ-007 | 地址边界合法性 | 最低地址与最高合法地址访问 | `axi4_lite_boundary_test` | `cp_addr_boundary.low_boundary` / `high_boundary` | 已实现 | 持续回归 |
| RQ-008 | 非对齐地址错误处理 | `addr[1:0] != 0` 错误响应 | `axi4_lite_unaligned_test` | `cp_addr_boundary.unaligned_addr` + `DECERR` 响应覆盖 | 已实现 | 使用 raw transaction 方式生成非对齐访问 |
| RQ-009 | 参考模型一致性 | 写后镜像更新，读回比对 | 全部读写类测试 | scoreboard `ref_reg_file` + `rdata` mismatch计数 | 已实现 | 建议扩展更多随机场景 |
| RQ-010 | 稳定回归可交付 | 一键编译/仿真/覆盖报告 | Makefile `comp/sim/cov_report` | code coverage: line/tgl/branch/FSM | 已实现 | 需形成周期性回归报表 |
| RQ-011 | 响应通道背压鲁棒性 | `BREADY/RREADY` 随机拉低 | `axi4_lite_backpressure_test` | 回归通过率 + scoreboard 零错误 | 已实现 | driver 可配置 `bready_delay_max/rready_delay_max` |
| RQ-012 | 握手时序断言闭环 | AW/W/B/AR/R 稳定性与配对性 | 全测试（`+define+AXI4L_SVA_ON`） | 接口 SVA 断言 0 error | 已实现 | 增加 outstanding/配对断言 |

## 4. 覆盖率目标（Exit Criteria）

- Functional Coverage：>= 95%
- Code Coverage：
  - Line >= 95%
  - Toggle >= 90%
  - Branch >= 90%
  - FSM >= 95%
- 质量门禁：
  - `UVM_ERROR == 0`
  - `UVM_FATAL == 0`
  - Scoreboard final status = PASS

## 5. 未覆盖项解释模板（回归报告使用）

每次回归对未达标覆盖点按以下模板说明：

- 覆盖点：`<name>`
- 当前值：`<xx%/未命中>`
- 原因：`<DUT未实现/约束限制/场景未生成>`
- 风险评估：`<低/中/高>`
- 计划动作：`<补DUT/补sequence/补test>`
- 预计完成版本：`<date or milestone>`

## 6. 执行与更新流程

1. 运行回归：
   - `make smoke`
   - `make regression`
2. 生成趋势与闭环报告：
   - `make trend`（包含 timestamp + git commit）
   - `make cov_merge`
   - `make closure_report`
3. 更新映射矩阵“当前结果”列（已实现/部分实现/未闭环）。
4. 对未闭环项创建 action list 并追踪至关闭。

