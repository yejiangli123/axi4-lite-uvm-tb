# =============================================================================
# axi4_lite UVM — Makefile
# 功能：VCS 编译/仿真、覆盖率（-cm）、smoke&回归、URG 合并、Verdi/波形、Python 报表。
# 常用：make comp && make sim TEST=axi4_lite_simple_test
#       make smoke  |  make cov_merge  |  make verdi
# =============================================================================

# ======================
# 配置项
# ======================
# Verdi 安装路径（DUMP_FSDB=1 编译 FSDB 时必须正确；与 sync_fifo 工程用法一致）
VERDI_HOME ?= /home/synopsys/verdi/Verdi_O-2018.09-SP2
# 仿真顶层模块名（Verdi 需要）
TOP_NAME   := top_tb
# FSDB 文件名（DUMP_FSDB=1）
FSDB_NAME  ?= waveform.fsdb

UVM_HOME = ${VCS_HOME}/etc/uvm
PROJ_HOME = .
RTL_DIR  = $(PROJ_HOME)/rtl
# DUT 源文件（仓库内为 .sv.txt；若在 VM 已改名为 axi4_lite_dut.sv：make RTL_DUT=axi4_lite_dut.sv comp）
RTL_DUT ?= axi4_lite_dut.sv
TB_DIR   = $(PROJ_HOME)/tb
PYTHON ?= python3
# 覆盖率 HTML 打开方式（任选其一）：
#   make cov_view_open                          → 默认 $(COV_BROWSER)
#   make cov_view_open COV_BROWSER=firefox      → 指定浏览器
#   make cov_view_path                          → 只打印路径与 file:// URL，拷到本机浏览器亦可
#   make cov_view_python                       → python3 -m webbrowser（部分环境免装桌面默认浏览器）
#   make cov_view_verdi / make cov_view_dve    → 商用 GUI 看 cov/（与 URG 网页不同）
COV_BROWSER ?= xdg-open
SIM_NAME = axi4_lite_uvm_sim
TEST ?= axi4_lite_simple_test
DUMP_FSDB ?= 0
COV_ENABLE ?= 1
# 覆盖率库目录：默认与 sync_fifo 一致为「可执行名.vdb」，落在工程根目录，避免 cov/$(TEST) 未创建导致 Verdi 找不到
# 若需按用例分目录：make comp COV_DIR=cov/$TEST （须与 sim 使用同一 COV_DIR）
COV_DIR ?= $(SIM_NAME).vdb
# 可选：手动指定 Verdi -covdir（留空则自动查找 $(COV_DIR)、cov/、工程根下 *.vdb）
COV_VERDI_VDB ?=
ASSERT_ENABLE ?= 1
SEED ?= 1
REPORT_DIR ?= reports
SMOKE_TESTS ?= axi4_lite_simple_test axi4_lite_wstrb_cov_test axi4_lite_boundary_test axi4_lite_error_resp_test axi4_lite_slverr_test axi4_lite_unaligned_test axi4_lite_backpressure_test
REGRESSION_TESTS ?= $(SMOKE_TESTS)
SEEDS ?= 1 7 11 23 37 59 83 101

ifeq ($(ASSERT_ENABLE),1)
ASSERT_DEFINE = +define+AXI4L_SVA_ON
else
ASSERT_DEFINE =
endif

ifeq ($(DUMP_FSDB),1)
  ifeq ($(strip $(VERDI_HOME)),)
    $(error DUMP_FSDB=1 需要设置 VERDI_HOME，例如: export VERDI_HOME=/path/to/Verdi_O-2018.09-SP2)
  endif
  # FSDB PLI（与 sync_fifo Makefile 相同路径层级）
  FSDB_PLI := -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
              $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
  WAVE_DEFINE = +define+DUMP_FSDB
  WAVE_FILE = $(FSDB_NAME)
  FSDB_SIM_OPTS = +fsdb+autoflush
else
  WAVE_DEFINE =
  WAVE_FILE = waveform.vcd
  FSDB_PLI =
  FSDB_SIM_OPTS =
endif

ifeq ($(COV_ENABLE),1)
# 不加 cond：否则 URG/Verdi 综合 Score 会被大量条件覆盖未闭合拉低，且与历史报表不可比
COV_COMP_OPTS = -cm line+tgl+branch+fsm -cm_dir $(COV_DIR)
COV_SIM_OPTS  = -cm line+tgl+branch+fsm -cm_dir $(COV_DIR)
else
COV_COMP_OPTS =
COV_SIM_OPTS  =
endif

