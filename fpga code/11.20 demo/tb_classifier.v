// =============================================================================
// tb_classifier.v  -  testbench for the gesture classifier only
//                     (emg_activation.v + gesture_fsm.v)
//
// Feeds already-smoothed EMG envelopes straight into emg_activation, one
// "frame" at a time (on the glove a frame is 1 ms), and prints what the
// classifier does with them:
//
//   frame | A0 A1 A2 (V) | threshold bits | tree answer | committed gesture
//
// Voltages are written in volts and converted to 12-bit ADC codes
// (code = V * 4095 / 3.3), the same scale the hardware sees.
//
// Sections
//   1. each gesture at the study's median voltages
//   2. persistence: a 4-frame blip is ignored, 5 frames commits
//   3. a fast fist ramp (20 ms) and its release
//   4. a slow fist ramp (100 ms)
//   5. hysteresis around the A1 0.32 V threshold
//   6. hold_rest (power-up settle / fault) forces REST
//   7. overlap cases from the study's 5th/95th percentiles (informational:
//      shows which errors the thresholds will make, not counted as failures)
//
// Run (from the project folder):
//   iverilog -g2005 -o tbc tb/tb_classifier.v emg_activation.v gesture_fsm.v
//   vvp tbc
// Waveforms are written to tb_classifier.vcd (open in GTKWave or Vivado).
// =============================================================================
`timescale 1ns / 1ps

module tb_classifier;

    // ---- clock and DUTs -----------------------------------------------------
    reg clk = 0;
    always #41.667 clk = ~clk;                // 12 MHz

    reg         rst       = 1;
    reg  [47:0] emg_filt  = 0;
    reg         filt_vld  = 0;
    reg         hold_rest = 0;
    wire [3:0]  lvl;
    wire        lvl_vld, cross_stb;
    wire [2:0]  gesture;
    wire        gesture_chg;

    emg_activation u_act (
        .clk(clk), .rst(rst),
        .emg_filt(emg_filt), .filt_vld(filt_vld),
        .lvl(lvl), .lvl_vld(lvl_vld), .cross_stb(cross_stb)
    );

    gesture_fsm #(.PERSIST(5)) u_fsm (
        .clk(clk), .rst(rst),
        .lvl(lvl), .lvl_vld(lvl_vld), .hold_rest(hold_rest),
        .gesture(gesture), .gesture_chg(gesture_chg)
    );

    localparam REST = 0, OPEN = 1, FIST = 2, PINCH = 3, POINT = 4;

    // ---- helpers ---------------------------------------------------------------
    function [8*5-1:0] gname(input [2:0] g);
        case (g)
            REST:    gname = "REST ";
            OPEN:    gname = "OPEN ";
            FIST:    gname = "FIST ";
            PINCH:   gname = "PINCH";
            POINT:   gname = "POINT";
            default: gname = "?    ";
        endcase
    endfunction

    function [11:0] code(input real v);       // volts -> 12-bit ADC code
        code = v * 4095.0 / 3.3;
    endfunction

    integer nframe = 0;
    integer fails  = 0;
    reg     verbose = 0;                       // 1 = print every frame
    reg [2:0] last_cand, last_gest;
    real    a0, a1, a2;

    task print_row;
        $display("%5d | %4.2f %4.2f %4.2f |    %b      %b      %b      %b   | %s | %s%s",
                 nframe, a0, a1, a2, lvl[0], lvl[1], lvl[2], lvl[3],
                 gname(u_fsm.cand), gname(gesture),
                 (gesture != last_gest) ? "  <- committed" : "");
    endtask

    task header(input [8*80-1:0] title);
        begin
            $display("\n%0s", title);
            $display("      |  smoothed (V)  |       threshold bits        |       |");
            $display("frame |  A0   A1   A2  | A0>.46 A1>.32 A1>.73 A2>.61 | tree  | gesture");
            $display("------+----------------+-----------------------------+-------+--------");
        end
    endtask

    // one 1 ms frame: present smoothed values, pulse filt_vld, let it settle
    task frame(input real v0, input real v1, input real v2);
        begin
            a0 = v0; a1 = v1; a2 = v2;
            emg_filt = {code(0.30), code(v2), code(v1), code(v0)};   // EMG4 reserved
            @(negedge clk) filt_vld = 1;
            @(negedge clk) filt_vld = 0;
            repeat (4) @(negedge clk);
            nframe = nframe + 1;
            if (verbose || u_fsm.cand != last_cand || gesture != last_gest)
                print_row;
            last_cand = u_fsm.cand;
            last_gest = gesture;
        end
    endtask

    task hold(input real v0, input real v1, input real v2, input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) frame(v0, v1, v2);
    endtask

    // linear ramp between two voltage sets over n frames
    task ramp(input real s0, input real s1, input real s2,
              input real e0, input real e1, input real e2, input integer n);
        integer i;
        real f;
        for (i = 1; i <= n; i = i + 1) begin
            f = i * 1.0 / n;
            frame(s0 + f*(e0-s0), s1 + f*(e1-s1), s2 + f*(e2-s2));
        end
    endtask

    task expect(input [2:0] g, input [8*60-1:0] msg);
        if (gesture == g) $display("  PASS  %0s", msg);
        else begin
            $display("  FAIL  %0s  (got %0s, expected %0s)", msg, gname(gesture), gname(g));
            fails = fails + 1;
        end
    endtask

    task note(input [2:0] g, input [8*60-1:0] msg);   // informational, not a failure
        $display("  INFO  %0s -> classified %0s", msg, gname(gesture));
    endtask

    // study medians (V)                     A0    A1    A2
    task rest_;  hold(0.21, 0.23, 0.26, 10); endtask
    `define REST_V  0.21, 0.23, 0.26
    `define OPEN_V  0.22, 0.93, 1.15
    `define FIST_V  1.70, 1.20, 0.70
    `define PINCH_V 0.19, 0.82, 0.28
    `define POINT_V 0.83, 0.48, 0.58

    // ---- test sequence -------------------------------------------------------------
    initial begin
        $dumpfile("tb_classifier.vcd");
        $dumpvars(0, tb_classifier);
        last_cand = REST; last_gest = REST;
        repeat (5) @(negedge clk);
        rst = 0;

        // -------------------------------------------------------------------
        header("1. Each gesture at the study medians (10 frames each, REST between)");
        hold(`REST_V,  10);  expect(REST,  "REST medians -> REST");
        hold(`OPEN_V,  10);  expect(OPEN,  "OPEN medians -> OPEN");
        hold(`REST_V,  10);
        hold(`FIST_V,  10);  expect(FIST,  "FIST medians -> FIST");
        hold(`REST_V,  10);
        hold(`PINCH_V, 10);  expect(PINCH, "PINCH medians -> PINCH");
        hold(`REST_V,  10);
        hold(`POINT_V, 10);  expect(POINT, "POINT medians -> POINT");
        hold(`REST_V,  10);  expect(REST,  "back to REST");

        // -------------------------------------------------------------------
        header("2. Persistence (PERSIST = 5 frames), every frame shown");
        verbose = 1;
        hold(`FIST_V, 4);    expect(REST, "4-frame FIST blip ignored");
        hold(`REST_V, 3);
        hold(`FIST_V, 5);    expect(FIST, "5 frames of FIST commits");
        hold(`REST_V, 6);    expect(REST, "5 frames of REST commits");
        verbose = 0;

        // -------------------------------------------------------------------
        header("3. Fast fist ramp, REST -> FIST over 20 frames, then release");
        ramp(`REST_V, `FIST_V, 20);
        hold(`FIST_V, 5);    expect(FIST, "fast ramp ends in FIST (via POINT)");
        ramp(`FIST_V, `REST_V, 20);
        hold(`REST_V, 5);    expect(REST, "release passes POINT/PINCH, ends at REST");

        // -------------------------------------------------------------------
        header("4. Slow fist ramp, REST -> FIST over 100 frames");
        ramp(`REST_V, `FIST_V, 100);
        hold(`FIST_V, 5);    expect(FIST, "slow ramp ends in FIST");
        hold(`REST_V, 10);

        // -------------------------------------------------------------------
        header("5. Hysteresis on A1 0.32 V (turns off below ~0.288 V)");
        verbose = 1;
        hold(0.21, 0.34, 0.26, 6);  expect(PINCH, "A1 = 0.34 V -> above threshold");
        hold(0.21, 0.30, 0.26, 6);  expect(PINCH, "A1 = 0.30 V -> inside band, stays");
        hold(0.21, 0.27, 0.26, 6);  expect(REST,  "A1 = 0.27 V -> below band, REST");
        verbose = 0;

        // -------------------------------------------------------------------
        header("6. hold_rest (power-up settle or safety fault)");
        hold(`OPEN_V, 10);   expect(OPEN, "OPEN before hold_rest");
        hold_rest = 1;
        hold(`OPEN_V, 3);    expect(REST, "hold_rest forces REST immediately");
        hold_rest = 0;
        hold(`OPEN_V, 6);    expect(OPEN, "OPEN again after hold_rest released");
        hold(`REST_V, 10);

        // -------------------------------------------------------------------
        header("7. Overlap cases from the study's 5th / 95th percentiles");
        hold(0.83, 0.85, 0.58, 10);  note(POINT, "POINT with A1 at its 95th pct (0.85 V)");
        hold(`REST_V, 10);
        hold(1.70, 0.67, 0.70, 10);  note(FIST,  "FIST with A1 at its 5th pct (0.67 V)");
        hold(`REST_V, 10);
        hold(0.19, 0.82, 0.62, 10);  note(PINCH, "PINCH with A2 at its 95th pct (0.62 V)");
        hold(`REST_V, 10);
        hold(0.22, 0.93, 0.55, 10);  note(OPEN,  "OPEN with A2 at its 5th pct (0.55 V)");
        hold(`REST_V, 10);

        $display("\n==== %0d failure(s) ====\n", fails);
        $finish;
    end

endmodule
