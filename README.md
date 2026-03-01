# 16-Bit Pipelined Floating-Point Multiplier in Verilog

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository contains the Verilog source code for a high-performance, 16-bit half-precision floating-point multiplier. The design is fully pipelined and includes a comprehensive self-checking testbench for verification.

***

## Key Features 🎯

* **3-Stage Pipelined Architecture**: The multiplier breaks the logic into three smaller stages (Decode/Multiply, Normalize, Round/Assemble) to increase throughput. It has a 3-cycle latency but allows a new operation to begin every clock cycle.
* **Overflow & Underflow Detection**: The module includes robust logic to detect when the result is too large (overflow) or too small (underflow) to be represented. The result is clamped to infinity or zero, and corresponding flags are set.
* **High-Accuracy Rounding**: Implements a precise "**Round to Nearest, Tie to Even**" rounding scheme to minimize numerical error, offering better accuracy than simple truncation.
* **Self-Checking Testbench**: The included testbench automatically verifies the multiplier's output against a set of predefined expected results. It reports a `[PASS]` or `[FAIL]` status for each test case, making verification straightforward.

***

## Hardware Design (RTL) ⚙️

The core of this project is the `FloatingPoint_Multiplier_Complete.v` module. It implements the multiplier based on the **16-bit half-precision floating-point format** (1-bit sign, 5-bit exponent, 10-bit mantissa).

The operation is divided into three pipeline stages:

1.  **Stage 1: Decode & Multiply**: This stage deconstructs the two 16-bit inputs (`a` and `b`) into their sign, exponent, and mantissa components. It performs the initial multiplication of the mantissas and calculates the new sign and exponent.
2.  **Stage 2: Normalize**: The product from Stage 1 is normalized. If the most significant bit of the product is set, the mantissa is shifted right and the exponent is incremented to bring the result back into the standard `1.xxx` format.
3.  **Stage 3: Round & Assemble**: This final stage applies the "Round to Nearest, Tie to Even" logic to the normalized mantissa. It also performs the final overflow and underflow checks. Finally, it assembles the sign, exponent, and mantissa into the final 16-bit result.

***

## How to Simulate 💻

This project was originally developed and verified using **Xilinx Vivado**, but it's written in standard Verilog and should be compatible with most simulators.

1.  **Get a Verilog Simulator**: You can use any standard Verilog simulator, such as Icarus Verilog (open-source), ModelSim, or the simulators included with Vivado or Quartus.
2.  **Compile the Files**: Compile both `FloatingPoint_Multiplier_Complete.v` and `self_checking_tb.v`.
3.  **Run the Simulation**: Set `tb_FloatingPoint_Multiplier_Complete_SelfCheck` as the top-level module for the simulation and run it. The testbench will automatically execute the test sequence and print the results to the console.

***

## License 📜

This project is licensed under the **MIT License**.