# ======================
# 编译选项
# ======================
VCS_OPTS = -sverilog \
           -debug_acc+all \
           -debug_region+cell+encrypt \
           +incdir+$(UVM_HOME)/src \
           +incdir+$(TB_DIR)/common \
           +incdir+$(TB_DIR)/agent \
           +incdir+$(TB_DIR)/env \
           +incdir+$(TB_DIR)/seq \
           +incdir+$(TB_DIR)/test \
           -o $(SIM_NAME) \
           -l comp.log \
           $(FSDB_PLI)

# ======================
# Verdi 命令行（参考 sync_fifo：波形 + 覆盖率一次打开；-covdir 在 verdi 目标内自动解析 *.vdb）
# ======================
VERDI_OPTS_BASE := -sv -novc -f verdi.f -top $(TOP_NAME)
ifeq ($(DUMP_FSDB),1)
VERDI_OPTS_BASE += -ssf $(WAVE_FILE)
endif

# ======================
# 文件列表（timescale.v 必须在最前面）
# ======================
FILE_LIST = timescale.v \
            $(UVM_HOME)/src/uvm_pkg.sv \
            $(TB_DIR)/common/axi4_lite_if.sv \
            $(TB_DIR)/common/axi4_lite_pkg.sv \
            $(TB_DIR)/common/axi4_lite_trans.sv \
            $(TB_DIR)/agent/axi4_lite_sequencer.sv \
            $(TB_DIR)/agent/axi4_lite_driver.sv \
            $(TB_DIR)/agent/axi4_lite_monitor.sv \
            $(TB_DIR)/agent/axi4_lite_agent.sv \
            $(TB_DIR)/env/axi4_lite_scoreboard.sv \
            $(TB_DIR)/env/axi4_lite_env.sv \
            $(TB_DIR)/seq/axi4_lite_base_seq.sv \
            $(TB_DIR)/seq/axi4_lite_simple_rw_seq.sv \
            $(TB_DIR)/seq/axi4_lite_wstrb_cov_seq.sv \
            $(TB_DIR)/seq/axi4_lite_boundary_seq.sv \
            $(TB_DIR)/seq/axi4_lite_error_resp_seq.sv \
            $(TB_DIR)/seq/axi4_lite_slverr_seq.sv \
            $(TB_DIR)/seq/axi4_lite_unaligned_seq.sv \
            $(TB_DIR)/seq/axi4_lite_backpressure_seq.sv \
            $(TB_DIR)/test/axi4_lite_base_test.sv \
            $(TB_DIR)/test/axi4_lite_simple_test.sv \
            $(TB_DIR)/test/axi4_lite_wstrb_cov_test.sv \
            $(TB_DIR)/test/axi4_lite_boundary_test.sv \
            $(TB_DIR)/test/axi4_lite_error_resp_test.sv \
            $(TB_DIR)/test/axi4_lite_slverr_test.sv \
            $(TB_DIR)/test/axi4_lite_unaligned_test.sv \
            $(TB_DIR)/test/axi4_lite_backpressure_test.sv \
            $(RTL_DIR)/$(RTL_DUT) \
            $(TB_DIR)/top_tb.sv

# ======================
# 目标定义
# ======================
# 避免目录下存在名为 sim/wave/... 的文件时，make 误认为目标已是最新而不执行 recipe
.PHONY: all comp sim wave verdi verdi.f help cov_report cov_view cov_view_open cov_view_path cov_view_python \
        cov_view_test cov_view_verdi cov_view_dve \
        smoke regression trend trend_with_cov cov_merge closure_report report_closure clean

all: comp sim

comp:
	@mkdir -p "$(COV_DIR)"
	vcs $(VCS_OPTS) $(COV_COMP_OPTS) +define+UVM_NO_DPI $(WAVE_DEFINE) $(ASSERT_DEFINE) $(FILE_LIST)

sim:
	@mkdir -p "$(COV_DIR)"
	./$(SIM_NAME) $(COV_SIM_OPTS) $(FSDB_SIM_OPTS) +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_LOW -l sim.log

# 仅打开波形（老用法）；推荐与 sync_fifo 一致使用 make verdi
wave:
	verdi -ssf $(WAVE_FILE) &

