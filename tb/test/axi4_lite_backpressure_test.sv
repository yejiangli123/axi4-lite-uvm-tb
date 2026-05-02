`ifndef AXI4_LITE_BACKPRESSURE_TEST_SV
`define AXI4_LITE_BACKPRESSURE_TEST_SV

//==============================================================================
// axi4_lite_backpressure_test — B/R 通道随机 ready 延迟
// 配置：bready_delay_max / rready_delay_max → driver
// 启动序列：axi4_lite_backpressure_seq
//==============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi4_lite_base_test.sv"
`include "../seq/axi4_lite_backpressure_seq.sv"

class axi4_lite_backpressure_test extends axi4_lite_base_test;
	`uvm_component_utils(axi4_lite_backpressure_test)

	function new(string name = "axi4_lite_backpressure_test", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// 在响应通道插入随机backpressure，逼出握手保持与等待路径
		uvm_config_db#(int unsigned)::set(this, "env.agt.drv", "bready_delay_max", 6);
		uvm_config_db#(int unsigned)::set(this, "env.agt.drv", "rready_delay_max", 6);
	endfunction

	virtual task run_phase(uvm_phase phase);
		axi4_lite_backpressure_seq seq;
		`uvm_info("TEST", "Backpressure test starting...", UVM_LOW)
		phase.raise_objection(this, "Start axi4_lite_backpressure_seq");

		seq = axi4_lite_backpressure_seq::type_id::create("seq");
		seq.start(env.agt.sqr);

		phase.drop_objection(this, "Finish axi4_lite_backpressure_seq");
		`uvm_info("TEST", "Backpressure test finished!", UVM_LOW)
	endtask
endclass
`endif
