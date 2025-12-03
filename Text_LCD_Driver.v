module Text_LCD_Driver(
    input wire iCLK,          // 50MHz Clock
    input wire iRST,
    input wire [39:0] iCharData, // 8 chars buffer (5 bits each: 0-25=A-Z, 31=Space)
    output reg [7:0] oLCD_D,  // LCD Data bus (D7~D0)
    output reg oLCD_E,        // LCD Enable
    output reg oLCD_RS,       // LCD Register Select (0=Command, 1=Data)
    output reg oLCD_RW        // LCD Read/Write (0=Write, 1=Read)
);

    // State Machine
    localparam IDLE = 3'd0;
    localparam INIT_WAIT = 3'd1;
    localparam INIT_FUNC = 3'd2;
    localparam INIT_DISP = 3'd3;
    localparam INIT_CLEAR = 3'd4;
    localparam INIT_ENTRY = 3'd5;
    localparam READY = 3'd6;
    localparam WRITE_CHAR = 3'd7;

    reg [2:0] state;
    reg [31:0] delay_cnt;
    reg [3:0] init_step;
    reg [2:0] char_idx;
    reg [7:0] ascii_char;

    // Clock divider for LCD timing
    // 50MHz / 200 = 250kHz (4us 주기)
    // LCD는 일반적으로 250kHz ~ 1MHz 범위의 클럭을 사용
    reg [7:0] clk_div;
    wire lcd_clk;
    assign lcd_clk = (clk_div == 8'd200); // 50MHz / 200 = 250kHz

    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            clk_div <= 8'd0;
        end else begin
            if (clk_div == 8'd200) begin
                clk_div <= 8'd0;
            end else begin
                clk_div <= clk_div + 8'd1;
            end
        end
    end

    // Character to ASCII conversion
    always @(*) begin
        case (iCharData[char_idx*5 +: 5])
            5'd0:  ascii_char = 8'h41; // A
            5'd1:  ascii_char = 8'h42; // B
            5'd2:  ascii_char = 8'h43; // C
            5'd3:  ascii_char = 8'h44; // D
            5'd4:  ascii_char = 8'h45; // E
            5'd5:  ascii_char = 8'h46; // F
            5'd6:  ascii_char = 8'h47; // G
            5'd7:  ascii_char = 8'h48; // H
            5'd8:  ascii_char = 8'h49; // I
            5'd9:  ascii_char = 8'h4A; // J
            5'd10: ascii_char = 8'h4B; // K
            5'd11: ascii_char = 8'h4C; // L
            5'd12: ascii_char = 8'h4D; // M
            5'd13: ascii_char = 8'h4E; // N
            5'd14: ascii_char = 8'h4F; // O
            5'd15: ascii_char = 8'h50; // P
            5'd16: ascii_char = 8'h51; // Q
            5'd17: ascii_char = 8'h52; // R
            5'd18: ascii_char = 8'h53; // S
            5'd19: ascii_char = 8'h54; // T
            5'd20: ascii_char = 8'h55; // U
            5'd21: ascii_char = 8'h56; // V
            5'd22: ascii_char = 8'h57; // W
            5'd23: ascii_char = 8'h58; // X
            5'd24: ascii_char = 8'h59; // Y
            5'd25: ascii_char = 8'h5A; // Z
            default: ascii_char = 8'h20; // Space (31 or others)
        endcase
    end

    // LCD Write Function
    task lcd_write;
        input [7:0] data;
        input rs_val;
        begin
            oLCD_D = data;
            oLCD_RS = rs_val;
            oLCD_RW = 1'b0; // Write mode
            oLCD_E = 1'b1;
            // E pulse: High -> Low (minimum 450ns)
            delay_cnt <= 32'd0;
            state <= WRITE_CHAR;
        end
    endtask

    // Main State Machine
    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            state <= INIT_WAIT;
            delay_cnt <= 32'd0;
            init_step <= 4'd0;
            char_idx <= 3'd0;
            oLCD_D <= 8'h00;
            oLCD_E <= 1'b0;
            oLCD_RS <= 1'b0;
            oLCD_RW <= 1'b0;
        end else if (lcd_clk) begin
            case (state)
                INIT_WAIT: begin
                    // Wait 15ms after power-on
                    if (delay_cnt < 32'd7500000) begin // 15ms at 50MHz
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        delay_cnt <= 32'd0;
                        state <= INIT_FUNC;
                        init_step <= 4'd0;
                    end
                end

                INIT_FUNC: begin
                    // Function Set: 8-bit mode, 2 lines, 5x8 font
                    if (delay_cnt == 32'd0) begin
                        oLCD_D <= 8'h38;
                        oLCD_RS <= 1'b0;
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd10) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        oLCD_E <= 1'b0;
                        delay_cnt <= 32'd0;
                        state <= INIT_DISP;
                    end
                end

                INIT_DISP: begin
                    // Display On/Off Control: Display ON, Cursor OFF, Blink OFF
                    if (delay_cnt == 32'd0) begin
                        oLCD_D <= 8'h0C;
                        oLCD_RS <= 1'b0;
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd10) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        oLCD_E <= 1'b0;
                        delay_cnt <= 32'd0;
                        state <= INIT_CLEAR;
                    end
                end

                INIT_CLEAR: begin
                    // Clear Display
                    // LCD 클리어 명령은 최소 2ms 대기 시간이 필요함
                    // lcd_clk = 250kHz (4us 주기)이므로 2ms = 500 사이클
                    if (delay_cnt == 32'd0) begin
                        oLCD_D <= 8'h01;
                        oLCD_RS <= 1'b0;
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd10) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd510) begin
                        // E 펄스 종료 후 2ms 대기 (500 사이클 = 2ms at 250kHz)
                        oLCD_E <= 1'b0;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        delay_cnt <= 32'd0;
                        state <= INIT_ENTRY;
                    end
                end

                INIT_ENTRY: begin
                    // Entry Mode Set: Increment, No shift
                    if (delay_cnt == 32'd0) begin
                        oLCD_D <= 8'h06;
                        oLCD_RS <= 1'b0;
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd10) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        oLCD_E <= 1'b0;
                        delay_cnt <= 32'd0;
                        state <= READY;
                        char_idx <= 3'd0;
                    end
                end

                READY: begin
                    // Set DDRAM address to 0x00 (first line, first position)
                    if (delay_cnt == 32'd0) begin
                        oLCD_D <= 8'h80;
                        oLCD_RS <= 1'b0;
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd10) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        oLCD_E <= 1'b0;
                        delay_cnt <= 32'd0;
                        state <= WRITE_CHAR;
                    end
                end

                WRITE_CHAR: begin
                    if (delay_cnt == 32'd0) begin
                        // Write character data
                        oLCD_D <= ascii_char;
                        oLCD_RS <= 1'b1; // Data mode
                        oLCD_RW <= 1'b0;
                        oLCD_E <= 1'b1;
                        delay_cnt <= delay_cnt + 32'd1;
                    end else if (delay_cnt < 32'd20) begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end else begin
                        oLCD_E <= 1'b0;
                        delay_cnt <= 32'd0;
                        if (char_idx < 3'd7) begin
                            char_idx <= char_idx + 3'd1;
                            // Continue to next character (stay in WRITE_CHAR state)
                            // delay_cnt is already 0, so next cycle will write next char
                        end else begin
                            char_idx <= 3'd0;
                            // All 8 characters written, go back to READY to refresh
                            state <= READY;
                        end
                    end
                end

                default: state <= INIT_WAIT;
            endcase
        end
    end

endmodule

