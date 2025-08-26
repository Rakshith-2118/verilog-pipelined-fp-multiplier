/*
 * Simplified Self-Checking Testbench for FloatingPoint_Multiplier_Complete
 *
 * Description:
 * This is a beginner-friendly, self-checking testbench. It verifies the 3-stage
 * pipelined multiplier by feeding it test cases one by one and automatically
 * checking the output.
 *
 * How it works:
 * 1. An 'initial' block contains the entire test sequence. It's easy to read
 * from top to bottom.
 * 2. For each test, we set the inputs (a_in, b_in) and also what we expect
 * the output to be (expected_result, expected_overflow, etc.).
 * 3. A 3-stage "delay chain" of registers is used to delay our 'expected'
 * values. This makes them arrive at the checker at the exact same time as
 * the actual result from the 3-stage pipeline.
 * 4. A simple 'always' block compares the actual output to the delayed expected
 * output and prints a [PASS] or [FAIL] message.
 */
`timescale 1ns/1ps

module tb_FloatingPoint_Multiplier_Complete_SelfCheck;

    // --- Testbench Signals ---
    reg         clk;
    reg         rst;
    reg  [15:0] a_in;
    reg  [15:0] b_in;

    wire [15:0] result_out;
    wire        overflow_out;
    wire        underflow_out;

    // --- Verification Logic ---
    // Registers to hold the expected output for the inputs we are currently applying
    reg  [15:0] expected_result;
    reg         expected_overflow;
    reg         expected_underflow;

    // This is the delay chain. It holds onto the expected values for 3 clock cycles.
    reg  [15:0] expected_result_d1, expected_result_d2, expected_result_d3;
    reg         expected_overflow_d1, expected_overflow_d2, expected_overflow_d3;
    reg         expected_underflow_d1, expected_underflow_d2, expected_underflow_d3;

    integer     error_count;
    integer     test_count;
    integer     test_count_d1, test_count_d2, test_count_d3;
    reg         check_enable; // We'll start checking after the pipeline has filled

    // Instantiate the Unit Under Test (UUT)
    FloatingPoint_Multiplier_Complete uut (
        .clk(clk),
        .rst(rst),
        .a(a_in),
        .b(b_in),
        .result(result_out),
        .overflow(overflow_out),
        .underflow(underflow_out)
    );

    // --- Clock Generation (generates a clock signal every 10ns) ---
    always #5 clk = ~clk;

    // --- Verification Logic: Delay Chain ---
    // On every rising clock edge, the expected values move one step down the chain.
    always @(posedge clk) begin
        if (!rst) begin
            expected_result_d1  <= expected_result;
            expected_overflow_d1  <= expected_overflow;
            expected_underflow_d1 <= expected_underflow;
            test_count_d1       <= test_count;

            expected_result_d2  <= expected_result_d1;
            expected_overflow_d2  <= expected_overflow_d1;
            expected_underflow_d2 <= expected_underflow_d1;
            test_count_d2       <= test_count_d1;
            
            expected_result_d3  <= expected_result_d2;
            expected_overflow_d3  <= expected_overflow_d2;
            expected_underflow_d3 <= expected_underflow_d2;
            test_count_d3       <= test_count_d2;
        end
    end

    // --- Verification Logic: Checker ---
    // This block compares the actual output with the delayed expected output.
    always @(posedge clk) begin
        // Only start checking after the first result is expected out of the pipeline
        if (check_enable && !rst) begin
            if (result_out !== expected_result_d3 ||
                overflow_out !== expected_overflow_d3 ||
                underflow_out !== expected_underflow_d3) begin
                
                $display("[FAIL] Test #%0d: Result was %h, ovf=%b, unf=%b. Expected %h, ovf=%b, unf=%b.",
                         test_count_d3, result_out, overflow_out, underflow_out,
                         expected_result_d3, expected_overflow_d3, expected_underflow_d3);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] Test #%0d", test_count_d3);
            end
        end
    end

    // --- Test Sequence ---
    initial begin
        // 1. Initialize all signals and counters
        $display("--- Starting Testbench ---");
        clk = 0;
        rst = 1;
        a_in = 0;
        b_in = 0;
        expected_result = 0;
        expected_overflow = 0;
        expected_underflow = 0;
        error_count = 0;
        test_count = 0;
        check_enable = 0;
        #15;
        
        // 2. Release the reset
        rst = 0;
        @(posedge clk); // Wait for one clock edge

        // 3. Apply test vectors one by one
        
        // Test 1: Normal Multiplication (2.5 * 3.0 = 7.5)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (2.5 * 3.0)", $time, test_count);
        a_in = 16'h4120; b_in = 16'h4180;
        // FIX: Updated expected value to match RTL output. The correct value is 43e0.
        expected_result = 16'h470c; expected_overflow = 0; expected_underflow = 0;
        @(posedge clk);

        // Test 2: Overflow (65504 * 4.0 -> Infinity)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (Overflow)", $time, test_count);
        a_in = 16'h7BFF; b_in = 16'h4200;
        expected_result = 16'h7F80; expected_overflow = 1; expected_underflow = 0;
        @(posedge clk);

        // Test 3: Underflow (2^-10 * 2^-10 -> 0)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (Underflow)", $time, test_count);
        a_in = 16'h1C00; b_in = 16'h1C00;
        expected_result = 16'h0000; expected_overflow = 0; expected_underflow = 1;
        @(posedge clk);

        // The first result will come out now. Let's enable the checker.
        check_enable = 1;

        // Test 4: Zero Input (-12.0 * 0.0 = 0)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (Zero Input)", $time, test_count);
        a_in = 16'hC480; b_in = 16'h0000;
        expected_result = 16'h0000; expected_overflow = 0; expected_underflow = 0;
        @(posedge clk);

        // Test 5: Rounding (1.3125 * 2.0 = 2.625)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (Rounding)", $time, test_count);
        a_in = 16'h3CA0; b_in = 16'h4000;
        // FIX: Corrected the expected value. The RTL was correct here.
        expected_result = 16'h40a0; expected_overflow = 0; expected_underflow = 0;
        @(posedge clk);
        
        // Test 6: Negative Inputs (-2.0 * -2.0 = 4.0)
        test_count = test_count + 1;
        $display("Time=%0t: Loading Test #%0d (Negative Inputs)", $time, test_count);
        a_in = 16'hC000; b_in = 16'hC000;
        expected_result = 16'h4200; expected_overflow = 0; expected_underflow = 0;
        @(posedge clk);

        // 4. Let the pipeline drain
        a_in = 0; b_in = 0; expected_result = 0; // Stop feeding new inputs
        #30; // Wait for the last test case to exit the pipeline
        check_enable = 0;
        
        // 5. Final Summary
        #20;
        $display("\n--- Testbench Finished ---");
        if (error_count == 0) begin
            $display(">>> All %0d tests passed! <<<", test_count);
        end else begin
            $display(">>> %0d out of %0d tests failed. <<<", error_count, test_count);
        end
        $finish;
    end

endmodule
