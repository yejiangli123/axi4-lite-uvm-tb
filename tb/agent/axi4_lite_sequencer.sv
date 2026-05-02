`ifndef AXI4_LITE_SEQUENCER_SV
`define AXI4_LITE_SEQUENCER_SV

//==============================================================================
// axi4_lite_sequencer.sv — 事务调度器（uvm_sequencer）
// 功能：在 driver 与 sequence 之间仲裁 axi4_lite_trans；无额外逻辑时可保持薄封装。
//==============================================================================

`include "uvm_macros.svh"
`include "../common/axi4_lite_trans.sv"

class axi4_lite_sequencer extends uvm_sequencer #(axi4_lite_trans);
	`uvm_component_utils(axi4_lite_sequencer)

	function new(string name = "axi4_lite_sequencer",uvm_component parent=null);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

endclass
`endif
