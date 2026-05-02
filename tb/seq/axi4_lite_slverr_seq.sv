`ifndef AXI4_LITE_SLVERR_SEQ_SV
`define AXI4_LITE_SLVERR_SEQ_SV

//==============================================================================
// axi4_lite_slverr_seq.sv — 非法 WSTRB 写 → SLVERR
// 测试：axi4_lite_slverr_test
// 场景：WSTRB=0 的 raw 写（绕过随机约束）；期望 BRESP=SLVERR
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_slverr_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_slverr_seq)

	function new(string name = "axi4_lite_slverr_seq");
		super.new(name);
	endfunction

	// 定向写：不 randomize，用于 WSTRB=0 等违反 c_wstrb_protocol 的场景
	virtual task send_raw_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("slverr_wr_tr");
		start_item(tr);
		tr.wr_rd = 1'b1;
		tr.addr  = addr;
		tr.wdata = data;
		tr.wstrb = strb;
		finish_item(tr);
	endtask

	virtual task body();
		`uvm_info("SEQ", "SLVERR sequence starting...", UVM_LOW)

		// 合法地址 + 非法写选通，期望SLVERR
		send_raw_write(32'h0000_0000, 32'hFACE_CAFE, 4'b0000);
		send_raw_write(32'h0000_0004, 32'h1234_5678, 4'b0000);

		`uvm_info("SEQ", "SLVERR sequence finished!", UVM_LOW)
	endtask
endclass

`endif
