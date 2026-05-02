`ifndef AXI4_LITE_SIMPLE_RW_SEQ_SV
`define AXI4_LITE_SIMPLE_RW_SEQ_SV

//==============================================================================
// axi4_lite_simple_rw_seq.sv — 冒烟：连续写后读回
// 测试：axi4_lite_simple_test
// 场景：0x0/0x4/0x8 全字写 → 同地址读回比对（覆盖 OKAY 主路径）
//==============================================================================

`include "uvm_macros.svh"

`include "axi4_lite_base_seq.sv"

class axi4_lite_simple_rw_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_simple_rw_seq)

	function new(string name = "axi4_lite_simple_rw_seq");
		super.new(name);
	endfunction

	// 与 base_seq 等价实现：约束块写法兼容部分仿真器（可直接改用 base 任务）
	virtual task write_word(bit [31:0] addr, bit [31:0] data, bit [3:0] strb = 4'b1111);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("wr_tr");
		start_item(tr);
		assert(tr.randomize() with{
			tr.wr_rd == 1'b1;
			tr.addr  == local::addr;
			tr.wdata == local::data;
			tr.wstrb == local::strb;
		})
		else `uvm_error("SEQ", "Write transaction randomization failed!")
		finish_item(tr);
	endtask

	virtual task read_word(bit [31:0] addr);
		axi4_lite_trans tr;
		tr = axi4_lite_trans::type_id::create("rd_tr");
		start_item(tr);
		assert(tr.randomize() with{
			tr.wr_rd == 1'b0;
			tr.addr  == local::addr;
		})
		else `uvm_error("SEQ", "Read transaction randomization failed!")
		finish_item(tr);
	endtask

	virtual task body();
		`uvm_info("SEQ", "Simple Read/Write Sequence starting...", UVM_LOW)

		`uvm_info("SEQ", "Writing 3 transactions...", UVM_LOW)
		write_word(32'h00000000, 32'h12345678, 4'b1111);
		write_word(32'h00000004, 32'h87654321, 4'b1111);
		write_word(32'h00000008, 32'hAA55AA55, 4'b1111);

		`uvm_info("SEQ", "Reading 3 transactions back...", UVM_LOW)
		read_word(32'h00000000);
		read_word(32'h00000004);
		read_word(32'h00000008);

		`uvm_info("SEQ", "Simple Read/Write Sequence finished!", UVM_LOW)
	endtask
endclass
`endif
