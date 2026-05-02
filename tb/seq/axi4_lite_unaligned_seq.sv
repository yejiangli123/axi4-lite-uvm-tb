`ifndef AXI4_LITE_UNALIGNED_SEQ_SV
`define AXI4_LITE_UNALIGNED_SEQ_SV

//==============================================================================
// axi4_lite_unaligned_seq.sv — 非对齐地址 DECERR
// 测试：axi4_lite_unaligned_test
// 场景：addr[1:0]!=0 的 raw 写/读；期望 DECERR（覆盖 cp_addr_boundary.unaligned）
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_unaligned_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_unaligned_seq)

	function new(string name = "axi4_lite_unaligned_seq");
		super.new(name);
	endfunction

	// 非对齐地址需绕过 addr_alignment 约束：以下均为 raw 事务
	virtual task send_raw_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("unaligned_wr_tr");
		start_item(tr);
		tr.wr_rd = 1'b1;
		tr.addr  = addr;
		tr.wdata = data;
		tr.wstrb = strb;
		finish_item(tr);
	endtask

	virtual task send_raw_read(bit [31:0] addr);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("unaligned_rd_tr");
		start_item(tr);
		tr.wr_rd = 1'b0;
		tr.addr  = addr;
		tr.wdata = 32'h0;
		tr.wstrb = 4'b0000;
		finish_item(tr);
	endtask

	virtual task body();
		`uvm_info("SEQ", "Unaligned address sequence starting...", UVM_LOW)

		// 非对齐写，期望DECERR
		send_raw_write(32'h0000_0001, 32'hDEAD_BEEF, 4'b1111);
		send_raw_write(32'h0000_0006, 32'hA5A5_5A5A, 4'b1111);

		// 非对齐读，期望DECERR
		send_raw_read(32'h0000_0003);
		send_raw_read(32'h0000_000B);

		`uvm_info("SEQ", "Unaligned address sequence finished!", UVM_LOW)
	endtask
endclass

`endif
