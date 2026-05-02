`ifndef AXI4_LITE_TRANS_SV
`define AXI4_LITE_TRANS_SV

//==============================================================================
// axi4_lite_trans.sv — AXI4-Lite 事务（sequence item）
// 功能：封装单次读/写所需的地址、数据、WSTRB 及响应字段，供 seq/driver/scb 传递。
// 分区：工厂注册 | 随机字段 | 响应字段 | 约束 | 打印
//==============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_lite_trans extends uvm_sequence_item;
    // -------------------------------------------------------------------------
    // UVM 工厂与字段自动化（供打印、拷贝、比较）
    // -------------------------------------------------------------------------
    `uvm_object_utils_begin(axi4_lite_trans)
        `uvm_field_int(addr,   UVM_ALL_ON)
        `uvm_field_int(wdata,  UVM_ALL_ON)
        `uvm_field_int(wstrb,  UVM_ALL_ON)
        `uvm_field_int(wr_rd,  UVM_ALL_ON)
        `uvm_field_int(rdata,  UVM_ALL_ON)
        `uvm_field_int(bresp,  UVM_ALL_ON)
        `uvm_field_int(rresp,  UVM_ALL_ON)
    `uvm_object_utils_end

    // -------------------------------------------------------------------------
    // 激励字段（由 sequence randomize 或 raw 赋值）
    // -------------------------------------------------------------------------
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    rand bit [3:0]  wstrb;
    rand bit        wr_rd;   // 1=写事务, 0=读事务

    // -------------------------------------------------------------------------
    // 响应字段（driver 在握手完成后回填）
    // -------------------------------------------------------------------------
    bit [31:0] rdata;
    bit [1:0]  bresp;  // 写通道响应（替换旧的resp）
    bit [1:0]  rresp;  // 读通道响应 RRESP

    // -------------------------------------------------------------------------
    // 约束：WSTRB 与读事务字段清理；默认 4 字节对齐（定向场景可用 raw 绕过）
    // -------------------------------------------------------------------------
    constraint c_wstrb_protocol {
        if (wr_rd == 1'b1) {
            // 写事务：WSTRB非全0，且1-4个字节有效
            wstrb != 4'b0000;
            $countones(wstrb) inside {1, 2, 3, 4};
        } else {
            // 读事务：写数据/选通清0（合并原rd_trans_clean约束）
            wdata == 32'h0;
            wstrb == 4'b0000;
        }
    }

    constraint addr_alignment {
        addr[1:0] == 2'b00;
    }

    function new(string name = "axi4_lite_trans");
        super.new(name);
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("addr",   addr,   32);
        printer.print_field("wr_rd",  wr_rd,  1);
        printer.print_field("wdata",  wdata,  32);
        printer.print_field("wstrb",  wstrb,  4);
        printer.print_field("rdata",  rdata,  32);
        printer.print_field("bresp",  bresp,  2);  // 写响应
        printer.print_field("rresp",  rresp,  2);  // 读响应
    endfunction

endclass
`endif
