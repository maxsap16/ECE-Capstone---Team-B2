// =============================================================================
// emg_activation.v  -  per-muscle on/off detection with hysteresis
//
// A channel turns ON when its filtered envelope rises to THR_ON and turns OFF
// only when it falls below THR_OFF (< THR_ON), so noise near one threshold
// can't make it chatter.
//
//   act[0] main flexor   act[1] main extensor
//   act[2] thumb flexor  act[3] index extensor
//
// >>> CALIBRATION: THR_ON / THR_OFF are fixed values from the predetermined
// >>> calibration study, in filtered 12-bit ADC codes (0-4095 = 0-3.3 V).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module emg_activation (
    input  wire        clk,
    input  wire        rst,
    input  wire [47:0] emg_filt,
    input  wire        filt_vld,
    output reg  [3:0]  act,
    output reg         act_vld,
    output reg         cross_stb      // pulses when any channel turns ON (scope, T1)
);
    // ---- CALIBRATION VALUES (TBD from bench characterization) ----------------

    //                         EMG1   EMG2   EMG3   EMG4
    localparam [11:0] THR_ON_0  = 12'd1200, THR_ON_1  = 12'd1200,
                      THR_ON_2  = 12'd1200, THR_ON_3  = 12'd1200;
    localparam [11:0] THR_OFF_0 = 12'd900,  THR_OFF_1 = 12'd900,
                      THR_OFF_2 = 12'd900,  THR_OFF_3 = 12'd900;
    // --------------------------------------------------------------------------

    wire [47:0] thr_on  = {THR_ON_3,  THR_ON_2,  THR_ON_1,  THR_ON_0 };
    wire [47:0] thr_off = {THR_OFF_3, THR_OFF_2, THR_OFF_1, THR_OFF_0};

    reg  [3:0] act_nxt;
    integer k;
    always @* begin
        for (k = 0; k < 4; k = k + 1) begin
            if (!act[k])
                act_nxt[k] = (emg_filt[12*k +: 12] >= thr_on [12*k +: 12]);
            else
                act_nxt[k] = (emg_filt[12*k +: 12] >= thr_off[12*k +: 12]);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            act       <= 4'd0;
            act_vld   <= 1'b0;
            cross_stb <= 1'b0;
        end else begin
            act_vld   <= filt_vld;
            cross_stb <= 1'b0;
            if (filt_vld) begin
                act       <= act_nxt;
                cross_stb <= |(act_nxt & ~act);
            end
        end
    end

endmodule
