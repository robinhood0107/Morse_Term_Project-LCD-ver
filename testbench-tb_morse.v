`timescale 1ns/1ps

// ----------------------
// 7-Segment Viewer (simulation only, for 8-digit common SEG line)
// ----------------------
module Seven_Seg_Viewer(
    input  wire [6:0] seg,   // common SEG(a~g) lines (Active Low)
    output reg  [4:0] idx    // 0~25: A~Z, 31: OFF/Unknown
);
    always @(*) begin
        case (seg)
            7'b0001000: idx = 5'd0;  // A
            7'b0000011: idx = 5'd1;  // B
            7'b1000110: idx = 5'd2;  // C
            7'b0100001: idx = 5'd3;  // D
            7'b0000110: idx = 5'd4;  // E
            7'b0001110: idx = 5'd5;  // F
            7'b0010000: idx = 5'd6;  // G
            7'b0001001: idx = 5'd7;  // H
            7'b1001111: idx = 5'd8;  // I
            7'b1110001: idx = 5'd9;  // J
            7'b0000101: idx = 5'd10; // K
            7'b1000111: idx = 5'd11; // L
            7'b0101010: idx = 5'd12; // M
            7'b1001000: idx = 5'd13; // N
            7'b0000001: idx = 5'd14; // O
            7'b0001100: idx = 5'd15; // P
            7'b0011000: idx = 5'd16; // Q
            7'b1111010: idx = 5'd17; // R
            7'b0010010: idx = 5'd18; // S
            7'b0000111: idx = 5'd19; // T
            7'b1000001: idx = 5'd20; // U
            7'b1000001: idx = 5'd21; // V (same as U)
            7'b1010101: idx = 5'd22; // W
            7'b0110110: idx = 5'd23; // X
            7'b0010001: idx = 5'd24; // Y
            7'b0100100: idx = 5'd25; // Z
            7'b1111111: idx = 5'd31; // OFF
            default    : idx = 5'd31;
        endcase
    end
endmodule

// ----------------------
// Top Testbench
// ----------------------
module tb_morse;

    reg        iCLK;
    reg [4:0]  KEY;
    reg [17:0] SW;
    wire [6:0] SEG;
    wire       SEG_DP;
    wire [7:0] SEG_EN;
    wire [0:0] LEDG;
    wire       oBuzzer;

    // Output from 7-seg viewer: current scanned digit character index
    wire [4:0] cur_char_idx;

    // Tap internal 8 character indices from DUT for easier observation
    wire [4:0] d0 = dut.char0;
    wire [4:0] d1 = dut.char1;
    wire [4:0] d2 = dut.char2;
    wire [4:0] d3 = dut.char3;
    wire [4:0] d4 = dut.char4;
    wire [4:0] d5 = dut.char5;
    wire [4:0] d6 = dut.char6;
    wire [4:0] d7 = dut.char7;

    // Convert character index (0~25,31) to ASCII letter/space (simulation only)
    function [7:0] ascii_from_idx;
        input [4:0] idx;
        begin
            if (idx <= 5'd25) begin
                ascii_from_idx = "A" + idx[4:0];
            end else begin
                ascii_from_idx = " ";
            end
        end
    endfunction

    // DUT instance
    Morse_Transceiver_Top dut (
        .iCLK(iCLK),
        .KEY(KEY),
        .SW(SW),
        .SEG(SEG),
        .SEG_DP(SEG_DP),
        .SEG_EN(SEG_EN),
        .LEDG(LEDG),
        .oBuzzer(oBuzzer)
    );

    // 7-seg viewer instance (connected to common SEG lines)
    // In the waveform, if you also watch SEG_EN:
    //  - SEG_EN = 1111_1110 -> cur_char_idx is Digit0
    //  - SEG_EN = 1111_1101 -> cur_char_idx is Digit1
    Seven_Seg_Viewer v0(.seg(SEG), .idx(cur_char_idx));

    // ----------------------
    // Periodically print the 8-character contents as a string
    // ----------------------
    integer disp_cnt;
    always @(posedge iCLK) begin
        disp_cnt <= disp_cnt + 1;
        // Periodically (every N cycles) print current 8-character string
        if (disp_cnt == 100) begin
            disp_cnt <= 0;
            $display("[%0t] 7SEG = \"%s%s%s%s%s%s%s%s\"  (d7..d0)",
                     $time,
                     ascii_from_idx(d7),
                     ascii_from_idx(d6),
                     ascii_from_idx(d5),
                     ascii_from_idx(d4),
                     ascii_from_idx(d3),
                     ascii_from_idx(d2),
                     ascii_from_idx(d1),
                     ascii_from_idx(d0));
        end
    end

    // ----------------------
    // Helper tasks to generate key presses
    // ----------------------
    task press_key;
        input integer idx; // 0~4
        begin
            KEY[idx] = 1'b0;
            #100;
            KEY[idx] = 1'b1;
        end
    endtask

    // RX-side helper tasks (Dot/Dash/Confirm)
    task rx_dot;
        begin
            press_key(2); // KEY2: Dot
        end
    endtask

    task rx_dash;
        begin
            press_key(1); // KEY1: Dash
        end
    endtask

    task rx_confirm;
        begin
            press_key(3); // KEY3: Confirm/Next
        end
    endtask

    // Move selection to target character index using KEY0 (reset) and KEY1 (next)
    task select_char;
        input [4:0] target_idx; // 0~25 (A~Z)
        integer k;
        begin
            // First reset to 'A' with KEY0
            press_key(0); // Reset to A
            #500;
            // Then press KEY1 "target_idx" times to reach the desired letter
            for (k = 0; k < target_idx; k = k + 1) begin
                press_key(1); // Next
                #500;
            end
        end
    endtask

    // Select a specific character index and save to TX buffer with KEY2
    task save_char;
        input [4:0] target_idx;
        begin
            select_char(target_idx);
            #1000;
            press_key(2); // Save
            #1000;
        end
    endtask

    // Send one Morse character sequence to RX using KEY1/KEY2/KEY3
    // pattern: final stack bits as used in RX_Module decode tables
    // len    : number of symbols (1~4)
    task rx_send_morse;
        input [3:0] pattern;
        input integer len;
        integer i;
        begin
            // press symbols from MSB down to LSB so that final stack matches pattern
            for (i = len-1; i >= 0; i = i - 1) begin
                if (pattern[i])
                    rx_dash();
                else
                    rx_dot();
                #500;
            end
            rx_confirm();
            #1500;
        end
    endtask

    // 50MHz clock (20ns period)
    initial iCLK = 0;
    always #10 iCLK = ~iCLK;
    initial disp_cnt = 0;

    initial begin
        // Initial state
        SW  = 18'd0;
        KEY = 5'b11111;    // Active-Low → 1 means "not pressed"

        // Reset
        SW[2] = 1'b1;      // rst = 1
        #200;
        SW[2] = 1'b0;      // rst = 0

        // Enter TX mode
        SW[0] = 1'b1;      // is_tx_mode = 1

        // ----------------------
        // Scenario: save "HELLO" into TX buffer
        // ----------------------
        // H(7), E(4), L(11), L(11), O(14)
        #2000;
        save_char(5'd7);   // H
        save_char(5'd4);   // E
        save_char(5'd11);  // L
        save_char(5'd11);  // L
        save_char(5'd14);  // O

        // Wait so that buffer contents are clearly visible on 7SEG
        #10000;

        $display("===================================================");
        $display("[%0t] EXPECTED 7SEG (TX mode) : \"HELLO   \" (exact alignment depends on buffer shift)", $time);
        $display("Check the periodic \"7SEG = ...\" log above; it should contain HELLO.");
        $display("===================================================");

        // Optionally start TX send with KEY3
        press_key(3); // Send

        // Extra time to observe TX behaviour
        #200000;

        // ======================
        // RX test: enter "HELLO"
        // ======================
        // Switch to RX mode
        SW[0] = 1'b0;      // is_tx_mode = 0 (RX)
        #1000;

        // Optional: small reset pulse to clear RX buffers
        SW[2] = 1'b1;
        #200;
        SW[2] = 1'b0;
        #2000;

        // H(7): "...." -> pattern 4'b0000, len=4
        rx_send_morse(4'b0000, 4);
        // E(4): "."    -> pattern 4'b0000, len=1
        rx_send_morse(4'b0000, 1);
        // L(11): ".-.." -> pattern 4'b0100, len=4 (see RX_Module table)
        rx_send_morse(4'b0100, 4);
        // L(11) again
        rx_send_morse(4'b0100, 4);
        // O(14): "---"  -> pattern 3'b111, len=3
        rx_send_morse(4'b0111, 3);

        // Wait so that decoded buffer is visible on 7SEG
        #10000;

        $display("===================================================");
        $display("[%0t] EXPECTED 7SEG (RX mode) : \"HELLO   \" (depending on buffer alignment)", $time);
        $display("Check the periodic \"7SEG = ...\" log above; it should contain HELLO from RX as well.");
        $display("===================================================");

        // Extra time to observe both TX/RX results
        #500000;

        $stop;
    end

endmodule