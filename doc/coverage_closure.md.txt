# AXI4-Lite Coverage Closure 目标与缺口说明

## 1) 覆盖率目标

- Functional Coverage 总体目标：>= 95%
- Code Coverage 目标：
  - Line >= 95%
  - Toggle >= 90%
  - Branch >= 90%
  - FSM >= 95%

## 2) Functional Coverage 维度

- WSTRB 分类（写事务）
  - 1-byte / 2-byte / 3-byte / 4-byte
  - illegal `WSTRB=0`
- 响应类型（写/读）
  - `OKAY(2'b00)` / `SLVERR(2'b10)` / `DECERR(2'b11)`
- 地址场景
  - 低边界 `0x0000_0000`
  - 高边界 `0x0000_000C`（当前DUT窗口）
  - 越界地址 `>=0x0000_0010`
  - 非对齐地址（`addr[1:0]!=0`）
- 交叉覆盖
  - `WSTRB` 分类 x 地址边界（写事务）

## 3) 当前已实现

- 在 `axi4_lite_scoreboard` 中实现 transaction 级 covergroup，并在每笔事务采样
- 在 interface 中启用关键 SVA（AW/W/B/AR/R 稳定性、请求-响应配对、outstanding<=1）
- 已有场景测试：
  - `axi4_lite_wstrb_cov_test`
  - `axi4_lite_boundary_test`
  - `axi4_lite_error_resp_test`
  - `axi4_lite_slverr_test`
  - `axi4_lite_unaligned_test`
  - `axi4_lite_backpressure_test`
- Makefile 已支持 code coverage 编译/运行与 `urg` 报告

## 4) 已闭环项说明（本轮）

- `SLVERR` 路径已打通：
  - DUT 新增 `wstrb==0` 返回 `SLVERR`
  - 通过 `axi4_lite_slverr_test` 命中覆盖
- 非对齐地址路径已打通：
  - DUT 对非对齐访问返回 `DECERR`
  - 通过 `axi4_lite_unaligned_test` 命中覆盖

## 5) 闭环动作（下一步）

- 下一步建议：
  - 扩展更多 `SLVERR` 触发源（如写只读寄存器）
  - 增加更大地址空间下的随机非对齐覆盖
  - 对 `backpressure + error response` 组合场景进行随机交叉激励
- 每次回归执行：
  - `make smoke`
  - `make regression`
  - `make trend`
  - `make cov_merge`
  - `make closure_report`

