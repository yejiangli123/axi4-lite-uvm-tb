`ifndef AXI4_LITE_AGENT_SV
`define AXI4_LITE_AGENT_SV

//==============================================================================
// axi4_lite_agent.sv — 单接口验证 agent（uvm_agent）
// 功能：ACTIVE 模式挂载 sqr+drv；PASSIVE 仅 monitor；统一导出 analysis_port 连 scoreboard。
// 分区：子组件句柄 | build（按 is_active 创建）| connect（drv←sqr，mon→ap）
//==============================================================================

`include "uvm_macros.svh"

`include "axi4_lite_sequencer.sv"
`include "axi4_lite_driver.sv"
`include "axi4_lite_monitor.sv"

class axi4_lite_agent extends uvm_agent;
	`uvm_component_utils(axi4_lite_agent)
	
	axi4_lite_sequencer sqr;
	axi4_lite_driver drv;
	axi4_lite_monitor mon;

	uvm_analysis_port#(axi4_lite_trans) ap;

	function new(string name = "axi4_lite_agent", uvm_component parent =  null);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon = axi4_lite_monitor::type_id::create("mon", this);
		if(get_is_active() == UVM_ACTIVE) begin
			sqr = axi4_lite_sequencer::type_id::create("sqr", this);
			drv = axi4_lite_driver::type_id::create("drv", this);
		end

		ap = new("ap",this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		if(get_is_active() == UVM_ACTIVE) begin
			drv.seq_item_port.connect(sqr.seq_item_export);
		end

		mon.ap.connect(this.ap);
	endfunction
endclass
`endif
