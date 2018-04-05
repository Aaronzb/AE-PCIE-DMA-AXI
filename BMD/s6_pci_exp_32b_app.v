//-----------------------------------------------------------------------------
//
// (c) Copyright 2001, 2002, 2003, 2004, 2005, 2007, 2008, 2009 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information of Xilinx, Inc.
// and is protected under U.S. and international copyright and other
// intellectual property laws.
//
// DISCLAIMER
//
// This disclaimer is not a license and does not grant any rights to the
// materials distributed herewith. Except as otherwise provided in a valid
// license issued to you by Xilinx, and to the maximum extent permitted by
// applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL
// FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS,
// IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
// MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE;
// and (2) Xilinx shall not be liable (whether in contract or tort, including
// negligence, or under any other theory of liability) for any loss or damage
// of any kind or nature related to, arising under or in connection with these
// materials, including for any direct, or any indirect, special, incidental,
// or consequential loss or damage (including loss of data, profits, goodwill,
// or any type of loss or damage suffered as a result of any action brought by
// a third party) even if such damage or loss was reasonably foreseeable or
// Xilinx had been advised of the possibility of the same.
//
// CRITICAL APPLICATIONS
//
// Xilinx products are not designed or intended to be fail-safe, or for use in
// any application requiring fail-safe performance, such as life-support or
// safety devices or systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any other
// applications that could lead to death, personal injury, or severe property
// or environmental damage (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and liability of any use of
// Xilinx products in Critical Applications, subject only to applicable laws
// and regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE
// AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Spartan-6 Integrated Block for PCI Express
// File       : pcie_app_s6.v
// Description: PCI Express Endpoint sample application
//              design. 
//
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

`define PCI_EXP_EP_OUI                           24'h000A35
`define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2                         32'h00000001

parameter INTERFACE_WIDTH = 32;
parameter INTERFACE_TYPE = 4'b0010;
parameter FPGA_FAMILY = 8'h20; 
parameter REM_WIDTH  = (INTERFACE_WIDTH == 128) ? 2 : 1;

module pcie_app_s6
(
  input            user_clk,
  input            user_reset,
  input            user_lnk_up,

  // Tx
  input  [5:0]     tx_buf_av,
  input            tx_cfg_req,
  output           tx_cfg_gnt,
  input            tx_err_drop,

  input            s_axis_tx_tready,
  output  [31:0]   s_axis_tx_tdata,
  output  [3:0]    s_axis_tx_tkeep,
  output  [3:0]    s_axis_tx_tuser,
  output           s_axis_tx_tlast,
  output           s_axis_tx_tvalid,

  // Rx
  output           rx_np_ok,
  input  [31:0]    m_axis_rx_tdata,
  input  [3:0]     m_axis_rx_tkeep,
  input            m_axis_rx_tlast,
  input            m_axis_rx_tvalid,
  output           m_axis_rx_tready,
  input  [21:0]    m_axis_rx_tuser,

  // Flow Control
  input  [11:0]    fc_cpld,
  input  [7:0]     fc_cplh,
  input  [11:0]    fc_npd,
  input  [7:0]     fc_nph,
  input  [11:0]    fc_pd,
  input  [7:0]     fc_ph,
  output [2:0]     fc_sel,


  input  [31:0]    cfg_do,
  input            cfg_rd_wr_done,
  output [9:0]     cfg_dwaddr,
  output           cfg_rd_en,


  output           cfg_err_cor,
  output           cfg_err_ur,
  output           cfg_err_ecrc,
  output           cfg_err_cpl_timeout,
  output           cfg_err_cpl_abort,
  output           cfg_err_posted,
  output           cfg_err_locked,
  output [47:0]    cfg_err_tlp_cpl_header,
  input            cfg_err_cpl_rdy,
  output           cfg_interrupt,
  input            cfg_interrupt_rdy,
  output           cfg_interrupt_assert,
  output [7:0]     cfg_interrupt_di,
  input  [7:0]     cfg_interrupt_do,
  input  [2:0]     cfg_interrupt_mmenable,
  input            cfg_interrupt_msienable,
  output           cfg_turnoff_ok,
  input            cfg_to_turnoff,
  output           cfg_trn_pending,
  output           cfg_pm_wake,
  input   [7:0]    cfg_bus_number,
  input   [4:0]    cfg_device_number,
  input   [2:0]    cfg_function_number,
  input  [15:0]    cfg_status,
  input  [15:0]    cfg_command,
  input  [15:0]    cfg_dstatus,
  input  [15:0]    cfg_dcommand,
  input  [15:0]    cfg_lstatus,
  input  [15:0]    cfg_lcommand,
  input   [2:0]    cfg_pcie_link_state,

  output [63:0]    cfg_dsn
);