# 生成 Verdi 用的 filelist（路径与 VCS FILE_LIST 一致）
verdi.f: Makefile
	@echo "# Generated for Verdi — do not edit" > $@
	@echo "+incdir+$(UVM_HOME)/src" >> $@
	@echo "+incdir+$(TB_DIR)/common" >> $@
	@echo "+incdir+$(TB_DIR)/agent" >> $@
	@echo "+incdir+$(TB_DIR)/env" >> $@
	@echo "+incdir+$(TB_DIR)/seq" >> $@
	@echo "+incdir+$(TB_DIR)/test" >> $@
	@for f in $(FILE_LIST); do echo $$f >> $@; done

# 与 sync_fifo 一致：Verdi 同时加载源码 +（可选）FSDB +（可选）覆盖率
verdi: verdi.f
	@if [ "$(COV_ENABLE)" = "1" ]; then \
	  vdb=""; \
	  if [ -n "$(strip $(COV_VERDI_VDB))" ] && [ -d "$(COV_VERDI_VDB)" ]; then \
	    vdb="$(COV_VERDI_VDB)"; \
	  elif [ -d "$(COV_DIR)" ]; then \
	    vdb=$$(find "$(COV_DIR)" -maxdepth 12 -type d -name '*.vdb' 2>/dev/null | head -1); \
	    if [ -z "$$vdb" ]; then vdb="$(COV_DIR)"; fi; \
	  fi; \
	  if [ -z "$$vdb" ] && [ -d cov ]; then \
	    vdb=$$(find cov -type d -name '*.vdb' 2>/dev/null | head -1); \
	  fi; \
	  if [ -z "$$vdb" ]; then \
	    for d in "./$(SIM_NAME).vdb" "./simv.vdb"; do [ -d "$$d" ] && vdb=$$d && break; done; \
	  fi; \
	  if [ -z "$$vdb" ]; then \
	    vdb=$$(find . -maxdepth 3 -type d -name '*.vdb' ! -path './reports/*' ! -path './csrc/*' 2>/dev/null | head -1); \
	  fi; \
	  if [ -z "$$vdb" ]; then \
	    echo "[Verdi] COV_ENABLE=1 但未找到覆盖率 *.vdb"; \
	    echo "        请先: make clean && make comp && make sim"; \
	    echo "        默认 -cm_dir=$(COV_DIR)；查找命令: find . -maxdepth 3 -type d -name '*.vdb'"; \
	    exit 1; \
	  fi; \
	  echo "[Verdi] $(VERDI_OPTS_BASE) -cov -covdir $$vdb"; \
	  verdi $(VERDI_OPTS_BASE) -cov -covdir $$vdb & \
	else \
	  echo "[Verdi] $(VERDI_OPTS_BASE)"; \
	  verdi $(VERDI_OPTS_BASE) & \
	fi

help:
	@echo "========================================================"
	@echo " AXI4-Lite UVM Makefile（VCS + 可选 Verdi 看波形/覆盖率）"
	@echo "========================================================"
	@echo "  make comp / sim / clean"
	@echo "  make sim TEST=xxx SEED=n"
	@echo ""
	@echo "  【与 sync_fifo 类似的 Verdi】"
	@echo "  make comp DUMP_FSDB=1 && make sim DUMP_FSDB=1   # 需正确 VERDI_HOME"
	@echo "  make verdi                                      # 源码 + FSDB(若开) + 覆盖率（默认库目录 $(COV_DIR)）"
	@echo "  可选: COV_VERDI_VDB=/path/to/xxx.vdb make verdi  # 手动指定覆盖率库"
	@echo ""
	@echo "  【URG 网页报表】make cov_merge / make cov_view_open"
	@echo "========================================================"

cov_report:
	urg -dir $(COV_DIR) -report cov_report_$(TEST)

# 合并 cov/ 下各用例 VDB，再用浏览器打开 URG 汇总页（常见路径：merged_urg/dashboard.html）
cov_view: cov_merge cov_view_open

