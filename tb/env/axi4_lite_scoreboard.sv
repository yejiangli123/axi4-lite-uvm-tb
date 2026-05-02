`ifndef AXI4_LITE_SCOREBOARD_SV
`define AXI4_LITE_SCOREBOARD_SV

//==============================================================================
// axi4_lite_scoreboard.sv — 参考模型 + 检查 + 功能覆盖率
// 功能：维护 ref_reg_file 与 DUT 一致；比对 BRESP/RRESP/RDATA；covergroup 采样事务维度。
// 分区：成员与统计 | covergroup | 期望响应/辅助函数 | write() 入口 | report_phase
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_trans.sv"

class axi4_lite_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(axi4_lite_scoreboard)

	uvm_analysis_imp #(axi4_lite_trans,axi4_lite_scoreboard) ap;

	// ----- 参考寄存器（合法窗口 4×32b，索引 addr[3:2]） -----
	bit [31:0] ref_reg_file [0:3];
	localparam bit [1:0] RESP_OKAY   = 2'b00;
	localparam bit [1:0] RESP_SLVERR = 2'b10;
	localparam bit [1:0] RESP_DECERR = 2'b11;

	int unsigned total_trans = 0;
	int unsigned write_trans = 0;
	int unsigned read_trans  = 0;
	int unsigned resp_mismatch_errors = 0;
	int unsigned rdata_mismatch_errors = 0;
	int unsigned order_pair_errors = 0;
	int unsigned corner_case_errors = 0;
	int unsigned total_errors = 0;
	int unsigned checker_warnings = 0;
	bit checker_strict = 1'b1;

	// ----- 功能覆盖率：WSTRB / 响应 / 地址场景及交叉 -----
	covergroup cg_axi4_lite_trans with function sample(
		bit wr_rd,
		bit [3:0]  wstrb,
		bit [1:0]  bresp,
		bit [1:0]  rresp,
		bit [31:0] addr
	);
		option.per_instance = 1;

		cp_wr_rd: coverpoint wr_rd {
			bins write = {1'b1};
			bins read  = {1'b0};
		}

		cp_wstrb_kind: coverpoint wstrb iff (wr_rd == 1'b1) {
			bins one_byte[]  = {4'b0001,4'b0010,4'b0100,4'b1000};
			bins two_bytes[] = {4'b0011,4'b0101,4'b0110,4'b1001,4'b1010,4'b1100};
			bins three_bytes[] = {4'b0111,4'b1011,4'b1101,4'b1110};
			bins four_bytes  = {4'b1111};
			bins illegal_zero = {4'b0000};
		}

		cp_resp_write: coverpoint bresp iff (wr_rd == 1'b1) {
			bins okay   = {RESP_OKAY};
			bins slverr = {RESP_SLVERR};
			bins decerr = {RESP_DECERR};
		}

		cp_resp_read: coverpoint rresp iff (wr_rd == 1'b0) {
			bins okay   = {RESP_OKAY};
			bins slverr = {RESP_SLVERR};
			bins decerr = {RESP_DECERR};
		}

		cp_addr_boundary: coverpoint addr {
			bins low_boundary   = {32'h0000_0000};
			bins high_boundary  = {32'h0000_000C};
			bins out_of_range   = {[32'h0000_0010:32'h0000_01FF]};
			// 显式枚举非对齐地址，避免部分编译器对 with/item 切片支持不一致
			bins unaligned_addr[] = {
				32'h0000_0001, 32'h0000_0002, 32'h0000_0003,
				32'h0000_0005, 32'h0000_0006, 32'h0000_0007,
				32'h0000_0009, 32'h0000_000A, 32'h0000_000B,
				32'h0000_000D, 32'h0000_000E, 32'h0000_000F
			};
		}

		cross_wstrb_boundary: cross cp_wstrb_kind, cp_addr_boundary iff (wr_rd == 1'b1);
	endgroup

	function new(string name = "axi4_lite_scoreboard", uvm_component parent = null);
		super.new(name,parent);
		cg_axi4_lite_trans = new();
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		ap = new("ap", this);
		void'(uvm_config_db#(bit)::get(this, "", "checker_strict", checker_strict));
		`uvm_info("SCOREBOARD", $sformatf("Checker policy: %s", checker_strict ? "STRICT" : "LENIENT"), UVM_LOW)
	endfunction

	virtual function void start_of_simulation_phase(uvm_phase phase);
		super.start_of_simulation_phase(phase);
		foreach(ref_reg_file[i]) begin
			ref_reg_file[i] = 32'h0;
		end
	endfunction

	// ----- 地址与响应期望（与 DUT RTL 行为对齐） -----
	function automatic bit is_addr_aligned(bit [31:0] addr);
		return (addr[1:0] == 2'b00);
	endfunction

	function automatic bit is_addr_in_range(bit [31:0] addr);
		return (addr[3:2] < 4);
	endfunction

	// 预留钩子：后续如果定义只读寄存器，可在这里映射返回1
	function automatic bit is_write_to_read_only(bit [31:0] addr);
		return 1'b0;
	endfunction

	function automatic bit [1:0] expected_resp(axi4_lite_trans tr);
		if(!is_addr_aligned(tr.addr)) begin
			return RESP_DECERR;
		end

		if(!is_addr_in_range(tr.addr)) begin
			return RESP_DECERR;
		end

		if((tr.wr_rd == 1'b1) && (tr.wstrb == 4'b0000)) begin
			return RESP_SLVERR;
		end

		if((tr.wr_rd == 1'b1) && is_write_to_read_only(tr.addr)) begin
			return RESP_SLVERR;
		end

		return RESP_OKAY;
	endfunction

	function automatic bit [31:0] apply_wstrb_mask(
		bit [31:0] old_data,
		bit [31:0] new_data,
		bit [3:0]  wstrb
	);
		bit [31:0] merged;
		merged = old_data;
		if(wstrb[0]) merged[7:0]   = new_data[7:0];
		if(wstrb[1]) merged[15:8]  = new_data[15:8];
		if(wstrb[2]) merged[23:16] = new_data[23:16];
		if(wstrb[3]) merged[31:24] = new_data[31:24];
		return merged;
	endfunction

	// ----- 严格/宽松模式下累计告警或报错 -----
	function void checker_issue(string issue_id, string msg, ref int unsigned counter);
		counter++;
		if(checker_strict) begin
			`uvm_error(issue_id, msg)
		end
		else begin
			checker_warnings++;
			`uvm_warning(issue_id, msg)
		end
	endfunction

	// ----- analysis_imp 回调：每笔事务更新模型或比对读数据 -----
	function void write(axi4_lite_trans tr);
		bit [1:0] expected;
		bit [31:0] expected_rdata;
		bit [31:0] old_ref_data;
		int unsigned addr_idx;

		`uvm_info("SCOREBOARD",$sformatf("Received transaction: %s",tr.sprint()),UVM_HIGH)
		expected = expected_resp(tr);
		cg_axi4_lite_trans.sample(tr.wr_rd, tr.wstrb, tr.bresp, tr.rresp, tr.addr);

		total_trans++;
		if(tr.wr_rd == 1'b1)begin
			write_trans++;
			addr_idx = tr.addr[3:2];
			if(is_addr_in_range(tr.addr)) begin
				old_ref_data = ref_reg_file[addr_idx];
			end
			if(tr.rresp != 2'b00) begin
				checker_issue("SCB_PAIR",
					$sformatf("Malformed WRITE transaction: rresp should be 0, got 0x%0h (addr=0x%0h)", tr.rresp, tr.addr),
					order_pair_errors);
			end
			`uvm_info("SCOREBOARD",$sformatf("Observed WRITE transaction: addr=0x%0h, wdata=0x%0h, bresp=0x%0h", tr.addr, tr.wdata, tr.bresp), UVM_LOW)

			if(tr.bresp != expected) begin
				checker_issue("SCB_RESP", $sformatf("Write response mismatch! bresp=0x%0h (expected 0x%0h), addr=0x%0h", tr.bresp, expected, tr.addr), resp_mismatch_errors);
			end

			// 仅在预期成功时更新参考模型
			if(expected == RESP_OKAY) begin
				ref_reg_file[addr_idx] = apply_wstrb_mask(ref_reg_file[addr_idx], tr.wdata, tr.wstrb);
			end
			else begin
				// 失败写事务不应修改参考模型（corner case一致性检查）
				if(is_addr_in_range(tr.addr) && (ref_reg_file[addr_idx] != old_ref_data)) begin
					checker_issue("SCB_CORNER",
						$sformatf("Failed WRITE unexpectedly changed ref model at addr=0x%0h old=0x%08h new=0x%08h",
							tr.addr, old_ref_data, ref_reg_file[addr_idx]),
						corner_case_errors);
				end
			end
		end
		else begin
			read_trans++;
			addr_idx = tr.addr[3:2];
			if((tr.wstrb != 4'b0000) || (tr.wdata != 32'h0)) begin
				checker_issue("SCB_PAIR",
					$sformatf("Malformed READ transaction: wdata/wstrb should be 0, got wdata=0x%08h wstrb=0x%0h (addr=0x%0h)", tr.wdata, tr.wstrb, tr.addr),
					order_pair_errors);
			end
			if(tr.bresp != 2'b00) begin
				checker_issue("SCB_PAIR",
					$sformatf("Malformed READ transaction: bresp should be 0, got 0x%0h (addr=0x%0h)", tr.bresp, tr.addr),
					order_pair_errors);
			end
			`uvm_info("SCOREBOARD", $sformatf("Observed READ  transaction: addr=0x%0h, rdata=0x%0h, rresp=0x%0h", tr.addr, tr.rdata, tr.rresp), UVM_LOW)

			if(tr.rresp != expected) begin
				checker_issue("SCB_RESP", $sformatf("Read response mismatch! rresp=0x%0h (expected 0x%0h), addr=0x%0h", tr.rresp, expected, tr.addr), resp_mismatch_errors);
			end

			if(expected == RESP_OKAY) begin
				expected_rdata = ref_reg_file[addr_idx];
				if(tr.rdata != expected_rdata) begin
					checker_issue("SCB_DATA", $sformatf("Read data mismatch! addr=0x%0h, rdata=0x%08h (expected 0x%08h)", tr.addr, tr.rdata, expected_rdata), rdata_mismatch_errors);
				end
			end
			else if((expected == RESP_DECERR) && (tr.rresp == RESP_DECERR) && checker_strict) begin
				// corner case：当前DUT DECERR 读默认返回0，严格模式下检查
				if(tr.rdata != 32'h0) begin
					checker_issue("SCB_CORNER",
						$sformatf("DECERR READ should return zero data in current DUT model. addr=0x%0h rdata=0x%08h", tr.addr, tr.rdata),
						corner_case_errors);
				end
			end
		end
	endfunction

	// ----- 仿真结束汇总统计与 PASS/FAIL -----
	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		total_errors = resp_mismatch_errors + rdata_mismatch_errors + order_pair_errors + corner_case_errors;
		 `uvm_info("SCOREBOARD", $sformatf("Scoreboard Report:"), UVM_LOW)
       	 `uvm_info("SCOREBOARD", $sformatf("  Total Transactions: %0d", total_trans), UVM_LOW)
       	 `uvm_info("SCOREBOARD", $sformatf("  Write Transactions: %0d", write_trans), UVM_LOW)
       	 `uvm_info("SCOREBOARD", $sformatf("  Read  Transactions: %0d", read_trans), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Response Mismatch Errors: %0d", resp_mismatch_errors), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Read Data Mismatch Errors: %0d", rdata_mismatch_errors), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Order/Pairing Errors     : %0d", order_pair_errors), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Corner Case Errors       : %0d", corner_case_errors), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Checker Warnings         : %0d", checker_warnings), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Total Scoreboard Errors : %0d", total_errors), UVM_LOW)
      	 `uvm_info("SCOREBOARD", $sformatf("  Functional Coverage      : %0.2f%%", cg_axi4_lite_trans.get_inst_coverage()), UVM_LOW)

		if((total_errors == 0) || (!checker_strict)) begin
			`uvm_info("SCOREBOARD", "SCOREBOARD FINAL STATUS: PASS", UVM_NONE)
		end
		else begin
			`uvm_error("SCOREBOARD", $sformatf("SCOREBOARD FINAL STATUS: FAIL (total_errors=%0d)", total_errors))
		end
    endfunction

endclass
`endif