// Wires and regs for creating trn signals

   wire [REM_WIDTH-1:0]    trn_trem_n;
   wire [REM_WIDTH-1:0]    trn_rrem;
   wire [INTERFACE_WIDTH-1:0] trn_td;
   wire [INTERFACE_WIDTH-1:0] trn_rd;
   wire                    trn_tsof_n;
   wire                    trn_teof_n;
   wire                    trn_tsrc_rdy_n;
   wire                    trn_tdst_rdy;
   wire                    trn_tstr_n;

   wire                    trn_rsof;
   wire                    trn_reof;
   wire                    trn_rsrc_rdy;
   wire                    trn_rdst_rdy_n;
   wire                    trn_rsrc_dsc;
   wire  [7:0]             trn_rbar_hit;
   wire                    trn_rnp_ok_n;



//
// Core input tie-offs
//

  assign fc_sel               = 3'b0; 
  assign rx_np_ok             = 1'b1;
  assign rx_np_req            = 1'b1; 
  assign tx_cfg_gnt           = 1'b1;

  assign cfg_err_cor          = 1'b0;
  assign cfg_err_ur           = 1'b0;
  assign cfg_err_ecrc         = 1'b0;
  assign cfg_err_cpl_timeout  = 1'b0;
  assign cfg_err_cpl_abort    = 1'b0;
  assign cfg_err_cpl_unexpect = 1'b0;
  assign cfg_err_posted       = 1'b0;
  assign cfg_err_locked       = 1'b0;
  assign cfg_pm_wake          = 1'b0;
  assign cfg_trn_pending      = 1'b0;


  assign pl_upstream_prefer_deemph = 1'b1;  // changed to be -3.5dB
  assign cfg_interrupt_di          = 8'b0;
  assign cfg_err_tlp_cpl_header    = 47'h0;
  assign cfg_di                    = 0;
  assign cfg_byte_en               = 4'h0;
  assign cfg_wr_en                 = 0;
  assign cfg_dsn                   = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};

//
// Programmable I/O Module
//

  wire [15:0] cfg_completer_id        = { cfg_bus_number, cfg_device_number, cfg_function_number };
  wire        cfg_bus_mstr_enable     = cfg_command[2];  
  wire        cfg_rd_en_n;
  wire        cfg_interrupt_n;
  wire        cfg_interrupt_assert_n;
  wire        cfg_turnoff_ok_n;
  assign      cfg_rd_en               = ~cfg_rd_en_n;
  assign      cfg_interrupt           = ~cfg_interrupt_n;
  assign      cfg_interrupt_assert    = ~cfg_interrupt_assert_n;
  assign      cfg_turnoff_ok          = ~cfg_turnoff_ok_n;


  wire        cfg_ext_tag_en          = cfg_dcommand[8];
  wire        cfg_phant_func_en       = cfg_dcommand[9];
  wire  [1:0] cfg_phant_func_supported= cfg_dstatus[4:3];
  wire  [5:0] cfg_neg_max_lnk_width   = cfg_lstatus[9:4];
  wire  [2:0] cfg_prg_max_payload_size= cfg_dcommand[7:5];
  wire  [2:0] cfg_max_rd_req_size     = cfg_dcommand[14:12];
  wire        cfg_rd_comp_bound       = cfg_lcommand[3];


