`ifndef AXI4_LITE_BASE_SEQ_SV
`define AXI4_LITE_BASE_SEQ_SV

//==============================================================================
// axi4_lite_base_seq.sv — 定向序列基类
// 功能：封装 write_word / read_word（randomize 约束 addr/data），派生类实现 body()。
//==============================================================================

`include "uvm_macros.svh"
`include "../common/axi4_lite_trans.sv"

class axi4_lite_base_seq extends uvm_sequence #(axi4_lite_trans);
	`uvm_object_utils(axi4_lite_base_seq)

	function new(string name = "axi4_lite_base_seq");
		super.new(name);
	endfunction

	virtual task write_word(bit [31:0] addr, bit [31:0] data, bit [3:0] strb = 4'b1111);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("wr_tr");
		start_item(tr);
		assert(tr.randomize() with {
			tr.wr_rd == 1'b1;
			tr.addr  == local::addr;
			tr.wdata == local::data;
			tr.wstrb == local::strb;
		}) else `uvm_error("SEQ", "Write transaction randomization failed!")
		finish_item(tr);
	endtask

	virtual task read_word(bit [31:0] addr);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("rd_tr");
		start_item(tr);
		assert(tr.randomize() with {
			tr.wr_rd == 1'b0;
			tr.addr  == local::addr;
		}) else `uvm_error("SEQ", "Read transaction randomization failed!")
		finish_item(tr);
	endtask

	virtual task body();
	
	endtask

endclass
`endif