# 仅打开已生成的合并报告（不重新跑 urg）；若无文件请先 make cov_merge
cov_view_open:
	@merged="$(REPORT_DIR)/coverage/merged_urg"; \
	html=""; \
	if [ -f "$$merged/dashboard.html" ]; then html="$$merged/dashboard.html"; \
	elif [ -f "$$merged/urgReport/dashboard.html" ]; then html="$$merged/urgReport/dashboard.html"; \
	fi; \
	if [ -z "$$html" ]; then \
		echo "[COV] 未找到 $$merged 下的 dashboard.html，请先执行 make cov_merge"; exit 1; \
	fi; \
	echo "[COV] 打开 $$html （浏览器：$(COV_BROWSER)）"; \
	$(COV_BROWSER) "$$html" >/dev/null 2>&1 & true

# 当前 TEST 对应单次仿真的 URG 报告 + 浏览器打开（需已 make sim 生成 $(COV_DIR)）
cov_view_test: cov_report
	@html=""; \
	if [ -f cov_report_$(TEST)/dashboard.html ]; then html=cov_report_$(TEST)/dashboard.html; \
	elif [ -f cov_report_$(TEST)/urgReport/dashboard.html ]; then html=cov_report_$(TEST)/urgReport/dashboard.html; \
	fi; \
	if [ -z "$$html" ]; then \
		echo "[COV] 未找到 cov_report_$(TEST) 下的 dashboard.html"; exit 1; \
	fi; \
	echo "[COV] 打开 $$html"; \
	$(COV_BROWSER) "$$html" >/dev/null 2>&1 & true

# 仅拉起 Verdi Coverage（无源码树）；平时更推荐 make verdi（与 sync_fifo 一致）
cov_view_verdi:
	@if [ "$(COV_ENABLE)" != "1" ]; then echo "[COV] 请使用 COV_ENABLE=1 编译并仿真"; exit 1; fi
	@vdb=""; \
	if [ -n "$(strip $(COV_VERDI_VDB))" ] && [ -d "$(COV_VERDI_VDB)" ]; then vdb="$(COV_VERDI_VDB)"; \
	elif [ -d "$(COV_DIR)" ]; then \
	  vdb=$$(find "$(COV_DIR)" -maxdepth 12 -type d -name '*.vdb' 2>/dev/null | head -1); \
	  if [ -z "$$vdb" ]; then vdb="$(COV_DIR)"; fi; \
	fi; \
	if [ -z "$$vdb" ] && [ -d cov ]; then vdb=$$(find cov -type d -name '*.vdb' 2>/dev/null | head -1); fi; \
	if [ -z "$$vdb" ]; then \
	  for d in "./$(SIM_NAME).vdb" "./simv.vdb"; do [ -d "$$d" ] && vdb=$$d && break; done; \
	fi; \
	if [ -z "$$vdb" ]; then vdb=$$(find . -maxdepth 3 -type d -name '*.vdb' ! -path './reports/*' ! -path './csrc/*' 2>/dev/null | head -1); fi; \
	if [ -z "$$vdb" ]; then echo "[COV] 未找到 *.vdb，请先 make comp && make sim"; exit 1; fi; \
	echo "[COV] Verdi -covdir $$vdb"; \
	verdi -cov -covdir $$vdb &

# Synopsys DVE 查看覆盖率（老环境常见；若无 dve 命令可跳过）
cov_view_dve:
	@if [ ! -d cov ]; then echo "[COV] cov 目录不存在"; exit 1; fi
	@echo "[COV] 启动 DVE Coverage，目录: cov"
	dve -cov -covdir cov &

# 不调用 xdg-open：只打印合并报告绝对路径与 file://，便于远程 VM 上手动开浏览器或拷到 Windows 打开
cov_view_path:
	@merged="$(REPORT_DIR)/coverage/merged_urg"; \
	html=""; \
	if [ -f "$$merged/dashboard.html" ]; then html="$$merged/dashboard.html"; \
	elif [ -f "$$merged/urgReport/dashboard.html" ]; then html="$$merged/urgReport/dashboard.html"; \
	fi; \
	if [ -z "$$html" ]; then echo "[COV] 未找到 dashboard.html，请先 make cov_merge"; exit 1; fi; \
	abs=$$(cd "$$(dirname "$$html")" && pwd)/$$(basename "$$html"); \
	echo "[COV] 合并报告本地路径:"; echo "    $$abs"; \
	echo "[COV] 任意浏览器地址栏可粘贴（Linux）:"; echo "    file://$$abs"; \
	echo "[COV] 或用 scp 把 merged_urg 拷到本机后双击 dashboard.html"

