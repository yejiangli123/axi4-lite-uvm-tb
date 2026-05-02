//==============================================================================
// top_tb.sv — 仿真顶层
// 功能：时钟/复位；例化 axi4_lite_if 与 axi4_lite_dut；config_db 下发 vif；run_test()；
//       可选 VCD 或 FSDB（DUMP_FSDB）波形。
// 分区：时钟复位 | DUT+IF 互联 | UVM 启动 | 波形 dump
//==============================================================================
`timescale 1ns/1ps

// UVM 库与工程包（pkg 内已按依赖顺序包含 agent/env/seq/test）
`include "uvm_pkg.sv"
`include "uvm_macros.svh"

// 先包含公共包和Interface
`include "tb/common/axi4_lite_pkg.sv"
`include "tb/common/axi4_lite_if.sv"

import uvm_pkg::*;

module top_tb;

  // ----- 时钟 / 复位 -----
  logic        aclk;
  logic        aresetn;  // AXI协议标准低电平复位

  // 100MHz（周期 10ns）
  initial begin
    aclk = 1'b0;
    forever #5 aclk = ~aclk;
  end

  // 复位：低有效，同步释放
  initial begin
    aresetn = 1'b0;
    repeat (2) @(posedge aclk);
    aresetn <= 1'b1;
  end

  // ----- AXI 验证接口 -----
  axi4_lite_if  axi_if (
    .aclk    (aclk),
    .aresetn  (aresetn)
  );

  // ----- DUT（端口与 interface 信号直连） -----
  axi4_lite_dut  u_dut (
    .aclk      (aclk),
    .aresetn    (aresetn),

    // 写地址通道
    .awaddr    (axi_if.awaddr),
    .awvalid   (axi_if.awvalid),
    .awready   (axi_if.awready),

    // 写数据通道
    .wdata     (axi_if.wdata),
    .wstrb     (axi_if.wstrb),
    .wvalid    (axi_if.wvalid),
    .wready    (axi_if.wready),

    // 写响应通道
    .bresp     (axi_if.bresp),
    .bvalid    (axi_if.bvalid),
    .bready    (axi_if.bready),

    // 读地址通道
    .araddr    (axi_if.araddr),
    .arvalid   (axi_if.arvalid),
    .arready   (axi_if.arready),

    // 读数据通道
    .rdata     (axi_if.rdata),
    .rresp     (axi_if.rresp),
    .rvalid    (axi_if.rvalid),
    .rready    (axi_if.rready)
  );

  // ----- UVM：vif → config_db；+UVM_TESTNAME 选择测试 -----
  initial begin
    // 把virtual interface放到uvm_config_db，所有UVM组件都能获取
    uvm_config_db#(virtual axi4_lite_if)::set(uvm_root::get(), "*", "vif", axi_if);

    // 启动 UVM：测试名由仿真命令行 +UVM_TESTNAME= 指定（见 Makefile 的 TEST）
    run_test();

    // 仿真结束打印
    $display("--------------------------------------");
    $display(" Simulation finished successfully! ");
    $display("--------------------------------------");
  end

  // ----- 波形（默认 VCD；Verdi 流水时用 DUMP_FSDB） -----
  initial begin
`ifdef DUMP_FSDB
    $fsdbDumpfile("waveform.fsdb");
    $fsdbDumpvars(0, top_tb);
`else
    $dumpfile("waveform.vcd");
    $dumpvars(0, top_tb); // 0=记录所有层级的所有信号，方便Debug
`endif
  end

endmodule
