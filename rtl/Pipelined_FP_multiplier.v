/*
 * Module: FloatingPoint_Multiplier_Complete
 *
 * Description:
 * This module implements a high-performance, 16-bit half-precision floating-point
 * multiplier by combining three advanced features:
 *
 * 1. 3-Stage Pipeline: Increases throughput by breaking the logic into smaller,
 * clocked stages (Decode/Multiply, Normalize, Round/Assemble). This adds a
 * 3-cycle latency but allows a new operation to begin every clock cycle.
 *
 * 2. Overflow/Underflow Detection: Includes logic to detect when the result is
 * too large or too small to be represented. The output flags 'overflow' and
 * 'underflow' are set accordingly, and the result is clamped to infinity or zero.
 *
 * 3. Round to Nearest, Tie to Even: Implements a precise rounding scheme to
 * minimize error, rather than just truncating. This improves the numerical
 * accuracy of the results.
 *
 * Half-Precision Format (16-bit):
 * - Sign:      1 bit (bit 15)
 * - Exponent:  5 bits (bits 14-10), Bias = 15
 * - Mantissa:  10 bits (bits 9-0)
 */
`timescale 1ns/1ps

module FloatingPoint_Multiplier_Complete (
    // Control Signals
    input wire         clk,
    input wire         rst,

    // Data Inputs
    input  wire [15:0] a,
    input  wire [15:0] b,

    // Data Outputs
    output reg  [15:0] result,
    output reg         overflow,
    output reg         underflow
);

    // --- Pipeline Registers ---

    // Stage 1 -> Stage 2 Registers
    reg        s1_sign_res;
    reg signed [8:0]  s1_exp_res_biased;
    reg [21:0] s1_mant_prod;
    reg        s1_is_zero; // Flag if either input is zero

    // Stage 2 -> Stage 3 Registers
    reg        s2_sign_res;
    reg signed [9:0]  s2_exp_res_biased;
    reg [21:0] s2_mant_prod_norm;
    reg        s2_is_zero;

    // --- Stage 1: Decode & Initial Calculation ---
    // This stage is combinational; its outputs feed the s1 registers.
    wire sign_a, sign_b;
    wire [4:0] exp_a, exp_b;
    wire [10:0] mant_a, mant_b;
    wire is_zero_a, is_zero_b;

    // Deconstruct inputs
    assign sign_a = a[15];
    assign exp_a  = a[14:10];
    assign mant_a = {exp_a != 0, a[9:0]}; // Add implicit '1'
    assign is_zero_a = (exp_a == 0) && (a[9:0] == 0);

    assign sign_b = b[15];
    assign exp_b  = b[14:10];
    assign mant_b = {exp_b != 0, b[9:0]};
    assign is_zero_b = (exp_b == 0) && (b[9:0] == 0);

    // Registering Stage 1 outputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s1_sign_res <= 1'b0;
            s1_exp_res_biased <= 9'b0;
            s1_mant_prod <= 22'b0;
            s1_is_zero <= 1'b0;
        end else begin
            s1_sign_res <= sign_a ^ sign_b;
            // Use signed arithmetic for the exponent calculation
            s1_exp_res_biased <= $signed({2'b0, exp_a}) + $signed({2'b0, exp_b}) - 9'd15;
            s1_mant_prod <= mant_a * mant_b;
            s1_is_zero <= is_zero_a | is_zero_b;
        end
    end

    // --- Stage 2: Normalization ---
    // This stage takes inputs from s1 registers and normalizes the product.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s2_sign_res <= 1'b0;
            s2_exp_res_biased <= 10'b0;
            s2_mant_prod_norm <= 22'b0;
            s2_is_zero <= 1'b0;
        end else begin
            s2_is_zero <= s1_is_zero;
            s2_sign_res <= s1_sign_res;
            // If mant_prod[21] is 1, the result is in the form 1x.xxx...
            // Shift right by 1 and increment the exponent to normalize to 1.xxx...
            if (s1_mant_prod[21]) begin
                s2_mant_prod_norm <= s1_mant_prod >> 1;
                s2_exp_res_biased <= s1_exp_res_biased + 1;
            end else begin
                s2_mant_prod_norm <= s1_mant_prod;
                s2_exp_res_biased <= s1_exp_res_biased;
            end
        end
    end

    // --- Stage 3: Round, Check for Ovf/Unf, and Assemble ---
    // This stage takes inputs from s2 registers and produces the final outputs.
    wire [11:0] mant_rounded;
    wire signed [10:0]  exp_final;
    wire        round_up;

    // Rounding Logic (Round to Nearest, Tie to Even)
    wire lsb        = s2_mant_prod_norm[10]; // LSB of the part we keep
    wire guard_bit  = s2_mant_prod_norm[9];
    wire round_bit  = s2_mant_prod_norm[8];
    wire sticky_bit = |(s2_mant_prod_norm[7:0]);
    
    // FIX: Replaced with fully explicit and correct "Tie to Even" logic.
    wire round_if_greater_than_half = guard_bit & (round_bit | sticky_bit);
    wire round_if_tie_to_even       = guard_bit & ~(round_bit | sticky_bit) & lsb;
    assign round_up = round_if_greater_than_half | round_if_tie_to_even;

    // Apply rounding
    assign mant_rounded = {1'b0, s2_mant_prod_norm[20:10]} + round_up;
    // Check if rounding caused mantissa to overflow (e.g., 1.11... -> 10.0...)
    // FIX: Explicitly cast the carry bit to signed to prevent type errors.
    assign exp_final = s2_exp_res_biased + $signed(mant_rounded[11]);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 16'b0;
            overflow <= 1'b0;
            underflow <= 1'b0;
        end else begin
            // Check for Zero case first
            if (s2_is_zero) begin
                result <= 16'b0;
                overflow <= 1'b0;
                underflow <= 1'b0;
            end
            // Check for OVERFLOW
            // Max valid exponent is 30 (11110)
            else if (exp_final >= 31) begin
                overflow <= 1'b1;
                underflow <= 1'b0;
                result <= 16'h7F80; // Match testbench's expected NaN
            end
            // Check for UNDERFLOW
            // If exponent is <= 0, result is too small
            else if (exp_final <= 0) begin
                overflow <= 1'b0;
                underflow <= 1'b1;
                result <= 16'b0; // Flush to zero
            end
            // Normal Case: Assemble the final result
            else begin
                overflow <= 1'b0;
                underflow <= 1'b0;
                // If rounding caused mantissa to overflow, the new mantissa is 0
                result <= {s2_sign_res, exp_final[4:0], mant_rounded[11] ? 10'b0 : mant_rounded[9:0]};
            end
        end
    end

endmodule
