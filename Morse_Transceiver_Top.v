module Morse_Transceiver_Top(
    input wire iCLK,          // 50MHz Clock
    input wire [4:0] KEY,     // Push Buttons (Active Low usually) - KEY[4]: TX Buffer Clear(#)
    input wire [17:0] SW,     // DIP Switches
    output wire [6:0] SEG,    // 7-Segment segment lines a~g (TX mode only)
    output wire       SEG_DP, // 7-Segment decimal point (h) - 여기서는 항상 OFF
    output wire [7:0] SEG_EN, // 8 Digit 공통 단자 (TX mode only)
    output wire [6:0] SEG_SINGLE, // Single 7-Segment display a~g (for current char browsing)
    output wire       SEG_SINGLE_DP, // Single 7-Segment decimal point h
    output wire [7:0] TLCD_D,  // Text LCD Data bus (D7~D0) - RX mode only
    output wire       TLCD_E,  // Text LCD Enable
    output wire       TLCD_RS, // Text LCD Register Select
    output wire       TLCD_RW, // Text LCD Read/Write
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

    // 7-Segment Output Logic (TX mode only)
    // TX mode: tx_display_data[39:0] 전체 8글자 사용
    wire [4:0] char0, char1, char2, char3, char4, char5, char6, char7;

    assign char0 = tx_display_data[4:0];
    assign char1 = tx_display_data[9:5];
    assign char2 = tx_display_data[14:10];
    assign char3 = tx_display_data[19:15];
    assign char4 = tx_display_data[24:20];
    assign char5 = tx_display_data[29:25];
    assign char6 = tx_display_data[34:30];
    assign char7 = tx_display_data[39:35];

    // 8 Digit 7-Segment Array 드라이버 (TX mode only)
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

    // Text LCD Driver
    // Note: LCD 드라이버는 항상 동작하지만, iCharData는 rx_display_data로 연결되어 있음
    // RX 모드일 때만 rx_display_data가 업데이트되므로, TX 모드에서는 마지막 RX 데이터가 표시됨
    // 이는 의도된 동작이며, 모드 전환 시 LCD가 즉시 업데이트되지 않을 수 있음
    Text_LCD_Driver lcd_driver_inst (
        .iCLK(iCLK),
        .iRST(rst),
        .iCharData(rx_display_data),
        .oLCD_D(TLCD_D),
        .oLCD_E(TLCD_E),
        .oLCD_RS(TLCD_RS),
        .oLCD_RW(TLCD_RW)
    );

    // 소수점은 사용하지 않으므로 항상 OFF
    // 주의: 실제 하드웨어에 따라 Active Low 또는 Active High일 수 있습니다.
    // - Active Low인 경우: 1 = OFF, 0 = ON
    // - Active High인 경우: 0 = OFF, 1 = ON
    // 일반적으로 DE2-115 보드의 7-segment는 Active Low이므로 1로 설정
    // 만약 소수점이 켜진다면 이 값을 0으로 변경하세요
    assign SEG_DP = 1'b1;

    // Single 7-Segment Display: TX 모드에서 현재 선택 중인 문자 표시
    // 표준 7-Segment 구성: a, b, c, d, e, f, g (데이터), h (소수점)
    wire [6:0] single_seg_out;
    Seven_Seg_Decoder single_seg_dec (
        .iData(tx_current_char_idx),
        .oSeg(single_seg_out)
    );
    // TX 모드일 때만 현재 문자 표시, RX 모드에서는 모든 세그먼트 OFF (Active High 기준 0)
    assign SEG_SINGLE = (is_tx_mode) ? single_seg_out : 7'b0000000;
    // 소수점(h)은 사용하지 않으므로 항상 OFF
    // 주의: 실제 하드웨어에 따라 Active Low 또는 Active High일 수 있습니다.
    // 일반적으로 DE2-115 보드의 7-segment는 Active Low이므로 1로 설정
    assign SEG_SINGLE_DP = 1'b1;

endmodule