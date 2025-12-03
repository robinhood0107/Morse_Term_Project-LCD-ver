module Morse_Transceiver_Top(
    input wire iCLK,          // 50MHz Clock
    input wire [4:0] KEY,     // Push Buttons (Active Low usually) - KEY[4]: TX Buffer Clear(#)
    input wire [17:0] SW,     // DIP Switches
    output wire [6:0] SEG,    // 7-Segment segment lines a~g (Active Low, 공통 사용)
    output wire       SEG_DP, // 7-Segment decimal point (h) - 여기서는 항상 OFF
    output wire [7:0] SEG_EN, // 8 Digit 공통 단자 (Active Low: 선택 자리만 0)
    output wire [6:0] SEG_SINGLE, // Single 7-Segment display a~g (for current char browsing)
    output wire       SEG_SINGLE_DP, // Single 7-Segment decimal point h
    output wire [0:0] LEDG,   // TX Output LED
    output wire oBuzzer       // Piezo Buzzer Output
);

    // Internal Wires
    wire rst;
    wire is_tx_mode;
    wire [3:0] sec, half_sec; // Timing signals
    
    // TX Signals
    wire [4:0] tx_current_char_idx; // Currently selected char index
    wire [39:0] tx_display_data;    // Data to show on HEX (8 chars buffer)
    wire tx_led_out;
    
    // RX Signals
    wire [39:0] rx_display_data;    // Decoded text to show on HEX (8 chars buffer)
    wire rx_buzzer_out;

    // Assignments based on Proposal
    assign is_tx_mode = SW[0]; // SW1: Mode Select (1: TX, 0: RX)
    assign rst = SW[2];        // SW3: Reset (Active High)

    // 1. Clock Divider Module
    // Generates 1Hz and 2Hz timing signals from 50MHz clock
    Clock_Divider clk_div(
        .iCLK(iCLK),
        .iRST(rst),
        .oSec(sec),
        .oHalfSec(half_sec)
    );

    // 2. TX Module (Transmitter)
    TX_Module tx_inst(
        .iCLK(iCLK),
        .iRST(rst),
        .iEnable(is_tx_mode),    // Enable only in TX mode
        .iKEY(KEY),              // KEY inputs for control
        .iHalfSec(half_sec),     // Timing for Morse output
        .oCurrentChar(tx_current_char_idx), // Index of char being selected
        .oDisplayData(tx_display_data),     // Buffer content to display
        .oLED(tx_led_out)        // Morse Code LED Output
    );

    // 3. RX Module (Receiver)
    RX_Module rx_inst(
        .iCLK(iCLK),
        .iRST(rst),
        .iEnable(!is_tx_mode),   // Enable only in RX mode
        .iKEY(KEY),              // KEY inputs for Dot/Dash
        .oDisplayData(rx_display_data), // Decoded text
        .oBuzzer(rx_buzzer_out)  // Buzzer sound
    );

    // 4. Output MUX & Display Logic
    // Switch outputs based on Mode
    assign LEDG[0] = (is_tx_mode) ? tx_led_out : 1'b0;
    assign oBuzzer = (!is_tx_mode) ? rx_buzzer_out : 1'b0;

    // 7-Segment Output Logic (8 Digit Array, Scanning 방식)
    // RX mode: rx_display_data[39:0] 전체 8글자 사용
    // TX mode: tx_display_data[39:0] 전체 8글자 사용
    wire [4:0] char0, char1, char2, char3, char4, char5, char6, char7;
    wire [39:0] buffer_data;

    // 공통 8자리(0~7)는 buffer_data로부터 선택
    assign buffer_data = (is_tx_mode) ? tx_display_data : rx_display_data[39:0];

    assign char0 = buffer_data[4:0];
    assign char1 = buffer_data[9:5];
    assign char2 = buffer_data[14:10];
    assign char3 = buffer_data[19:15];
    assign char4 = buffer_data[24:20];
    assign char5 = buffer_data[29:25];
    assign char6 = buffer_data[34:30];
    assign char7 = buffer_data[39:35];

    // 8 Digit 7-Segment Array 드라이버
    SevenSeg_Array_Driver seg_array_inst (
        .iCLK(iCLK),
        .iRST(rst),
        .char0(char0),
        .char1(char1),
        .char2(char2),
        .char3(char3),
        .char4(char4),
        .char5(char5),
        .char6(char6),
        .char7(char7),
        .oSEG(SEG),
        .oDIGIT(SEG_EN)
    );

    // 소수점은 사용하지 않으므로 항상 OFF (Active Low 기준 1)
    assign SEG_DP = 1'b1;

    // Single 7-Segment Display: TX 모드에서 현재 선택 중인 문자 표시
    // 표준 7-Segment 구성: a, b, c, d, e, f, g (데이터), h (소수점)
    wire [6:0] single_seg_out;
    Seven_Seg_Decoder single_seg_dec (
        .iData(tx_current_char_idx),
        .oSeg(single_seg_out)
    );
    assign SEG_SINGLE = (is_tx_mode) ? single_seg_out : 7'b1111111; // TX 모드일 때만 표시 (a~g)
    assign SEG_SINGLE_DP = 1'b1; // 소수점(h)은 사용하지 않으므로 항상 OFF (Active Low 기준 1)

endmodule