# 用 Python 自带模块打开默认浏览器（不依赖 xdg-open）
cov_view_python:
	@merged="$(REPORT_DIR)/coverage/merged_urg"; \
	html=""; \
	if [ -f "$$merged/dashboard.html" ]; then html="$$merged/dashboard.html"; \
	elif [ -f "$$merged/urgReport/dashboard.html" ]; then html="$$merged/urgReport/dashboard.html"; \
	fi; \
	if [ -z "$$html" ]; then echo "[COV] 请先 make cov_merge"; exit 1; fi; \
	abs=$$(cd "$$(dirname "$$html")" && pwd)/$$(basename "$$html"); \
	echo "[COV] webbrowser 打开 file://$$abs"; \
	$(PYTHON) -m webbrowser "file://$$abs"

smoke: comp
	mkdir -p $(REPORT_DIR)/smoke
	@echo "test,seed,status,uvm_error,uvm_fatal,scb_resp_err,scb_data_err,scb_pair_err,scb_corner_err,fcov_percent" > $(REPORT_DIR)/smoke/smoke_summary.csv
	@pass=0; total=0; \
	for t in $(SMOKE_TESTS); do \
		total=$$((total+1)); \
		log="$(REPORT_DIR)/smoke/$${t}.log"; \
		echo "[SMOKE] Running $$t"; \
		./$(SIM_NAME) $(COV_SIM_OPTS) +UVM_TESTNAME=$$t +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_LOW -l $$log; \
		err=$$(grep -E "UVM_ERROR\\s*:\\s*" $$log | tail -1 | awk '{print $$3}'); \
		fatal=$$(grep -E "UVM_FATAL\\s*:\\s*" $$log | tail -1 | awk '{print $$3}'); \
		resp_err=$$(grep -E "Response Mismatch Errors:" $$log | tail -1 | awk '{print $$5}'); \
		data_err=$$(grep -E "Read Data Mismatch Errors:" $$log | tail -1 | awk '{print $$6}'); \
		pair_err=$$(grep -E "Order/Pairing Errors" $$log | tail -1 | awk '{print $$4}'); \
		corner_err=$$(grep -E "Corner Case Errors" $$log | tail -1 | awk '{print $$5}'); \
		fcov=$$(grep -E "Functional Coverage" $$log | tail -1 | sed -E 's/.*: ([0-9\\.]+)%.*/\1/'); \
		err=$${err:-0}; fatal=$${fatal:-0}; resp_err=$${resp_err:-0}; data_err=$${data_err:-0}; pair_err=$${pair_err:-0}; corner_err=$${corner_err:-0}; fcov=$${fcov:-NA}; \
		if [ "$$err" = "0" ] && [ "$$fatal" = "0" ]; then status=PASS; pass=$$((pass+1)); else status=FAIL; fi; \
		echo "$$t,$(SEED),$$status,$$err,$$fatal,$$resp_err,$$data_err,$$pair_err,$$corner_err,$$fcov" >> $(REPORT_DIR)/smoke/smoke_summary.csv; \
	done; \
	rate=$$(awk "BEGIN { if ($$total==0) print 0; else printf \"%.2f\", ($$pass/$$total)*100 }"); \
	echo "[SMOKE] pass=$$pass/$$total ($$rate%)"; \
	echo "pass_rate,$$rate" > $(REPORT_DIR)/smoke/smoke_pass_rate.txt

