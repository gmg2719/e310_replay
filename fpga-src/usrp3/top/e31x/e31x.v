/////////////////////////////////////////////////////////////////////
//
// Copyright 2018 Ettus Research, A National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: e31x
// Description:
//   E31x Top Level
//
/////////////////////////////////////////////////////////////////////

module e31x (

  // PS Connections
  inout [53:0]  MIO,
  input         PS_SRSTB,
  input         PS_CLK,
  input         PS_PORB,
  inout         DDR_CLK,
  inout         DDR_CLK_N,
  inout         DDR_CKE,
  inout         DDR_CS_N,
  inout         DDR_RAS_N,
  inout         DDR_CAS_N,
  inout         DDR_WEB,
  inout [2:0]   DDR_BANKADDR,
  inout [14:0]  DDR_ADDR,
  inout         DDR_ODT,
  inout         DDR_DRSTB,
  inout [31:0]  DDR_DQ,
  inout [3:0]   DDR_DM,
  inout [3:0]   DDR_DQS,
  inout [3:0]   DDR_DQS_N,
  inout         DDR_VRP,
  inout         DDR_VRN,

  // PL DDR
  input         sys_clk_i,
  //
  inout  [15:0] ddr3_dq,
  inout  [1:0]  ddr3_dqs_n,
  inout  [1:0]  ddr3_dqs_p,
  output [1:0]  ddr3_dm,
  //
  output [2:0]  ddr3_ba,
  output [14:0] ddr3_addr,
  output        ddr3_ras_n,
  output        ddr3_cas_n,
  output        ddr3_we_n,
  //
  output [0:0]  ddr3_cke,
  output [0:0]  ddr3_odt,
  //
  output [0:0]  ddr3_ck_p,
  output [0:0]  ddr3_ck_n,
  //
  output        ddr3_reset_n,

  //AVR SPI IO
  input         AVR_CS_R,
  output        AVR_IRQ,
  output        AVR_MISO_R,
  input         AVR_MOSI_R,
  input         AVR_SCK_R,

  input         ONSWITCH_DB,

  // RF Board connections
  // Change to inout/output as
  // they are implemented/tested
  input [34:0]  DB_EXP_1_8V,

  // Front-end Band Selects
  output [2:0]  TX_BANDSEL,
  output [2:0]  RX1_BANDSEL,
  output [2:0]  RX2_BANDSEL,
  output [1:0]  RX2C_BANDSEL,
  output [1:0]  RX1B_BANDSEL,
  output [1:0]  RX1C_BANDSEL,
  output [1:0]  RX2B_BANDSEL,

  // Enables
  output        TX_ENABLE1A,
  output        TX_ENABLE2A,
  output        TX_ENABLE1B,
  output        TX_ENABLE2B,

  // Antenna Selects
  output        VCTXRX1_V1,
  output        VCTXRX1_V2,
  output        VCTXRX2_V1,
  output        VCTXRX2_V2,
  output        VCRX1_V1,
  output        VCRX1_V2,
  output        VCRX2_V1,
  output        VCRX2_V2,

  // Leds
  output        LED_TXRX1_TX,
  output        LED_TXRX1_RX,
  output        LED_RX1_RX,
  output        LED_TXRX2_TX,
  output        LED_TXRX2_RX,
  output        LED_RX2_RX,

  // AD9361 connections
  input  [7:0]  CAT_CTRL_OUT,
  output [3:0]  CAT_CTRL_IN,
  output        CAT_RESET,  // FIXME Fix in Pinout
  output        CAT_CS,
  output        CAT_SCLK,
  output        CAT_MOSI,
  input         CAT_MISO,
  input         CAT_BBCLK_OUT, //unused
  output        CAT_SYNC,
  output        CAT_TXNRX,
  output        CAT_ENABLE,
  output        CAT_ENAGC,
  input         CAT_RX_FRAME,
  input         CAT_DATA_CLK,
  output        CAT_TX_FRAME,
  output        CAT_FB_CLK,
  input [11:0]  CAT_P0_D,
  output [11:0] CAT_P1_D,

  // pps connections
  input         GPS_PPS,
  input         PPS_EXT_IN,

  // VTCXO and the DAC that feeds it
  output        TCXO_DAC_SYNC_N,
  output        TCXO_DAC_SCLK,
  output        TCXO_DAC_SDIN,
  input         TCXO_CLK,

  // gpios, change to inout somehow
  inout [5:0]   PL_GPIO
);

  // Constants
  localparam REG_AWIDTH = 14; // log2(0x4000)
  localparam REG_DWIDTH = 32;
  localparam DB_GPIO_WIDTH = 32;
  localparam FP_GPIO_OFFSET = 32; // Offset within ps_gpio_*
  localparam FP_GPIO_WIDTH = 6;

  //If bus_clk freq ever changes, update this parameter accordingly.
  localparam BUS_CLK_RATE = 32'd100000000; //100 MHz bus_clk rate.
  localparam NUM_SFP_PORTS = 0;
  localparam NUM_RADIOS = 1;
  localparam NUM_CHANNELS_PER_RADIO = 2;
  localparam NUM_DBOARDS = 1;
  localparam NUM_CHANNELS = NUM_RADIOS * NUM_CHANNELS_PER_RADIO;

  // Clocks
  wire bus_clk;
  wire bus_clk_2x;
  wire radio_clk;
  wire reg_clk;
  wire clk40;
  wire ddr3_dma_clk;
  wire FCLK_CLK0;
  wire FCLK_CLK1;
  wire FCLK_CLK2;
  wire FCLK_CLK3;

  // Resets
  wire global_rst;
  wire bus_rst;
  wire radio_rst;
  wire reg_rstn;
  wire clk40_rst;
  wire clk40_rstn;
  wire FCLK_RESET0_N;

  // Crossbar
  wire        m_axi_xbar_arvalid;
  wire        m_axi_xbar_awvalid;
  wire        m_axi_xbar_bready;
  wire        m_axi_xbar_rready;
  wire        m_axi_xbar_wvalid;
  wire [11:0] m_axi_xbar_arid;
  wire [11:0] m_axi_xbar_awid;
  wire [11:0] m_axi_xbar_wid;
  wire [31:0] m_axi_xbar_araddr;
  wire [31:0] m_axi_xbar_awaddr;
  wire [31:0] m_axi_xbar_wdata;
  wire [3:0]  m_axi_xbar_wstrb;
  wire        m_axi_xbar_arready;
  wire        m_axi_xbar_awready;
  wire        m_axi_xbar_bvalid;
  wire        m_axi_xbar_rlast;
  wire        m_axi_xbar_rvalid;
  wire        m_axi_xbar_wready;
  wire [1:0]  m_axi_xbar_bresp;
  wire [1:0]  m_axi_xbar_rresp;
  wire [31:0] m_axi_xbar_rdata;

  // PMU
  wire [31:0] m_axi_pmu_araddr;
  wire [2:0]  m_axi_pmu_arprot;
  wire        m_axi_pmu_arready;
  wire        m_axi_pmu_arvalid;
  wire [31:0] m_axi_pmu_awaddr;
  wire [2:0]  m_axi_pmu_awprot;
  wire        m_axi_pmu_awready;
  wire        m_axi_pmu_awvalid;
  wire        m_axi_pmu_bready;
  wire [1:0]  m_axi_pmu_bresp;
  wire        m_axi_pmu_bvalid;
  wire [31:0] m_axi_pmu_rdata;
  wire        m_axi_pmu_rready;
  wire [1:0]  m_axi_pmu_rresp;
  wire        m_axi_pmu_rvalid;
  wire [31:0] m_axi_pmu_wdata;
  wire        m_axi_pmu_wready;
  wire [3:0]  m_axi_pmu_wstrb;
  wire        m_axi_pmu_wvalid;

  // DMA to PS
  wire [63:0] o_cvita_dma_tdata;
  wire        o_cvita_dma_tlast;
  wire        o_cvita_dma_tready;
  wire        o_cvita_dma_tvalid;

  wire [63:0] i_cvita_dma_tdata;
  wire        i_cvita_dma_tlast;
  wire        i_cvita_dma_tready;
  wire        i_cvita_dma_tvalid;

  /////////////////////////////////////////////////////////////////////
  //
  // Resets:
  //  - PL - Global Reset --> Bus Reset
  //                      --> Radio Reset
  //  - PS - FCLK_RESET0_N --> clk40_rst(n)
  //
  //////////////////////////////////////////////////////////////////////

  // Global synchronous reset, on the bus_clk domain. De-asserts after 85
  // bus_clk cycles. Asserted by default.
  por_gen por_gen (
    .clk(bus_clk),
    .reset_out(global_rst)
  );

  // Synchronous reset for the bus_clk domain
  reset_sync bus_reset_gen (
    .clk(bus_clk),
    .reset_in(~FCLK_RESET0_N),
    //.reset_in(~clocks_locked),
    .reset_out(bus_rst)
  );


  // PS-based Resets //
  //
  // Synchronous reset for the clk40 domain. This is derived from the PS reset 0.
  reset_sync clk40_reset_gen (
    .clk(clk40),
    .reset_in(~FCLK_RESET0_N),
    .reset_out(clk40_rst)
  );
  // Invert for various modules.
  assign clk40_rstn = ~clk40_rst;
  assign reg_rstn = clk40_rstn;

  /////////////////////////////////////////////////////////////////////
  //
  // Clocks and PPS
  //
  /////////////////////////////////////////////////////////////////////

  wire [1:0] pps_select;

  assign clk40   = FCLK_CLK1;   // 40 MHz
  assign bus_clk = FCLK_CLK0;   // 100 MHz
  assign bus_clk_2x = FCLK_CLK3;   // 200 MHz
  assign ddr3_dma_clk = FCLK_CLK3;
  assign reg_clk = clk40;

  wire pps;
  wire clk_tcxo = TCXO_CLK; // 40 MHz
  wire is_10meg, is_pps, reflck, plllck; // reference status bits
  reg [3:0] tcxo_status, st_rsync;
  reg [2:0] pps_reg;

  wire pps_ext = PPS_EXT_IN;
  wire gps_pps = GPS_PPS;

  // A local pps signal is derived from the tcxo clock. If a reference
  // at an appropriate rate (1 pps or 10 MHz) is present and selected
  // a digital control loop will be invoked to tune the vcxo and lock
  // the reference.
  ppsloop ppslp (
    .reset(1'b0),
    .xoclk(clk_tcxo), .ppsgps(gps_pps), .ppsext(pps_ext),
    .refsel(pps_select),
    .lpps(pps),
    .is10meg(is_10meg), .ispps(is_pps), .reflck(reflck), .plllck(plllck),
    .sclk(TCXO_DAC_SCLK), .mosi(TCXO_DAC_SDIN), .sync_n(TCXO_DAC_SYNC_N),
    .dac_dflt(16'h7fff)
  );

  always @(posedge bus_clk) begin
    // status signals originate from other than the bus_clk domain so re-sync
    // before passing to e300_core
    st_rsync <= {plllck, is_10meg, is_pps, reflck};
    tcxo_status <= st_rsync;
  end

  // TODO: Check this logic
  // connect PPS input to GPIO so ntpd can use it
  always @ (posedge bus_clk)
    pps_reg <= bus_rst ? 3'b000 : {pps_reg[1:0], GPS_PPS};
  assign ps_gpio_in[8] = pps_reg[2]; // 62




  //////////////////////////////////////////////////////////////////////
  //
  // PL DDR3 Memory Interface
  // Added By Jiliang Wang 2020/07/23
  //
  ///////////////////////////////////////////////////////////////////////

  wire         ddr3_axi_clk;                  // 1/4 DDR external clock rate
  wire         ddr3_axi_rst; //used by core   // Synchronized to ddr_sys_clk
  (*mark_debug = "true" *) wire         ddr3_running; //used by core   // DRAM calibration complete.
  wire [11:0]  device_temp;

  // Slave Interface Write Address Ports
  wire [3:0]   ddr3_axi_awid;
  wire [31:0]  ddr3_axi_awaddr;
  wire [7:0]   ddr3_axi_awlen;
  wire [2:0]   ddr3_axi_awsize;
  wire [1:0]   ddr3_axi_awburst;
  wire [0:0]   ddr3_axi_awlock;
  wire [3:0]   ddr3_axi_awcache;
  wire [2:0]   ddr3_axi_awprot;
  wire [3:0]   ddr3_axi_awqos;
  wire         ddr3_axi_awvalid;
  wire         ddr3_axi_awready;
  // Slave Interface Write Data Ports
  wire [127:0] ddr3_axi_wdata;
  wire [15:0]  ddr3_axi_wstrb;
  wire         ddr3_axi_wlast;
  wire         ddr3_axi_wvalid;
  wire         ddr3_axi_wready;
  // Slave Interface Write Response Ports
  wire         ddr3_axi_bready;
  wire [3:0]   ddr3_axi_bid;
  wire [1:0]   ddr3_axi_bresp;
  wire         ddr3_axi_bvalid;
  // Slave Interface Read Address Ports
  wire [3:0]   ddr3_axi_arid;
  wire [31:0]  ddr3_axi_araddr;
  wire [7:0]   ddr3_axi_arlen;
  wire [2:0]   ddr3_axi_arsize;
  wire [1:0]   ddr3_axi_arburst;
  wire [0:0]   ddr3_axi_arlock;
  wire [3:0]   ddr3_axi_arcache;
  wire [2:0]   ddr3_axi_arprot;
  wire [3:0]   ddr3_axi_arqos;
  wire         ddr3_axi_arvalid;
  wire         ddr3_axi_arready;
  // Slave Interface Read Data Ports
  wire         ddr3_axi_rready;
  wire [3:0]   ddr3_axi_rid;
  wire [127:0] ddr3_axi_rdata;
  wire [1:0]   ddr3_axi_rresp;
  wire         ddr3_axi_rlast;
  wire         ddr3_axi_rvalid;

  reg      ddr3_axi_rst_reg_n;

  // Copied this reset circuit from example design.
  always @(posedge ddr3_axi_clk)
    ddr3_axi_rst_reg_n <= ~ddr3_axi_rst;

  mig_7series_0 u_mig_7series_0 (
    // Memory interface ports
    .ddr3_addr           (ddr3_addr),
    .ddr3_ba             (ddr3_ba),
    .ddr3_cas_n          (ddr3_cas_n),
    .ddr3_ck_n           (ddr3_ck_n),
    .ddr3_ck_p           (ddr3_ck_p),
    .ddr3_cke            (ddr3_cke),
    .ddr3_ras_n          (ddr3_ras_n),
    .ddr3_we_n           (ddr3_we_n),
    .ddr3_dq             (ddr3_dq),
    .ddr3_dqs_n          (ddr3_dqs_n),
    .ddr3_dqs_p          (ddr3_dqs_p),
    .ddr3_reset_n        (ddr3_reset_n),
    .init_calib_complete (ddr3_running),

//    .ddr3_cs_n           (ddr3_cs_n),
    .ddr3_dm             (ddr3_dm),
    .ddr3_odt            (ddr3_odt),
    // Application interface ports
    .ui_clk              (ddr3_axi_clk),
    .ui_clk_sync_rst     (ddr3_axi_rst),
    
    .mmcm_locked         (),
    .aresetn             (ddr3_axi_rst_reg_n),
    .app_sr_req          (1'b0),
    .app_ref_req         (1'b0),
    .app_zq_req          (1'b0),
    .app_sr_active       (),
    .app_ref_ack         (),
    .app_zq_ack          (),
    // Slave Interface Write Address Ports
    .s_axi_awid          (ddr3_axi_awid),
    .s_axi_awaddr        (ddr3_axi_awaddr[28:0]),//
    .s_axi_awlen         (ddr3_axi_awlen),
    .s_axi_awsize        (ddr3_axi_awsize),
    .s_axi_awburst       (ddr3_axi_awburst),
    .s_axi_awlock        (ddr3_axi_awlock),
    .s_axi_awcache       (ddr3_axi_awcache),
    .s_axi_awprot        (ddr3_axi_awprot),
    .s_axi_awqos         (ddr3_axi_awqos),//4'h0
    .s_axi_awvalid       (ddr3_axi_awvalid),
    .s_axi_awready       (ddr3_axi_awready),
    // Slave Interface Write Data Ports
    .s_axi_wdata         (ddr3_axi_wdata),
    .s_axi_wstrb         (ddr3_axi_wstrb),
    .s_axi_wlast         (ddr3_axi_wlast),
    .s_axi_wvalid        (ddr3_axi_wvalid),
    .s_axi_wready        (ddr3_axi_wready),
    // Slave Interface Write Response Ports
    .s_axi_bid           (ddr3_axi_bid),
    .s_axi_bresp         (ddr3_axi_bresp),
    .s_axi_bvalid        (ddr3_axi_bvalid),
    .s_axi_bready        (ddr3_axi_bready),
    // Slave Interface Read Address Ports
    .s_axi_arid          (ddr3_axi_arid),
    .s_axi_araddr        (ddr3_axi_araddr[28:0]),//
    .s_axi_arlen         (ddr3_axi_arlen),
    .s_axi_arsize        (ddr3_axi_arsize),
    .s_axi_arburst       (ddr3_axi_arburst),
    .s_axi_arlock        (ddr3_axi_arlock),
    .s_axi_arcache       (ddr3_axi_arcache),
    .s_axi_arprot        (ddr3_axi_arprot),
    .s_axi_arqos         (ddr3_axi_arqos),//4'h0
    .s_axi_arvalid       (ddr3_axi_arvalid),
    .s_axi_arready       (ddr3_axi_arready),
    // Slave Interface Read Data Ports
    .s_axi_rid           (ddr3_axi_rid),
    .s_axi_rdata         (ddr3_axi_rdata),
    .s_axi_rresp         (ddr3_axi_rresp),
    .s_axi_rlast         (ddr3_axi_rlast),
    .s_axi_rvalid        (ddr3_axi_rvalid),
    .s_axi_rready        (ddr3_axi_rready),
    // System Clock Ports
    .sys_clk_i           (sys_clk_i),
    .clk_ref_i           (bus_clk_2x),
    .device_temp         (device_temp),
    //.sys_clk_p           (sys_clk_p),
    //.sys_clk_n           (sys_clk_n),

    .sys_rst             (bus_rst)
  );





  /////////////////////////////////////////////////////////////////////
  //
  // Power Button
  //
  //////////////////////////////////////////////////////////////////////

  // register the debounced onswitch signal to detect edges,
  // Note: ONSWITCH_DB is low active
  reg [1:0] onswitch_edge;
  always @ (posedge bus_clk)
    onswitch_edge <= bus_rst ? 2'b00 : {onswitch_edge[0], ONSWITCH_DB};

  wire button_press = ~ONSWITCH_DB & onswitch_edge[0] & onswitch_edge[1];
  wire button_release = ONSWITCH_DB & ~onswitch_edge[0] & ~onswitch_edge[1];

  // stretch the pulse so IRQs don't get lost
  reg [7:0] button_press_reg, button_release_reg;
  always @ (posedge bus_clk)
    if (bus_rst) begin
      button_press_reg <= 8'h00;
      button_release_reg <= 8'h00;
    end else begin
      button_press_reg <= {button_press_reg[6:0], button_press};
      button_release_reg <= {button_release_reg[6:0], button_release};
    end

  wire button_press_irq = |button_press_reg;
  wire button_release_irq = |button_release_reg;

  /////////////////////////////////////////////////////////////////////
  //
  // Interrupts Fabric to PS
  //
  //////////////////////////////////////////////////////////////////////

  wire [15:0] IRQ_F2P;
  wire pmu_irq;
  assign IRQ_F2P = {12'b0,
                    pmu_irq,            // Interrupt 32
                    button_release_irq, // Interrupt 31
                    button_press_irq,   // Interrupt 30
                    1'b0};

  /////////////////////////////////////////////////////////////////////
  //
  // PS Connections
  //
  //////////////////////////////////////////////////////////////////////

  wire [63:0] ps_gpio_in;
  wire [63:0] ps_gpio_out;
  wire [63:0] ps_gpio_tri;

  e31x_ps_bd e31x_ps_bd_inst (

    // DDR Interface
    .DDR_VRN(DDR_VRN),
    .DDR_VRP(DDR_VRP),
    .DDR_addr(DDR_ADDR),
    .DDR_ba(DDR_BANKADDR),
    .DDR_cas_n(DDR_CAS_N),
    .DDR_ck_n(DDR_CLK_N),
    .DDR_ck_p(DDR_CLK),
    .DDR_cke(DDR_CKE),
    .DDR_cs_n(DDR_CS_N),
    .DDR_dm(DDR_DM),
    .DDR_dq(DDR_DQ),
    .DDR_dqs_n(DDR_DQS_N),
    .DDR_dqs_p(DDR_DQS),
    .DDR_odt(DDR_ODT),
    .DDR_ras_n(DDR_RAS_N),
    .DDR_reset_n(DDR_RESET_N),
    .DDR_we_n(DDR_WE_N),

    // Clocks
    .FCLK_CLK0(FCLK_CLK0),
    .FCLK_CLK1(FCLK_CLK1),
    .FCLK_CLK2(FCLK_CLK2),
    .FCLK_CLK3(FCLK_CLK3),

    // Resets
    .FCLK_RESET0_N(FCLK_RESET0_N),

    // GPIO
    .GPIO_0_tri_i(ps_gpio_in),
    .GPIO_0_tri_o(ps_gpio_out),
    .GPIO_0_tri_t(ps_gpio_tri),

    // Interrupts
    .IRQ_F2P(IRQ_F2P),

    // MIO
    .MIO(MIO),

    .PS_CLK(PS_CLK),
    .PS_PORB(PS_PORB),
    .PS_SRSTB(PS_SRSTB),

    // SPI
    .SPI0_MISO_I(CAT_MISO),
    .SPI0_MISO_O(),
    .SPI0_MISO_T(),
    .SPI0_MOSI_I(1'b0),
    .SPI0_MOSI_O(CAT_MOSI),
    .SPI0_MOSI_T(),
    .SPI0_SCLK_I(1'b0),
    .SPI0_SCLK_O(CAT_SCLK),
    .SPI0_SCLK_T(),
    .SPI0_SS1_O(),
    .SPI0_SS2_O(),
    .SPI0_SS_I(1'b1),
    .SPI0_SS_O(CAT_CS),
    .SPI0_SS_T(),

    .SPI1_MISO_I(),
    .SPI1_MISO_O(),
    .SPI1_MISO_T(),
    .SPI1_MOSI_I(),
    .SPI1_MOSI_O(),
    .SPI1_MOSI_T(),
    .SPI1_SCLK_I(),
    .SPI1_SCLK_O(),
    .SPI1_SCLK_T(),
    .SPI1_SS1_O(),
    .SPI1_SS2_O(),
    .SPI1_SS_I(),
    .SPI1_SS_O(),
    .SPI1_SS_T(),

    // USB
    .USBIND_0_port_indctl(),
    .USBIND_0_vbus_pwrfault(),
    .USBIND_0_vbus_pwrselect(),

    .bus_clk(bus_clk),
    .bus_rstn(~bus_rst),
    .clk40(clk40),
    .clk40_rstn(clk40_rstn),
    .S_AXI_GP0_ACLK(clk40),
    .S_AXI_GP0_ARESETN(clk40_rstn),

    // XBAR Regport
    .m_axi_xbar_araddr(m_axi_xbar_araddr),
    .m_axi_xbar_arprot(m_axi_xbar_arprot),
    .m_axi_xbar_arready(m_axi_xbar_arready),
    .m_axi_xbar_arvalid(m_axi_xbar_arvalid),
    .m_axi_xbar_awaddr(m_axi_xbar_awaddr),
    .m_axi_xbar_awprot(m_axi_xbar_awprot),
    .m_axi_xbar_awready(m_axi_xbar_awready),
    .m_axi_xbar_awvalid(m_axi_xbar_awvalid),
    .m_axi_xbar_bready(m_axi_xbar_bready),
    .m_axi_xbar_bresp(m_axi_xbar_bresp),
    .m_axi_xbar_bvalid(m_axi_xbar_bvalid),
    .m_axi_xbar_rdata(m_axi_xbar_rdata),
    .m_axi_xbar_rready(m_axi_xbar_rready),
    .m_axi_xbar_rresp(m_axi_xbar_rresp),
    .m_axi_xbar_rvalid(m_axi_xbar_rvalid),
    .m_axi_xbar_wdata(m_axi_xbar_wdata),
    .m_axi_xbar_wready(m_axi_xbar_wready),
    .m_axi_xbar_wstrb(m_axi_xbar_wstrb),
    .m_axi_xbar_wvalid(m_axi_xbar_wvalid),

    // PMU
    .m_axi_pmu_araddr(m_axi_pmu_araddr),
    .m_axi_pmu_arprot(m_axi_pmu_arprot),
    .m_axi_pmu_arready(m_axi_pmu_arready),
    .m_axi_pmu_arvalid(m_axi_pmu_arvalid),
    .m_axi_pmu_awaddr(m_axi_pmu_awaddr),
    .m_axi_pmu_awprot(m_axi_pmu_awprot),
    .m_axi_pmu_awready(m_axi_pmu_awready),
    .m_axi_pmu_awvalid(m_axi_pmu_awvalid),
    .m_axi_pmu_bready(m_axi_pmu_bready),
    .m_axi_pmu_bresp(m_axi_pmu_bresp),
    .m_axi_pmu_bvalid(m_axi_pmu_bvalid),
    .m_axi_pmu_rdata(m_axi_pmu_rdata),
    .m_axi_pmu_rready(m_axi_pmu_rready),
    .m_axi_pmu_rresp(m_axi_pmu_rresp),
    .m_axi_pmu_rvalid(m_axi_pmu_rvalid),
    .m_axi_pmu_wdata(m_axi_pmu_wdata),
    .m_axi_pmu_wready(m_axi_pmu_wready),
    .m_axi_pmu_wstrb(m_axi_pmu_wstrb),
    .m_axi_pmu_wvalid(m_axi_pmu_wvalid),

    // DMA
    .i_cvita_dma_tdata(i_cvita_dma_tdata),
    .i_cvita_dma_tlast(i_cvita_dma_tlast),
    .i_cvita_dma_tready(i_cvita_dma_tready),
    .i_cvita_dma_tvalid(i_cvita_dma_tvalid),
    .o_cvita_dma_tdata(o_cvita_dma_tdata),
    .o_cvita_dma_tlast(o_cvita_dma_tlast),
    .o_cvita_dma_tready(o_cvita_dma_tready),
    .o_cvita_dma_tvalid(o_cvita_dma_tvalid)
  );

  /////////////////////////////////////////////////////////////////////
  //
  // AD9361 Interface
  //
  /////////////////////////////////////////////////////////////////////

  wire [REG_DWIDTH-1:0] dboard_ctrl;
  wire [REG_DWIDTH-1:0] dboard_status;
  wire mimo_busclk;
  wire tx_pll_lock_busclk, rx_pll_lock_busclk;

  wire codec_arst;
  wire [NUM_CHANNELS*32-1:0] rx_flat, tx_flat;

  wire [11:0] rx_i0, rx_q0, tx_i0, tx_q0;
  wire [11:0] rx_i1, rx_q1, tx_i1, tx_q1;

  wire rx_stb, tx_stb;
  wire [NUM_CHANNELS-1:0] rx_atr, tx_atr;

  assign rx_flat = {rx_i1, 4'd0, rx_q1, 4'd0,
                    rx_i0, 4'd0, rx_q0, 4'd0};

  assign tx_q0 = tx_flat[15:4];
  assign tx_i0 = tx_flat[31:20];
  assign tx_q1 = tx_flat[47:36];
  assign tx_i1 = tx_flat[63:52];

  assign mimo_busclk = dboard_ctrl[0];
  assign codec_arst = dboard_ctrl[1];

  synchronizer synchronizer_tx_pll_lock (
    .clk(bus_clk), .rst(1'b0), .in(CAT_CTRL_OUT[7]), .out(tx_pll_lock_busclk)
  );

  synchronizer synchronizer_rx_pll_lock (
    .clk(bus_clk), .rst(1'b0), .in(CAT_CTRL_OUT[6]), .out(rx_pll_lock_busclk)
  );

  assign dboard_status = {
    20'b0,
    tcxo_status,          // TCXO satus {plllck, is_10meg, is_pps, refclk}
    tx_pll_lock_busclk,   // TX PLL Lock
    rx_pll_lock_busclk,   // RX PLL Lock
    6'b0
  };


  e310_io e310_io (
    //.areset(codec_arst), TODO
    .areset(bus_rst),
    .mimo(mimo_busclk),
    // Baseband sample interface
    .radio_clk(radio_clk),
    .radio_rst(radio_rst),
    .rx_i0(rx_i1),
    .rx_q0(rx_q1),
    .rx_i1(rx_i0),
    .rx_q1(rx_q0),
    .rx_stb(rx_stb),
    .tx_i0(tx_i1),
    .tx_q0(tx_q1),
    .tx_i1(tx_i0),
    .tx_q1(tx_q0),
    .tx_stb(tx_stb),
    // AD9361 interface
    .rx_clk(CAT_DATA_CLK),
    .rx_frame(CAT_RX_FRAME),
    .rx_data(CAT_P0_D),
    .tx_clk(CAT_FB_CLK),
    .tx_frame(CAT_TX_FRAME),
    .tx_data(CAT_P1_D)
  );

  assign CAT_CTRL_IN = 4'b1;
  assign CAT_ENAGC = 1'b1;
  assign CAT_TXNRX = 1'b1;
  assign CAT_ENABLE = 1'b1;
  assign CAT_RESET = ~bus_rst; // Operates active-low, really CAT_RESET_B
  assign CAT_SYNC = 1'b0;

  /////////////////////////////////////////////////////////////////////
  //
  // DB GPIO Interface
  //  - Control Filter Banks
  //  - LEDs
  //
  /////////////////////////////////////////////////////////////////////

  // Flattened Radio GPIO control
  wire [DB_GPIO_WIDTH*NUM_CHANNELS-1:0] db_gpio_out_flat;
  wire [DB_GPIO_WIDTH*NUM_CHANNELS-1:0] db_gpio_ddr_flat;
  wire [DB_GPIO_WIDTH*NUM_CHANNELS-1:0] db_gpio_in_flat;
  wire [32*NUM_CHANNELS-1:0] leds_flat;

  // Radio GPIO control
  wire [DB_GPIO_WIDTH-1:0] db_gpio_in[0:NUM_CHANNELS-1];
  wire [DB_GPIO_WIDTH-1:0] db_gpio_out[0:NUM_CHANNELS-1];
  wire [DB_GPIO_WIDTH-1:0] db_gpio_ddr[0:NUM_CHANNELS-1];
  wire [DB_GPIO_WIDTH-1:0] db_gpio_pins[0:NUM_CHANNELS-1];
  wire [31:0] leds[0:NUM_CHANNELS-1];

  genvar i;
  generate
    for (i = 0; i < NUM_CHANNELS; i = i + 1) begin

      assign db_gpio_in_flat[DB_GPIO_WIDTH*i +: DB_GPIO_WIDTH] = db_gpio_in[i];
      assign db_gpio_out[i] = db_gpio_out_flat[DB_GPIO_WIDTH*i +: DB_GPIO_WIDTH];
      assign db_gpio_ddr[i] = db_gpio_ddr_flat[DB_GPIO_WIDTH*i +: DB_GPIO_WIDTH];
      assign leds[i] = leds_flat[32*i +: 32];

      gpio_atr_io #(
        .WIDTH(DB_GPIO_WIDTH)
      ) gpio_atr_db_inst (
        .clk(radio_clk),
        .gpio_pins(db_gpio_pins[i]),
        .gpio_ddr(db_gpio_ddr[i]),
        .gpio_out(db_gpio_out[i]),
        .gpio_in(db_gpio_in[i])
      );
    end
  endgenerate

  // DB_GPIO and LED pin assignments with software mapping
  wire [2:0] TX1_BANDSEL;
  wire [2:0] TX2_BANDSEL;

  // Channel 0
  assign {VCRX1_V1, // [15:15]
          VCRX1_V2, // [14:14]
          VCTXRX1_V1, // [13:13]
          VCTXRX1_V2, // [12:12]
          TX_ENABLE1B, // [11:11]
          TX_ENABLE1A, // [10:10]
          RX1C_BANDSEL, // [9:8]
          RX1B_BANDSEL, // [7:6]
          RX1_BANDSEL, // [5:3]
          TX1_BANDSEL // [2:0]
         } = db_gpio_pins[1];

  assign {LED_RX1_RX,
          LED_TXRX1_TX,
          LED_TXRX1_RX
         } = leds[1];

  // Channel 1
  assign {VCRX2_V1,
          VCRX2_V2,
          VCTXRX2_V1,
          VCTXRX2_V2,
          TX_ENABLE2B,
          TX_ENABLE2A,
          RX2C_BANDSEL,
          RX2B_BANDSEL,
          RX2_BANDSEL,
          TX2_BANDSEL
         } = db_gpio_pins[0];

  assign {LED_RX2_RX,
          LED_TXRX2_TX,
          LED_TXRX2_RX
         } = leds[0];

  // It is okay to OR here as the both channels must be set to the same freq.
  // This is needed so software does not have to set properties of radio core 0
  // when only using radio core 1.
  assign TX_BANDSEL = TX1_BANDSEL | TX2_BANDSEL;

    /////////////////////////////////////////////////////////////////////
  //
  // Front-Panel GPIO
  //
  /////////////////////////////////////////////////////////////////////

  wire [FP_GPIO_WIDTH-1:0] fp_gpio_in;
  wire [FP_GPIO_WIDTH-1:0] fp_gpio_out;
  wire [FP_GPIO_WIDTH-1:0] fp_gpio_tri;

  gpio_atr_io #(.WIDTH(FP_GPIO_WIDTH)) fp_gpio_atr_inst (
    .clk(radio_clk), .gpio_pins(PL_GPIO),
    .gpio_ddr(fp_gpio_tri), .gpio_out(fp_gpio_out), .gpio_in(fp_gpio_in)
  );

  /////////////////////////////////////////////////////////////////////
  //
  // GPSDO Control and Status
  //
  /////////////////////////////////////////////////////////////////////

  wire [31:0] gps_ctrl;
  wire [31:0] gps_status;
  // Not used

  /////////////////////////////////////////////////////////////////////
  //
  // E320 Core:
  //   - xbar
  //   - Radio
  //   - DMA
  //   - DRAM
  //   - CEs
  //
  //////////////////////////////////////////////////////////////////////

  wire [31:0] build_datestamp;

  USR_ACCESSE2 usr_access_i (
    .DATA(build_datestamp), .CFGCLK(), .DATAVALID()
  );

  e31x_core #(
    .REG_AWIDTH(REG_AWIDTH),
    .BUS_CLK_RATE(BUS_CLK_RATE),
    .NUM_SFP_PORTS(NUM_SFP_PORTS),
    .NUM_RADIO_CORES(NUM_RADIOS),
    .NUM_CHANNELS_PER_RADIO(NUM_CHANNELS_PER_RADIO),
    .NUM_CHANNELS(NUM_CHANNELS),
    .NUM_DBOARDS(NUM_DBOARDS),
    .USE_REPLAY(1),
    .FP_GPIO_WIDTH(FP_GPIO_WIDTH),
    .DB_GPIO_WIDTH(DB_GPIO_WIDTH)
  ) e31x_core_inst (

    //Clocks and resets
    .radio_clk(radio_clk),
    .radio_rst(radio_rst),
    .bus_clk(bus_clk),
    .bus_rst(bus_rst),
    .ddr3_dma_clk(ddr3_dma_clk),
    // Clocking and PPS Controls/Indicators
    .pps_refclk(pps),
    .refclk_locked(reflck),
    .pps_select(pps_select),

    .s_axi_aclk(clk40),
    .s_axi_aresetn(clk40_rstn),
    // AXI4-Lite: Write address port (domain: s_axi_aclk)
    .s_axi_awaddr(m_axi_xbar_awaddr),
    .s_axi_awvalid(m_axi_xbar_awvalid),
    .s_axi_awready(m_axi_xbar_awready),
    // AXI4-Lite: Write data port (domain: s_axi_aclk)
    .s_axi_wdata(m_axi_xbar_wdata),
    .s_axi_wstrb(m_axi_xbar_wstrb),
    .s_axi_wvalid(m_axi_xbar_wvalid),
    .s_axi_wready(m_axi_xbar_wready),
    // AXI4-Lite: Write response port (domain: s_axi_aclk)
    .s_axi_bresp(m_axi_xbar_bresp),
    .s_axi_bvalid(m_axi_xbar_bvalid),
    .s_axi_bready(m_axi_xbar_bready),
    // AXI4-Lite: Read address port (domain: s_axi_aclk)
    .s_axi_araddr(m_axi_xbar_araddr),
    .s_axi_arvalid(m_axi_xbar_arvalid),
    .s_axi_arready(m_axi_xbar_arready),
    // AXI4-Lite: Read data port (domain: s_axi_aclk)
    .s_axi_rdata(m_axi_xbar_rdata),
    .s_axi_rresp(m_axi_xbar_rresp),
    .s_axi_rvalid(m_axi_xbar_rvalid),
    .s_axi_rready(m_axi_xbar_rready),



    // DRAM signals
    .ddr3_axi_clk              (ddr3_axi_clk),
    .ddr3_axi_rst              (ddr3_axi_rst),
    .ddr3_running              (ddr3_running),
    // Slave Interface Write Address Ports
    .ddr3_axi_awid             (ddr3_axi_awid),
    .ddr3_axi_awaddr           (ddr3_axi_awaddr),
    .ddr3_axi_awlen            (ddr3_axi_awlen),
    .ddr3_axi_awsize           (ddr3_axi_awsize),
    .ddr3_axi_awburst          (ddr3_axi_awburst),
    .ddr3_axi_awlock           (ddr3_axi_awlock),
    .ddr3_axi_awcache          (ddr3_axi_awcache),
    .ddr3_axi_awprot           (ddr3_axi_awprot),
    .ddr3_axi_awqos            (ddr3_axi_awqos),
    .ddr3_axi_awvalid          (ddr3_axi_awvalid),
    .ddr3_axi_awready          (ddr3_axi_awready),
    // Slave Interface Write Data Ports
    .ddr3_axi_wdata            (ddr3_axi_wdata),
    .ddr3_axi_wstrb            (ddr3_axi_wstrb),
    .ddr3_axi_wlast            (ddr3_axi_wlast),
    .ddr3_axi_wvalid           (ddr3_axi_wvalid),
    .ddr3_axi_wready           (ddr3_axi_wready),
    // Slave Interface Write Response Ports
    .ddr3_axi_bid              (ddr3_axi_bid),
    .ddr3_axi_bresp            (ddr3_axi_bresp),
    .ddr3_axi_bvalid           (ddr3_axi_bvalid),
    .ddr3_axi_bready           (ddr3_axi_bready),
    // Slave Interface Read Address Ports
    .ddr3_axi_arid             (ddr3_axi_arid),
    .ddr3_axi_araddr           (ddr3_axi_araddr),
    .ddr3_axi_arlen            (ddr3_axi_arlen),
    .ddr3_axi_arsize           (ddr3_axi_arsize),
    .ddr3_axi_arburst          (ddr3_axi_arburst),
    .ddr3_axi_arlock           (ddr3_axi_arlock),
    .ddr3_axi_arcache          (ddr3_axi_arcache),
    .ddr3_axi_arprot           (ddr3_axi_arprot),
    .ddr3_axi_arqos            (ddr3_axi_arqos),
    .ddr3_axi_arvalid          (ddr3_axi_arvalid),
    .ddr3_axi_arready          (ddr3_axi_arready),
    // Slave Interface Read Data Ports
    .ddr3_axi_rid              (ddr3_axi_rid),
    .ddr3_axi_rdata            (ddr3_axi_rdata),
    .ddr3_axi_rresp            (ddr3_axi_rresp),
    .ddr3_axi_rlast            (ddr3_axi_rlast),
    .ddr3_axi_rvalid           (ddr3_axi_rvalid),
    .ddr3_axi_rready           (ddr3_axi_rready),

    // Radio ATR
    .rx_atr(rx_atr),
    .tx_atr(tx_atr),

    // Front-Panel GPIO
    .fp_gpio_in(fp_gpio_in),
    .fp_gpio_tri(fp_gpio_tri),
    .fp_gpio_out(fp_gpio_out),

    // PS GPIO Connection
    .ps_gpio_tri(ps_gpio_tri[FP_GPIO_WIDTH+FP_GPIO_OFFSET-1: FP_GPIO_OFFSET]),
    .ps_gpio_out(ps_gpio_out[FP_GPIO_WIDTH+FP_GPIO_OFFSET-1: FP_GPIO_OFFSET]),
    .ps_gpio_in(ps_gpio_in[FP_GPIO_WIDTH+FP_GPIO_OFFSET-1: FP_GPIO_OFFSET]),

    // DB GPIO
    .db_gpio_out_flat(db_gpio_out_flat),
    .db_gpio_ddr_flat(db_gpio_ddr_flat),
    .db_gpio_in_flat(db_gpio_in_flat),
    .db_gpio_fab_flat(32'b0),

    // TX/RX LEDs
    .leds_flat(leds_flat),

    // Radio Strobes
    .rx_stb({NUM_CHANNELS{rx_stb}}),
    .tx_stb({NUM_CHANNELS{tx_stb}}),

    // Radio Data
    .rx(rx_flat),
    .tx(tx_flat),

    // DMA to PS
    .dmao_tdata(i_cvita_dma_tdata),
    .dmao_tlast(i_cvita_dma_tlast),
    .dmao_tready(i_cvita_dma_tready),
    .dmao_tvalid(i_cvita_dma_tvalid),

    .dmai_tdata(o_cvita_dma_tdata),
    .dmai_tlast(o_cvita_dma_tlast),
    .dmai_tready(o_cvita_dma_tready),
    .dmai_tvalid(o_cvita_dma_tvalid),

    .build_datestamp(build_datestamp),
    .sfp_ports_info(),
    .gps_status(gps_status),
    .gps_ctrl(gps_ctrl),
    .dboard_status(dboard_status),
    .xadc_readback(32'h0), //Unused
    .fp_gpio_ctrl(), //Unused
    .dboard_ctrl(dboard_ctrl)
  );

  /////////////////////////////////////////////////////////////////////
  //
  // PL DDR3 Memory Interface
  //
  /////////////////////////////////////////////////////////////////////

  //wire pl_dram_clk = FCLK_CLK3;
  //wire pl_dram_rst = ~FCLK_RESET0_N;

  //example_top inst_example_top
  //(
  //  .ddr3_dq                       (PL_DDR3_DQ),
  //  .ddr3_dqs_n                    (PL_DDR3_DQS_N),
  //  .ddr3_dqs_p                    (PL_DDR3_DQS_P),
  //  .ddr3_addr                     (PL_DDR3_ADDR),
  //  .ddr3_ba                       (PL_DDR3_BA),
  //  .ddr3_ras_n                    (PL_DDR3_RAS_N),
  //  .ddr3_cas_n                    (PL_DDR3_CAS_N),
  //  .ddr3_we_n                     (PL_DDR3_WE_N),
  //  .ddr3_reset_n                  (PL_DDR3_RESET_N),
  //  .ddr3_ck_p                     (PL_DDR3_CK_P),
  //  .ddr3_ck_n                     (PL_DDR3_CK_N),
  //  .ddr3_cke                      (PL_DDR3_CKE),
  //  .ddr3_dm                       (PL_DDR3_DM),
  //  .ddr3_odt                      (PL_DDR3_ODT),
  //  .sys_clk_i                     (PL_DDR3_SYSCLK),
  //  .clk_ref_i                     (pl_dram_clk),
  //  .tg_compare_error              (),
  //  .init_calib_complete           (),
  //  .sys_rst                       (pl_dram_rst)
  //);

  // PMU
  axi_pmu inst_axi_pmu (
    .s_axi_aclk(clk40),  // TODO: Original design used bus_clk
    .s_axi_areset(clk40_rst),

    .ss(AVR_CS_R),
    .mosi(AVR_MOSI_R),
    .sck(AVR_SCK_R),
    .miso(AVR_MISO_R),

    // AXI4-Lite: Write address port (domain: s_axi_aclk)
    .s_axi_awaddr(m_axi_pmu_awaddr),
    .s_axi_awvalid(m_axi_pmu_awvalid),
    .s_axi_awready(m_axi_pmu_awready),
    // AXI4-Lite: Write data port (domain: s_axi_aclk)
    .s_axi_wdata(m_axi_pmu_wdata),
    .s_axi_wstrb(m_axi_pmu_wstrb),
    .s_axi_wvalid(m_axi_pmu_wvalid),
    .s_axi_wready(m_axi_pmu_wready),
    // AXI4-Lite: Write response port (domain: s_axi_aclk)
    .s_axi_bresp(m_axi_pmu_bresp),
    .s_axi_bvalid(m_axi_pmu_bvalid),
    .s_axi_bready(m_axi_pmu_bready),
    // AXI4-Lite: Read address port (domain: s_axi_aclk)
    .s_axi_araddr(m_axi_pmu_araddr),
    .s_axi_arvalid(m_axi_pmu_arvalid),
    .s_axi_arready(m_axi_pmu_arready),
    // AXI4-Lite: Read data port (domain: s_axi_aclk)
    .s_axi_rdata(m_axi_pmu_rdata),
    .s_axi_rresp(m_axi_pmu_rresp),
    .s_axi_rvalid(m_axi_pmu_rvalid),
    .s_axi_rready(m_axi_pmu_rready),

    .s_axi_irq(pmu_irq)
  );

  assign AVR_IRQ = 1'b0;


endmodule // e31x
