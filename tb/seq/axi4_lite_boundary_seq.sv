`ifndef AXI4_LITE_BOUNDARY_SEQ_SV
`define AXI4_LITE_BOUNDARY_SEQ_SV

//==============================================================================
// axi4_lite_boundary_seq.sv — 寄存器窗口边界
// 测试：axi4_lite_boundary_test
// 场景：最低字 0x0、最高合法字 0xC 写读（cp_addr_boundary low/high）
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_boundary_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_boundary_seq)

	function new(string name = "axi4_lite_boundary_seq");
		super.new(name);
	endfunction

	virtual task body();
		`uvm_info("SEQ", "Boundary address sequence starting...", UVM_LOW)

		// 最低边界地址
		write_word(32'h00000000, 32'hA0A0A0A0, 4'b1111);
		read_word(32'h00000000);

		// 最高合法地址（当前DUT窗口：0x00 ~ 0x0C）
		write_word(32'h0000000C, 32'h5A5A5A5A, 4'b1111);
		read_word(32'h0000000C);

		`uvm_info("SEQ", "Boundary address sequence finished!", UVM_LOW)
	endtask
endclass

`endif
