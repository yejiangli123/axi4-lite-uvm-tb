`ifndef AXI4_LITE_BACKPRESSURE_SEQ_SV
`define AXI4_LITE_BACKPRESSURE_SEQ_SV

//==============================================================================
// axi4_lite_backpressure_seq.sv — B/R ready 背压压力
// 测试：axi4_lite_backpressure_test（driver 配置 bready/rready 随机延迟）
// 场景：多轮 0x0~0xC 随机数据写后立即读，迫使 slave 侧握手等待路径反复触发
//==============================================================================

`include "uvm_macros.svh"
`include "axi4_lite_base_seq.sv"

class axi4_lite_backpressure_seq extends axi4_lite_base_seq;
	`uvm_object_utils(axi4_lite_backpressure_seq)

	function new(string name = "axi4_lite_backpressure_seq");
		super.new(name);
	endfunction

	virtual task body();
		int i;
		bit [31:0] wr_data;
		bit [31:0] addr_lane;
		`uvm_info("SEQ", "Backpressure stress sequence starting...", UVM_LOW)

		// 多轮读写，确保在B/R通道ready随机拉低时仍能稳定完成事务
		for(i = 0; i < 40; i++) begin
			wr_data = $urandom();
			addr_lane = ((i % 4) << 2);
			write_word(addr_lane, wr_data, 4'hF);
			read_word(addr_lane);
		end

		`uvm_info("SEQ", "Backpressure stress sequence finished!", UVM_LOW)
	endtask
endclass
`endif