regression: comp
	mkdir -p $(REPORT_DIR)/regression
	@echo "test,seed,status,uvm_error,uvm_fatal,scb_resp_err,scb_data_err,scb_pair_err,scb_corner_err,fcov_percent" > $(REPORT_DIR)/regression/regression_summary.csv
	@pass=0; total=0; \
	for t in $(REGRESSION_TESTS); do \
		for s in $(SEEDS); do \
			total=$$((total+1)); \
			log="$(REPORT_DIR)/regression/$${t}_seed$${s}.log"; \
			echo "[REG] Running $$t seed=$$s"; \
			./$(SIM_NAME) $(COV_SIM_OPTS) +UVM_TESTNAME=$$t +ntb_random_seed=$$s +UVM_VERBOSITY=UVM_LOW -l $$log; \
			err=$$(grep -E "UVM_ERROR\\s*:\\s*" $$log | tail -1 | awk '{print $$3}'); \
			fatal=$$(grep -E "UVM_FATAL\\s*:\\s*" $$log | tail -1 | awk '{print $$3}'); \
			resp_err=$$(grep -E "Response Mismatch Errors:" $$log | tail -1 | awk '{print $$5}'); \
			data_err=$$(grep -E "Read Data Mismatch Errors:" $$log | tail -1 | awk '{print $$6}'); \
			pair_err=$$(grep -E "Order/Pairing Errors" $$log | tail -1 | awk '{print $$4}'); \
			corner_err=$$(grep -E "Corner Case Errors" $$log | tail -1 | awk '{print $$5}'); \
			fcov=$$(grep -E "Functional Coverage" $$log | tail -1 | sed -E 's/.*: ([0-9\\.]+)%.*/\1/'); \
			err=$${err:-0}; fatal=$${fatal:-0}; resp_err=$${resp_err:-0}; data_err=$${data_err:-0}; pair_err=$${pair_err:-0}; corner_err=$${corner_err:-0}; fcov=$${fcov:-NA}; \
			if [ "$$err" = "0" ] && [ "$$fatal" = "0" ]; then status=PASS; pass=$$((pass+1)); else status=FAIL; fi; \
			echo "$$t,$$s,$$status,$$err,$$fatal,$$resp_err,$$data_err,$$pair_err,$$corner_err,$$fcov" >> $(REPORT_DIR)/regression/regression_summary.csv; \
		done; \
	done; \
	rate=$$(awk "BEGIN { if ($$total==0) print 0; else printf \"%.2f\", ($$pass/$$total)*100 }"); \
	echo "[REG] pass=$$pass/$$total ($$rate%)"; \
	echo "pass_rate,$$rate" > $(REPORT_DIR)/regression/regression_pass_rate.txt

# 依赖 smoke/regression 生成的 pass_rate 与 CSV；代码覆盖率列来自 merged URG（请先 make cov_merge）
trend:
	mkdir -p $(REPORT_DIR)
	$(PYTHON) tools/trend_snapshot.py --report-dir $(REPORT_DIR) --urg-report $(REPORT_DIR)/coverage/merged_urg

# 合并仿真覆盖率后再追加趋势行，使 trend.csv 含 line/toggle/branch/fsm 列
trend_with_cov: cov_merge trend

# 收集工程内 *.vdb（默认 $(SIM_NAME).vdb；或 cov/ 下多库），供 URG 合并
cov_merge:
	mkdir -p $(REPORT_DIR)/coverage
	@VDB_LIST=$$(find . \( -path ./reports -o -path ./csrc -o -path ./verdiLog \) -prune -o -type d -name '*.vdb' -print 2>/dev/null | sort -u); \
	if [ -z "$$VDB_LIST" ]; then \
		echo "[COV] 未找到任何 *.vdb。请先: make clean && make comp && make sim（COV_ENABLE=1）"; \
		echo "    默认覆盖率目录 COV_DIR=$(COV_DIR)"; \
		ls -la "$(COV_DIR)" 2>/dev/null || true; \
		exit 1; \
	fi; \
	N=$$(echo "$$VDB_LIST" | wc -l); \
	echo "[COV] 合并 $$N 个 VDB -> $(REPORT_DIR)/coverage/merged_urg"; \
	urg -dir $$(echo "$$VDB_LIST" | tr '\n' ' ') -report $(REPORT_DIR)/coverage/merged_urg

closure_report:
	mkdir -p $(REPORT_DIR)/coverage
	@if [ ! -f tools/gen_closure_report.py ]; then \
		echo "[COV] 缺少 tools/gen_closure_report.py"; \
		echo "    请将仓库中的 tools/gen_closure_report.py 拷到本工程: $(CURDIR)/tools/"; \
		echo "    （仅这一个文件即可，无需 coverage_metrics.py）"; \
		exit 1; \
	fi
	$(PYTHON) tools/gen_closure_report.py \
		--smoke $(REPORT_DIR)/smoke/smoke_summary.csv \
		--regression $(REPORT_DIR)/regression/regression_summary.csv \
		--urg-report $(REPORT_DIR)/coverage/merged_urg \
		--output $(REPORT_DIR)/coverage/closure_report.md

# 先生成合并 URG，再写闭环 Markdown（需已完成 smoke/regression 才有 CSV 内容）
report_closure: cov_merge closure_report

clean:
	rm -rf $(SIM_NAME) *.log *.vcd csrc ucli.key DVEfiles verdiLog *.fsdb *.vdb cov cov_report_* reports verdi.f
