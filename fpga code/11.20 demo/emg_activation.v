// =============================================================================
// emg_activation.v  -  compares the EMG envelopes against the gesture thresholds
//
// Three sensors are used for classification (from the team's sensor study):
//   EMG1 = A0  6:30 position  flexor mass
//   EMG2 = A1  12:00 position dorsal extensors
//   EMG3 = A2  5:00 position  ulnar border
//   EMG4 = reserved (scanned, filtered and logged, not used to classify)
//
// Output lvl[3:0] = one bit per threshold:
//   lvl[0]  A0 > 0.46 V    flexors working hard        (FIST / POINT)
//   lvl[1]  A1 > 0.32 V    any activity at all         (not REST)
//   lvl[2]  A1 > 0.73 V    strong extensor activity    (FIST vs POINT)
//   lvl[3]  A2 > 0.61 V    ulnar-border activity       (OPEN vs PINCH)
//
// Each bit has hysteresis: it turns on at THR and off only below THR - HYST,
// so a signal sitting on a threshold can't make the output chatter.
//
// >>> CALIBRATION: thresholds from one person, 2 sessions, 16 repetitions,
// >>> 23,071 samples, recorded on an Arduino. Codes assume a 3.3 V ADC
// >>> reference: code = V * 4095 / 3.3. The MyoWare gain pots must match the
// >>> settings used in that study. Re-check with more people before T3.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module emg_activation (
    input  wire        clk,            // 12 MHz system clock
    input  wire        rst,            // synchronous reset (all threshold bits low = REST)
    input  wire [47:0] emg_filt,       // 4 smoothed EMG values: [0] A0 [1] A1 [2] A2 [3] reserved
    input  wire        filt_vld,       // new values available; compare against thresholds
    output reg  [3:0]  lvl,            // threshold bits: [0] A0>0.46 [1] A1>0.32 [2] A1>0.73 [3] A2>0.61
    output reg         lvl_vld,        // one-clock pulse: lvl has been updated
    output reg         cross_stb       // one-clock pulse when any bit turns on (scope, T1 start)
);

    // ---- CALIBRATION VALUES (from sensor study) ------------------------------
    localparam [11:0] A0_HI = 12'd571;   // 0.46 V  flexor mass
    localparam [11:0] A1_LO = 12'd397;   // 0.32 V  dorsal extensors, lower
    localparam [11:0] A1_HI = 12'd906;   // 0.73 V  dorsal extensors, upper
    localparam [11:0] A2_HI = 12'd757;   // 0.61 V  ulnar border
    localparam [11:0] HYST  = 12'd40;    // ~0.03 V turn-off band below each threshold
    // --------------------------------------------------------------------------

    wire [11:0] a0 = emg_filt[12*0 +: 12];
    wire [11:0] a1 = emg_filt[12*1 +: 12];
    wire [11:0] a2 = emg_filt[12*2 +: 12];

    // value and threshold for each bit
    wire [47:0] val = {a2,    a1,    a1,    a0   };
    wire [47:0] thr = {A2_HI, A1_HI, A1_LO, A0_HI};

    reg  [3:0] lvl_nxt;
    integer k;
    always @* begin
        for (k = 0; k < 4; k = k + 1) begin
            if (!lvl[k]) lvl_nxt[k] = (val[12*k +: 12] >= thr[12*k +: 12]);
            else         lvl_nxt[k] = (val[12*k +: 12] >= thr[12*k +: 12] - HYST);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            lvl       <= 4'd0;
            lvl_vld   <= 1'b0;
            cross_stb <= 1'b0;
        end else begin
            lvl_vld   <= filt_vld;
            cross_stb <= 1'b0;
            if (filt_vld) begin
                lvl       <= lvl_nxt;
                cross_stb <= |(lvl_nxt & ~lvl);
            end
        end
    end

endmodule

`default_nettype wire
