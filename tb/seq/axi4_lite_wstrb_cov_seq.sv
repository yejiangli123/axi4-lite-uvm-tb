`ifndef AXI4_LITE_WSTRB_COV_SEQ_SV
`define AXI4_LITE_WSTRB_COV_SEQ_SV

//==============================================================================
// axi4_lite_wstrb_cov_seq.sv — WSTRB 字节使能覆盖
// 测试：axi4_lite_wstrb_cov_test
// 场景：1/2/3/4 字节写组合 + 读回，命中 cp_wstrb_kind 各 bins
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_wstrb_cov_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_wstrb_cov_seq)

	function new(string name = "axi4_lite_wstrb_cov_seq");
		super.new(name);
	endfunction

	virtual task body();
		`uvm_info("SEQ", "WSTRB coverage sequence starting...", UVM_LOW)

		// 4-byte write
		write_word(32'h00000000, 32'h11223344, 4'b1111);
		read_word(32'h00000000);

		// 1-byte writes
		write_word(32'h00000004, 32'h000000AA, 4'b0001);
		write_word(32'h00000004, 32'h0000BB00, 4'b0010);
		write_word(32'h00000004, 32'h00CC0000, 4'b0100);
		write_word(32'h00000004, 32'hDD000000, 4'b1000);
		read_word(32'h00000004);

		// 2-byte writes
		write_word(32'h00000008, 32'h00001234, 4'b0011);
		write_word(32'h00000008, 32'h56780000, 4'b1100);
		read_word(32'h00000008);

		// 3-byte writes
		write_word(32'h0000000C, 32'h00ABCDEF, 4'b0111);
		write_word(32'h0000000C, 32'h12345600, 4'b1110);
		read_word(32'h0000000C);

		`uvm_info("SEQ", "WSTRB coverage sequence finished!", UVM_LOW)
	endtask
endclass

`endif
