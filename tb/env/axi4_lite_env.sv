`ifndef AXI4_LITE_ENV_SV
`define AXI4_LITE_ENV_SV

//==============================================================================
// axi4_lite_env.sv — 验证环境顶层（uvm_env）
// 功能：例化 agent + scoreboard；connect_phase 将 monitor 事务送入 scoreboard。
// 扩展：可在 apply_default_config() 集中下发 is_active、checker_strict 等。
//==============================================================================

`include "uvm_macros.svh"
`include "../agent/axi4_lite_agent.sv"
`include "axi4_lite_scoreboard.sv"

class axi4_lite_env extends uvm_env;
	`uvm_component_utils(axi4_lite_env)

	axi4_lite_agent agt;
	axi4_lite_scoreboard scb;

	function new(string name = "axi4_lite_env", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	// 预留配置钩子：后续可在此集中下发agent/scb配置
	// 例如：
	// uvm_config_db#(uvm_active_passive_enum)::set(this, "agt", "is_active", UVM_PASSIVE);
	// uvm_config_db#(int)::set(this, "scb", "some_cfg", 1);
	virtual function void apply_default_config();
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		apply_default_config();
		agt = axi4_lite_agent::type_id::create("agt", this);
		scb = axi4_lite_scoreboard::type_id::create("scb", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.ap.connect(scb.ap);
	endfunction

endclass
`endif
