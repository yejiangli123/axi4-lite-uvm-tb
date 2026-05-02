# AXI4-Lite UVM 验证环境

基于 **SystemVerilog + UVM** 的 AXI4-Lite 从设备（寄存器窗口）验证平台，配套 **Synopsys VCS** 编译仿真、可选 **Verdi** 波形与覆盖率查看、**URG** 合并报表及 **Python** 辅助脚本。

> **说明**：本仓库仅包含 RTL/TB/脚本；**VCS / Verdi / 许可证需在本机自行安装**，无法在 GitHub 上提供。

---

## 功能概览

- **UVM 组件**：`driver` / `monitor` / `sequencer` / `agent`，`scoreboard` 内含参考寄存器模型与事务比对  
- **功能覆盖率**：Scoreboard 内 `covergroup`（WSTRB、响应类型、地址场景及交叉）  
- **接口断言**：`+define+AXI4L_SVA_ON`（Makefile 默认 `ASSERT_ENABLE=1`）时在 `axi4_lite_if` 中编译协议 SVA  
- **代码覆盖率**：`-cm line+tgl+branch+fsm`，默认写入 `$(SIM_NAME).vdb`（即 `axi4_lite_uvm_sim.vdb`）  
- **回归**：`make smoke` / `make regression`，支持 `SEED`、多 seed 列表  

---

## 目录结构

```
.
├── Makefile.txt          # 构建脚本（见下文「文件名」说明）
├── timescale.v.txt
├── rtl/
│   └── axi4_lite_dut.sv.txt    # DUT：4×32bit 寄存器 + AXI4-Lite 读写状态机
├── tb/
│   ├── top_tb.sv.txt           # 顶层：时钟/复位、DUT+IF、run_test
│   ├── common/                 # trans / if / pkg
│   ├── agent/
│   ├── env/
│   ├── seq/                    # 各定向 sequence
│   └── test/                   # UVM_TESTNAME 对应测试类
├── tools/                      # URG 解析、趋势 CSV、闭环 Markdown
├── doc/                        # VPlan / 覆盖率闭环说明（*.md.txt）
└── reports/                    # 运行产物示例（若存在）；大文件见 .gitignore
```

---

## 环境与依赖

| 项目 | 说明 |
|------|------|
| 仿真器 | Synopsys **VCS**（示例版本可与 Makefile 中路径一致） |
| `VCS_HOME` | 须指向 VCS 安装根目录；**UVM** 默认使用 `$VCS_HOME/etc/uvm` |
| 可选 | **Verdi**（`make verdi`、`DUMP_FSDB=1` 时需配置 `VERDI_HOME`） |
| Python | 3.x（`make trend` / `closure_report` 等使用 `PYTHON`，默认 `python3`） |

---

## 源文件命名（`.sv.txt` → `.sv`）

仓库中为 **`*.sv.txt` / `Makefile.txt`** 便于在 Windows 下编辑。在 Linux 仿真机上通常需二选一：

1. **重命名**为 `*.sv` 与 `Makefile`，并保证 `FILE_LIST` 与路径一致；或  
2. 保持文件名不变，将 Makefile 中路径改为实际文件名（当前 Makefile 写的是 `axi4_lite_dut.sv` 等无 `.txt` 后缀）。

若 DUT 已改名为 `axi4_lite_dut.sv`，可：

```bash
make comp RTL_DUT=axi4_lite_dut.sv
```

---

## 快速开始

```bash
export VCS_HOME=/path/to/vcs-mx/O-2018.09-1   # 按本机安装修改

make -f Makefile.txt comp    # 或使用已重命名的 Makefile: make comp
make -f Makefile.txt sim TEST=axi4_lite_simple_test SEED=1
```

常用目标（与 `make help` 一致）：

| 命令 | 作用 |
|------|------|
| `make comp` | VCS 编译，生成 `axi4_lite_uvm_sim` |
| `make sim` | 运行仿真；`TEST=` 指定 UVM 测试名；`SEED=` 控制随机种子 |
| `make smoke` | 依次运行预设 smoke 用例列表 |
| `make regression` | 回归用例（默认与 smoke 列表一致，可多 seed） |
| `make cov_merge` | 收集工程内 `*.vdb` 并由 URG 生成合并报告（默认 `reports/coverage/merged_urg`） |
| `make cov_view_open` | 在浏览器中打开 URG 汇总页（需先 `cov_merge`） |
| `make verdi` | 启动 Verdi（源码 + 可选 FSDB + 覆盖率目录自动解析） |
| `make clean` | 清理仿真产物、覆盖率库、常见 log 等 |

**波形**

- 默认 **VCD**：`waveform.vcd`  
- **FSDB**：`make comp DUMP_FSDB=1 && make sim DUMP_FSDB=1`，并设置正确的 `VERDI_HOME`  

**关闭断言编译**

```bash
make comp ASSERT_ENABLE=0
```

---

## 测试用例（`+UVM_TESTNAME=`）

与 `SMOKE_TESTS` 对应的部分测试名：

| 测试类 | 简要场景 |
|--------|-----------|
| `axi4_lite_simple_test` | 基础连续写后读回 |
| `axi4_lite_wstrb_cov_test` | WSTRB 字节使能覆盖 |
| `axi4_lite_boundary_test` | 最低/最高合法字地址 |
| `axi4_lite_error_resp_test` | 越界访问 DECERR |
| `axi4_lite_slverr_test` | 非法 WSTRB（如全 0）SLVERR |
| `axi4_lite_unaligned_test` | 非对齐地址 DECERR |
| `axi4_lite_backpressure_test` | B/R ready 随机延迟 |

示例：

```bash
make sim TEST=axi4_lite_backpressure_test
```

---

## 覆盖率与脚本（`tools/`）

- **`coverage_metrics.py`**：解析 URG `dashboard` 文本/HTML，抽取 line/toggle/branch/fsm 等  
- **`gen_closure_report.py`**：生成覆盖率闭环 Markdown（可单文件拷贝至其他环境）  
- **`trend_snapshot.py`**：向 `reports/trend.csv` 追加一行趋势（可与 `cov_merge`、回归通过率等联动）  

具体目标见 Makefile 中 `trend`、`trend_with_cov`、`report_closure` 等。

---

## 文档

- `doc/vplan_axi4_lite.md.txt`：验证计划与需求映射  
- `doc/coverage_closure.md.txt`：覆盖率目标与说明模板  

---

## 许可证

若仓库根目录包含 `LICENSE` 文件，以该文件为准；未添加前请勿假定默认可自由商用。

---

## 致谢 / 声明

UVM 来自 Synopsys VCS 附带发行版路径；工具链商标归各自厂商所有。本项目用于学习与简历展示时，请遵守校方或雇主对代码外传的合规要求。
