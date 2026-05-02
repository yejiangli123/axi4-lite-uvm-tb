`ifndef AXI4_LITE_SLVERR_TEST_SV
`define AXI4_LITE_SLVERR_TEST_SV

//==============================================================================
// axi4_lite_slverr_test — WSTRB=0 写 → SLVERR
// 启动序列：axi4_lite_slverr_seq
//==============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi4_lite_base_test.sv"
`include "../seq/axi4_lite_slverr_seq.sv"

class axi4_lite_slverr_test extends axi4_lite_base_test;
	`uvm_component_utils(axi4_lite_slverr_test)

	function new(string name = "axi4_lite_slverr_test", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual task run_phase(uvm_phase phase);
		axi4_lite_slverr_seq seq;
		`uvm_info("TEST", "SLVERR test starting...", UVM_LOW)
		phase.raise_objection(this, "Start axi4_lite_slverr_seq");

		seq = axi4_lite_slverr_seq::type_id::create("seq");
		seq.start(env.agt.sqr);

		phase.drop_objection(this, "Finish axi4_lite_slverr_seq");
		`uvm_info("TEST", "SLVERR test finished!", UVM_LOW)
	endtask
endclass

`endif
