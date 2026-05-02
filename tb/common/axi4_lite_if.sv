`ifndef AXI4_LITE_IF_SV
`define AXI4_LITE_IF_SV

//==============================================================================
// axi4_lite_if.sv — AXI4-Lite 验证接口 + 时钟块 + 可选 SVA
// 功能：汇集 AW/W/B 与 AR/R 信号；提供 drv_cb（驱动）、mon_cb（采样）；可选协议断言。
// 分区：信号 | master/slave modport | clocking blocks | AXI4L_SVA_ON 断言区
//==============================================================================

interface axi4_lite_if (
    input  logic        aclk,
    input  logic        aresetn
);

    // =========================================================================
    // AXI4-Lite 五通道信号（与 DUT 端口一一对应）
    // =========================================================================

    // 写地址通道 (AW)
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;

    // 写数据通道 (W)
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;

    // 写响应通道 (B)
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // 读地址通道 (AR)
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;

    // 读数据通道 (R)
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // =========================================================================
    // modport：TB 侧作 master 驱动/采样；DUT 侧在 top_tb 中直连 wire
    // =========================================================================

    // Master Modport
    modport master (
        input  aclk, aresetn,
        output awaddr, awvalid,
        input  awready,
        output wdata, wstrb, wvalid,
        input  wready,
        input  bresp, bvalid,
        output bready,
        output araddr, arvalid,
        input  arready,
        input  rdata, rresp, rvalid,
        output rready
    );

    // Slave Modport
    modport slave (
        input  aclk, aresetn,
        input  awaddr, awvalid,
        output awready,
        input  wdata, wstrb, wvalid,
        output wready,
        output bresp, bvalid,
        input  bready,
        input  araddr, arvalid,
        output arready,
        output rdata, rresp, rvalid,
        input  rready
    );

    // =========================================================================
    // clocking block：消除 TB/DUT 竞态；driver 用 drv_cb，monitor 用 mon_cb
    // =========================================================================

    // Driver 时钟块
    clocking drv_cb @(posedge aclk);
        default input #1step output #0;
        output awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready;
        input  awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid;
    endclocking

    // Monitor 时钟块
    clocking mon_cb @(posedge aclk);
        default input #1step output #0;
        input  awaddr, awvalid, awready, wdata, wstrb, wvalid, wready, bresp, bvalid, bready, araddr, arvalid, arready, rdata, rresp, rvalid, rready;
    endclocking

`ifdef AXI4L_SVA_ON
    // -------------------------------------------------------------------------
    // 协议断言：VALID/READY 保持、稳定、outstanding 计数、单事务在途
    // 编译：Makefile 默认 +define+AXI4L_SVA_ON；关闭 ASSERT_ENABLE=0
    // -------------------------------------------------------------------------
    int unsigned wr_outstanding;
    int unsigned rd_outstanding;

    always @(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin
            wr_outstanding <= 0;
            rd_outstanding <= 0;
        end
        else begin
            if(awvalid && awready && wvalid && wready) begin
                wr_outstanding <= wr_outstanding + 1;
            end
            if(bvalid && bready && (wr_outstanding > 0)) begin
                wr_outstanding <= wr_outstanding - 1;
            end

            if(arvalid && arready) begin
                rd_outstanding <= rd_outstanding + 1;
            end
            if(rvalid && rready && (rd_outstanding > 0)) begin
                rd_outstanding <= rd_outstanding - 1;
            end
        end
    end

    property p_aw_stable_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> (awvalid && $stable(awaddr));
    endproperty
    a_aw_stable_until_ready: assert property(p_aw_stable_until_ready)
        else $error("AXI4L_SVA: AW channel changed before handshake");

    property p_w_stable_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> (wvalid && $stable(wdata) && $stable(wstrb));
    endproperty
    a_w_stable_until_ready: assert property(p_w_stable_until_ready)
        else $error("AXI4L_SVA: W channel changed before handshake");

    property p_ar_stable_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> (arvalid && $stable(araddr));
    endproperty
    a_ar_stable_until_ready: assert property(p_ar_stable_until_ready)
        else $error("AXI4L_SVA: AR channel changed before handshake");

    property p_b_stable_until_accept;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> (bvalid && $stable(bresp));
    endproperty
    a_b_stable_until_accept: assert property(p_b_stable_until_accept)
        else $error("AXI4L_SVA: B channel changed before acceptance");

    property p_r_stable_until_accept;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> (rvalid && $stable(rdata) && $stable(rresp));
    endproperty
    a_r_stable_until_accept: assert property(p_r_stable_until_accept)
        else $error("AXI4L_SVA: R channel changed before acceptance");

    // VALID 在握手完成前须保持（AXI handshaking 规则）
    property p_awvalid_hold_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid;
    endproperty
    a_awvalid_hold_until_ready: assert property(p_awvalid_hold_until_ready)
        else $error("AXI4L_SVA: AWVALID dropped before AW handshake");

    property p_wvalid_hold_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid;
    endproperty
    a_wvalid_hold_until_ready: assert property(p_wvalid_hold_until_ready)
        else $error("AXI4L_SVA: WVALID dropped before W handshake");

    property p_arvalid_hold_until_ready;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid;
    endproperty
    a_arvalid_hold_until_ready: assert property(p_arvalid_hold_until_ready)
        else $error("AXI4L_SVA: ARVALID dropped before AR handshake");

    property p_bvalid_hold_until_accept;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid;
    endproperty
    a_bvalid_hold_until_accept: assert property(p_bvalid_hold_until_accept)
        else $error("AXI4L_SVA: BVALID dropped before B handshake");

    property p_rvalid_hold_until_accept;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid;
    endproperty
    a_rvalid_hold_until_accept: assert property(p_rvalid_hold_until_accept)
        else $error("AXI4L_SVA: RVALID dropped before R handshake");

    property p_b_has_outstanding_write;
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> (wr_outstanding > 0);
    endproperty
    a_b_has_outstanding_write: assert property(p_b_has_outstanding_write)
        else $error("AXI4L_SVA: BVALID without outstanding write request");

    property p_r_has_outstanding_read;
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> (rd_outstanding > 0);
    endproperty
    a_r_has_outstanding_read: assert property(p_r_has_outstanding_read)
        else $error("AXI4L_SVA: RVALID without outstanding read request");

    property p_single_outstanding_write;
        @(posedge aclk) disable iff (!aresetn)
        wr_outstanding <= 1;
    endproperty
    a_single_outstanding_write: assert property(p_single_outstanding_write)
        else $error("AXI4L_SVA: More than one outstanding write in AXI4-Lite");

    property p_single_outstanding_read;
        @(posedge aclk) disable iff (!aresetn)
        rd_outstanding <= 1;
    endproperty
    a_single_outstanding_read: assert property(p_single_outstanding_read)
        else $error("AXI4L_SVA: More than one outstanding read in AXI4-Lite");
`endif

endinterface
`endif
