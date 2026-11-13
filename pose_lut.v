// =============================================================================
// pose_lut.v  -  gesture -> target pulse width for each servo
//
// Output packing: pose_us = {servo2, servo1, servo0}, 12 bits each, in us.
//   servo0 = thumb;    servo1 = index;    servo2 = middle/ring/pinky
//
// >>> CALIBRATION: pulse widths are placeholders. Convention used here is
// >>> 1000 us = finger extended (open), 2000 us = finger flexed (closed);
// >>> servo_pwm clamps every value to that servo's hard limits regardless.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module pose_lut (
    input  wire [2:0]  gesture,
    output reg  [35:0] pose_us
);

    localparam [2:0] G_REST = 3'd0, G_OPEN = 3'd1, G_FIST = 3'd2,
                     G_PINCH = 3'd3, G_POINT = 3'd4;

    // ---- CALIBRATION VALUES (TBD on bench) -----------------------------------
    //                           servo2     servo1     servo0
    localparam [35:0] P_REST  = {12'd1200,  12'd1200,  12'd1200};  //fully relaxed
    localparam [35:0] P_OPEN  = {12'd1000,  12'd1000,  12'd1000};
    localparam [35:0] P_FIST  = {12'd2000,  12'd2000,  12'd1900};
    localparam [35:0] P_PINCH = {12'd1000,  12'd1800,  12'd1800};
    localparam [35:0] P_POINT = {12'd2000,  12'd1000,  12'd1800};
    // --------------------------------------------------------------------------

    always @* begin
        case (gesture)
            G_OPEN:  pose_us = P_OPEN;
            G_FIST:  pose_us = P_FIST;
            G_PINCH: pose_us = P_PINCH;
            G_POINT: pose_us = P_POINT;
            default: pose_us = P_REST;     //REST and any other outside cases
        endcase
    end

endmodule

`default_nettype wire
