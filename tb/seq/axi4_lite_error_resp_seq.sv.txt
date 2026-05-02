`ifndef AXI4_LITE_ERROR_RESP_SEQ_SV
`define AXI4_LITE_ERROR_RESP_SEQ_SV

//==============================================================================
// axi4_lite_error_resp_seq.sv — 越界访问 DECERR
// 测试：axi4_lite_error_resp_test
// 场景：≥0x10 地址写读，期望 RRESP/BRESP=DECERR（与 ref 模型 DECERR 读数据约定一致）
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_error_resp_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_error_resp_seq)

	function new(string name = "axi4_lite_error_resp_seq");
		super.new(name);
	endfunction

	virtual task body();
		`uvm_info("SEQ", "Error response sequence starting...", UVM_LOW)

		// 越界访问：当前DUT应返回DECERR(2'b11)
		write_word(32'h00000010, 32'hDEAD_BEEF, 4'b1111);
		read_word(32'h00000010);

		// 再补一个更大越界地址
		write_word(32'h00000100, 32'h1234_5678, 4'b1111);
		read_word(32'h00000100);

		`uvm_info("SEQ", "Error response sequence finished!", UVM_LOW)
	endtask
endclass

`endif