BMD#
   (
   .INTERFACE_WIDTH(INTERFACE_WIDTH),
   .INTERFACE_TYPE(INTERFACE_TYPE),
   .FPGA_FAMILY(FPGA_FAMILY)
   ) BMD (

   .trn_clk     ( user_clk ),                         // I
   .trn_reset_n ( ~user_reset ),                      // I
   .trn_lnk_up_n (~user_lnk_up ),                     // I
  
   .trn_td ( trn_td ),                                // O [63:0]
   .trn_trem_n ( trn_trem_n ),                        // O [7:0]
   .trn_tsof_n ( trn_tsof_n ),                        // O
   .trn_teof_n ( trn_teof_n ),                        // O
   .trn_tsrc_rdy_n ( trn_tsrc_rdy_n ),                // O
   .trn_tsrc_dsc_n ( trn_tsrc_dsc_n ),                // O
   .trn_tdst_rdy_n ( ~trn_tdst_rdy ),                 // I
   .trn_tdst_dsc_n ( 1'b1 ),                          // I
   .trn_tbuf_av ( tx_buf_av ),                        // I [5:0]
   .trn_tstr_n (trn_tstr_n ),                         // O
   
  
   .trn_rd ( trn_rd ),                                // I [63:0]
   .trn_rrem_n ( ~trn_rrem),                          // I [7:0]
   .trn_rsof_n ( ~trn_rsof ),                         // I
   .trn_reof_n ( ~trn_reof ),                         // I
   .trn_rsrc_rdy_n ( ~trn_rsrc_rdy ),                 // I
   .trn_rsrc_dsc_n ( ~trn_rsrc_dsc ),                 // I
   .trn_rdst_rdy_n ( trn_rdst_rdy_n ),                // O
   .trn_rbar_hit_n ( ~trn_rbar_hit[6:0] ),            // I [6:0]
   .trn_rnp_ok_n ( trn_rnp_ok_n ),                    // O 

   .cfg_to_turnoff_n ( ~cfg_to_turnoff ),             // I
   .cfg_turnoff_ok_n ( cfg_turnoff_ok_n ),            // O
 
   .cfg_interrupt_n(cfg_interrupt_n),                 // O
   .cfg_interrupt_rdy_n(~cfg_interrupt_rdy),          // I
   
   .cfg_interrupt_msienable(cfg_interrupt_msienable), // I
   .cfg_interrupt_do(cfg_interrupt_do),               // I
   .cfg_interrupt_mmenable(cfg_interrupt_mmenable),   // I
   .cfg_interrupt_assert_n(cfg_interrupt_assert_n),   // O
   .cfg_ext_tag_en(cfg_ext_tag_en),                   // I 
   .cfg_phant_func_en(cfg_phant_func_en),             // I 
   .cfg_phant_func_supported(cfg_phant_func_supported),   // I [1:0]
   .cfg_interrupt_di( ),                                  // O [7:0] 

   .cfg_neg_max_lnk_width(cfg_neg_max_lnk_width),         // I [5:0]
   .cfg_prg_max_payload_size(cfg_prg_max_payload_size),   // I [5:0]
   .cfg_max_rd_req_size(cfg_max_rd_req_size),             // I [2:0]
   .cfg_rd_comp_bound(cfg_rd_comp_bound),                 // I 

   .cfg_dwaddr(cfg_dwaddr),                               // O [11:0]
   .cfg_rd_en_n(cfg_rd_en_n),                             // O
   .cfg_do(cfg_do),                                       // I [31:0]
   .cfg_rd_wr_done_n(~cfg_rd_wr_done),                    // I 

   .pl_initial_link_width( pl_initial_link_width ),       // I [2:0]
   .pl_lane_reversal_mode( pl_lane_reversal_mode ),       // I [1:0]
   .pl_link_gen2_capable( pl_link_gen2_capable ),         // I
   .pl_link_partner_gen2_supported( pl_link_partner_gen2_supported ), // I
   .pl_link_upcfg_capable( pl_link_upcfg_capable ),                   // I
   .pl_ltssm_state( pl_ltssm_state ),                                 // I [5:0]
   .pl_sel_link_width( pl_sel_link_width ),                           // I [1:0]
   .pl_sel_link_rate( pl_sel_link_rate ),                             // I
   .pl_directed_link_auton( pl_directed_link_auton ),                 // O
   .pl_directed_link_change( pl_directed_link_change ),               // O [1:0]
   .pl_directed_link_speed( pl_directed_link_speed ),                 // O 
   .pl_directed_link_width( pl_directed_link_width ),                 // O [1:0]
   .pl_upstream_preemph_src( ),                                       // O
  
   .cpld_data_size_hwm( ),                                            // O [31:0]
   .cur_rd_count_hwm( ),                                              // O [15:0]
   .cpld_size( ),                                                     // O [31:0]
   .cur_mrd_count( ),                                                 // O [15:0]    
   
   .cfg_completer_id ( cfg_completer_id ),                            // I [15:0]
   .cfg_bus_mstr_enable (cfg_bus_mstr_enable )                        // I 

);


axi_trn_top #(
  .C_DATA_WIDTH     (INTERFACE_WIDTH),    // RX/TX interface data width

  .C_FAMILY         ("S6"),               // Targeted FPGA family
  .C_ROOT_PORT      ("FALSE"),            // PCIe block is in root port mode
  .C_PM_PRIORITY    ("FALSE")             // Disable TX packet boundary thrtl

  ) axi_trn_top (
  //---------------------------------------------//
  // User Design I/O                             //
  //---------------------------------------------//

    // AXI TX
    //-----------
  .s_axis_tx_tdata          (s_axis_tx_tdata),          //  output
  .s_axis_tx_tvalid         (s_axis_tx_tvalid),         //  output
  .s_axis_tx_tready         (s_axis_tx_tready),         //  input
  .s_axis_tx_tkeep          (s_axis_tx_tkeep),          //  output
  .s_axis_tx_tlast          (s_axis_tx_tlast),          //  output
  .s_axis_tx_tuser          (s_axis_tx_tuser),          //  output

    // AXI RX
    //-----------
  .m_axis_rx_tdata          (m_axis_rx_tdata),          //  input
  .m_axis_rx_tvalid         (m_axis_rx_tvalid),         //  input
  .m_axis_rx_tready         (m_axis_rx_tready),         //  output
  .m_axis_rx_tkeep          (m_axis_rx_tkeep),          //  input
  .m_axis_rx_tlast          (m_axis_rx_tlast),          //  input
  .m_axis_rx_tuser          (m_axis_rx_tuser),          //  input


  //---------------------------------------------//
  // PCIe Block I/O                              //
  //---------------------------------------------//

    // TRN TX
    //-----------
  .trn_td                   (trn_td),                   //  input
  .trn_tsof                 (~trn_tsof_n),              //  input
  .trn_teof                 (~trn_teof_n),              //  input
  .trn_tsrc_rdy             (~trn_tsrc_rdy_n),          //  input
  .trn_tdst_rdy             (trn_tdst_rdy),             //  output
  .trn_tsrc_dsc             (~trn_tsrc_dsc_n),          //  input
  .trn_trem                 (~trn_trem_n),              //  input
  .trn_terrfwd              (0),                        //  input
  .trn_tstr                 (~trn_tstr_n),              //  input

    // TRN RX
    //-----------
  .trn_rd                   (trn_rd),                   //  output
  .trn_rsof                 (trn_rsof),                 //  output
  .trn_reof                 (trn_reof),                 //  output
  .trn_rsrc_rdy             (trn_rsrc_rdy),             //  output
  .trn_rdst_rdy             (~trn_rdst_rdy_n),          //  input
  .trn_rsrc_dsc             (trn_rsrc_dsc),             //  output
  .trn_rrem                 (trn_rrem),                 //  output
  .trn_rbar_hit             (trn_rbar_hit),             //  output
  .trn_lnk_up               (user_lnk_up),              //  input


    // System
    //-----------
  .user_clk                 (user_clk),                 //  input
  .user_rst                 (user_reset)                //  input

);

endmodule // pcie_app_s6

