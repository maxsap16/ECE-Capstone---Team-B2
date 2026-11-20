// =============================================================================
// gesture_fsm.v  -  decision tree from threshold bits to gesture
//
// 1. Decision tree (from the team's sensor study):
//        if A0 > 0.46 V:   FIST if A1 > 0.73 V, else POINT
//        elif A1 < 0.32 V: REST
//        else:             OPEN if A2 > 0.61 V, else PINCH
// 2. Persistence: the tree's answer must be the same for PERSIST frames.
// 3. Transitions: a change is allowed if either end is REST, plus two
//    "ramp-through" changes:  POINT -> FIST  and  PINCH -> OPEN.
//    While a fist builds up, A0 crosses its threshold before A1 reaches
//    0.73 V, so the tree briefly says POINT; likewise OPEN passes through
//    PINCH while A2 rises. These two upgrades let the gesture finish without
//    a full relax. The reverse directions stay blocked, so releasing a FIST
//    or OPEN goes back to REST instead of stopping at POINT or PINCH.
// hold_rest forces REST immediately (power-up settle or a safety fault).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module gesture_fsm #(
    parameter PERSIST = 5              // frames (ms) the answer must hold before the gesture changes
) (
    input  wire       clk,             // 12 MHz system clock
    input  wire       rst,             // synchronous reset (gesture = REST)
    input  wire [3:0] lvl,             // threshold bits from emg_activation
    input  wire       lvl_vld,         // new bits available; one classification step
    input  wire       hold_rest,       // force REST now: still settling after power-up, or a fault
    output reg  [2:0] gesture,         // 0 REST, 1 OPEN, 2 FIST, 3 PINCH, 4 POINT
    output reg        gesture_chg      // one-clock pulse when gesture changes (scope, logger)
);

    localparam [2:0] G_REST  = 3'd0,
                     G_OPEN  = 3'd1,
                     G_FIST  = 3'd2,
                     G_PINCH = 3'd3,
                     G_POINT = 3'd4;

    wire a0_hi = lvl[0];               // A0 > 0.46 V
    wire a1_lo = lvl[1];               // A1 > 0.32 V
    wire a1_hi = lvl[2];               // A1 > 0.73 V
    wire a2_hi = lvl[3];               // A2 > 0.61 V

    // ---- 1. decision tree -----------------------------------------------------
    reg [2:0] cand;
    always @* begin
        if (a0_hi)       cand = a1_hi ? G_FIST : G_POINT;
        else if (!a1_lo) cand = G_REST;
        else             cand = a2_hi ? G_OPEN : G_PINCH;
    end

    // ---- 3. allowed transitions -------------------------------------------------
    reg [2:0] cand_q;
    reg [7:0] persist_cnt;

    wire allowed = (gesture == G_REST) || (cand_q == G_REST) ||
                   (gesture == G_POINT && cand_q == G_FIST)  ||
                   (gesture == G_PINCH && cand_q == G_OPEN);

    // ---- 2. persistence and commit ----------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            gesture     <= G_REST;
            gesture_chg <= 1'b0;
            cand_q      <= G_REST;
            persist_cnt <= 8'd0;
        end else begin
            gesture_chg <= 1'b0;
            if (hold_rest) begin
                if (gesture != G_REST) gesture_chg <= 1'b1;
                gesture     <= G_REST;
                cand_q      <= G_REST;
                persist_cnt <= 8'd0;
            end else if (lvl_vld) begin
                if (cand != cand_q) begin
                    cand_q      <= cand;
                    persist_cnt <= 8'd1;
                end else if (persist_cnt < PERSIST) begin
                    persist_cnt <= persist_cnt + 1'b1;
                end
                // commit on the frame the count reaches PERSIST
                if (cand == cand_q && persist_cnt == PERSIST - 1 &&
                    cand_q != gesture && allowed) begin
                    gesture     <= cand_q;
                    gesture_chg <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
