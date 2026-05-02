`ifndef AXI4_LITE_DRIVER_SV
`define AXI4_LITE_DRIVER_SV

//==============================================================================
// axi4_lite_driver.sv — AXI4-Lite Master BFM（uvm_driver）
// 功能：将 axi4_lite_trans 驱动到接口；完成写(AW+W→B) / 读(AR→R)；支持 B/R ready 随机延迟。
// 分区：参数与配置 | build/run | 初始化 | 单事务驱动 | 背压注入
//==============================================================================

`include "uvm_macros.svh"

`include "axi4_lite_trans.sv"

class axi4_lite_driver extends uvm_driver #(axi4_lite_trans);
	`uvm_component_utils(axi4_lite_driver)

	// ----- 虚接口与超时、背压配置（config_db 可覆盖 ready 延迟上限） -----
	virtual axi4_lite_if vif;
	localparam int unsigned HANDSHAKE_TIMEOUT_CYCLES = 200;
	localparam int unsigned POST_RESET_WAIT_CYCLES   = 5;
	int unsigned bready_delay_max;
	int unsigned rready_delay_max;

	function new(string name = "axi4_lite_driver",uvm_component parent = null);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual axi4_lite_if)::get(this,"","vif",vif))begin
			`uvm_fatal("DRV","Failed to get virtual interface from config DB!")
		end
		bready_delay_max = 0;
		rready_delay_max = 0;
		void'(uvm_config_db#(int unsigned)::get(this, "", "bready_delay_max", bready_delay_max));
		void'(uvm_config_db#(int unsigned)::get(this, "", "rready_delay_max", rready_delay_max));
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);

		init_signals();

		wait(vif.aresetn == 1'b1);
		repeat(POST_RESET_WAIT_CYCLES) @(vif.drv_cb);
		`uvm_info("DRV","Reset released,AXI4_Lite driver start working!",UVM_LOW)
		`uvm_info("DRV", $sformatf("Backpressure config: bready_delay_max=%0d, rready_delay_max=%0d",
			bready_delay_max, rready_delay_max), UVM_LOW)

		forever begin
			seq_item_port.get_next_item(req);
			drive_one_transfer(req);
			seq_item_port.item_done();
		end
	endtask

	// ----- 空闲态默认驱动：valid 拉低，避免未知态 -----
	virtual task init_signals();
		@(vif.drv_cb);
		vif.drv_cb.awaddr <= 32'h0;
		vif.drv_cb.wdata  <= 32'h0;
		vif.drv_cb.wstrb  <= 4'h0;
		vif.drv_cb.araddr <= 32'h0;

		vif.drv_cb.awvalid <= 1'b0;
		vif.drv_cb.wvalid  <= 1'b0;
		vif.drv_cb.arvalid <= 1'b0;

		vif.drv_cb.bready  <= 1'b0;
		vif.drv_cb.rready  <= 1'b0;
	endtask

	// ----- 单事务：写分支 AW/W 同拍握手 → B；读分支 AR → R -----
	virtual task drive_one_transfer(axi4_lite_trans tr);
		int unsigned timeout_cnt;
		@(vif.drv_cb);

		if(tr.wr_rd == 1'b1)begin
			vif.drv_cb.awaddr <= tr.addr;
			vif.drv_cb.wdata <= tr.wdata;
			vif.drv_cb.wstrb <= tr.wstrb;
			// DUT 当前实现要求 AW/W 同时有效，这里同拍发起并等待双握手
			vif.drv_cb.awvalid <= 1'b1;
			vif.drv_cb.wvalid <= 1'b1;

			timeout_cnt = 0;
			while(!(vif.drv_cb.awready == 1'b1 && vif.drv_cb.wready == 1'b1)) begin
				@(vif.drv_cb);
				timeout_cnt++;
				if(timeout_cnt >= HANDSHAKE_TIMEOUT_CYCLES) begin
					`uvm_fatal("DRV_TIMEOUT",
						$sformatf("Timeout waiting AW/W handshake. awvalid=%0b wvalid=%0b awready=%0b wready=%0b addr=0x%08h",
							vif.awvalid, vif.wvalid, vif.awready, vif.wready, tr.addr))
				end
			end

			vif.drv_cb.awvalid <= 1'b0;
			vif.drv_cb.wvalid <= 1'b0;

			inject_bready_backpressure();
			vif.drv_cb.bready <= 1'b1;
			timeout_cnt = 0;
			while(vif.drv_cb.bvalid != 1'b1) begin
				@(vif.drv_cb);
				timeout_cnt++;
				if(timeout_cnt >= HANDSHAKE_TIMEOUT_CYCLES) begin
					`uvm_fatal("DRV_TIMEOUT",
						$sformatf("Timeout waiting B channel valid. bready=%0b addr=0x%08h",
							vif.bready, tr.addr))
				end
			end
			tr.bresp = vif.drv_cb.bresp;
			vif.drv_cb.bready <= 1'b0;
		end
		else begin
			vif.drv_cb.araddr <= tr.addr;
			vif.drv_cb.arvalid <= 1'b1;
			timeout_cnt = 0;
			while(vif.drv_cb.arready != 1'b1) begin
				@(vif.drv_cb);
				timeout_cnt++;
				if(timeout_cnt >= HANDSHAKE_TIMEOUT_CYCLES) begin
					`uvm_fatal("DRV_TIMEOUT",
						$sformatf("Timeout waiting AR handshake. arvalid=%0b arready=%0b addr=0x%08h",
							vif.arvalid, vif.arready, tr.addr))
				end
			end
			vif.drv_cb.arvalid <= 1'b0;

			inject_rready_backpressure();
			vif.drv_cb.rready <= 1'b1;
			timeout_cnt = 0;
			while(vif.drv_cb.rvalid != 1'b1) begin
				@(vif.drv_cb);
				timeout_cnt++;
				if(timeout_cnt >= HANDSHAKE_TIMEOUT_CYCLES) begin
					`uvm_fatal("DRV_TIMEOUT",
						$sformatf("Timeout waiting R channel valid. rready=%0b addr=0x%08h",
							vif.rready, tr.addr))
				end
			end
			tr.rdata = vif.drv_cb.rdata;
			tr.rresp = vif.drv_cb.rresp;
			vif.drv_cb.rready <= 1'b0;
		end
		@(vif.drv_cb);
	endtask

	// ----- 模拟 slave 晚拉 ready：在拉高 bready/rready 前随机等待若干周期 -----
	virtual task inject_bready_backpressure();
		int unsigned delay_cycles;
		delay_cycles = (bready_delay_max == 0) ? 0 : $urandom_range(0, bready_delay_max);
		repeat(delay_cycles) @(vif.drv_cb);
	endtask

	virtual task inject_rready_backpressure();
		int unsigned delay_cycles;
		delay_cycles = (rready_delay_max == 0) ? 0 : $urandom_range(0, rready_delay_max);
		repeat(delay_cycles) @(vif.drv_cb);
	endtask
endclass
`endif
