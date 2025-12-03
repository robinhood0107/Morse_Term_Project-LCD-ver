module RX_Module(
    input wire iCLK,
    input wire iRST,
    input wire iEnable,
    input wire [4:0] iKEY, // KEY[1]: Dash, KEY[2]: Dot, KEY[3]: Next/Confirm, KEY[4]: Unused here
    output wire [39:0] oDisplayData, // 8 chars buffer
    output wire oBuzzer
);
    reg [39:0] shift_reg; // Holds 8 decoded characters (5bits * 8)
    
    // Decoding State
    reg [3:0] stack; // Stores dots(0)/dashes(1). LSB first.
    reg [2:0] count; // Number of signals in current char
    reg [4:0] decoded; // [Fix] Declaration moved here from inside always block
    
    // Edge detection for buttons
    reg [4:0] key_prev;
    
    // Buzzer Logic: Beep while key is pressed (Active Low keys assumed)
    assign oBuzzer = iEnable ? (!iKEY[1] || !iKEY[2]) : 1'b0;
    assign oDisplayData = shift_reg;

    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            shift_reg <= 40'hFFFFFFFFFF; // Reset display (8 chars, all OFF)
            stack <= 0;
            count <= 0;
            key_prev <= 5'b11111;
            decoded <= 5'd31;
        end else if (iEnable) begin
            // Key edge detection (Active Low)
            // KEY[1] (Dash/Long, '1') Falling Edge
            if (key_prev[1] && !iKEY[1]) begin
                stack <= {stack[2:0], 1'b1}; // Shift in 1 (Dash)
                count <= count + 1;
            end
            // KEY[2] (Dot/Short, '0') Falling Edge
            else if (key_prev[2] && !iKEY[2]) begin
                stack <= {stack[2:0], 1'b0}; // Shift in 0 (Dot)
                count <= count + 1;
            end
            // KEY[3] (Confirm/Next) Falling Edge
            else if (key_prev[3] && !iKEY[3]) begin
                // Decode Logic (Full Morse Tree Implementation)
                // A=0, B=1, ..., Z=25
                decoded = 5'd31; // Default Space/Error

                case (count)
                    // Length 1
                    1: case(stack[0])
                        1'b0: decoded = 5'd4;  // E (.)
                        1'b1: decoded = 5'd19; // T (-)
                       endcase
                    
                    // Length 2
                    2: case(stack[1:0])
                        2'b00: decoded = 5'd8;  // I (..)
                        2'b01: decoded = 5'd0;  // A (.-)
                        2'b10: decoded = 5'd13; // N (-.)
                        2'b11: decoded = 5'd12; // M (--)
                       endcase
                    
                    // Length 3
                    3: case(stack[2:0])
                        3'b000: decoded = 5'd18; // S (...)
                        3'b001: decoded = 5'd20; // U (..-)
                        3'b010: decoded = 5'd17; // R (.-.)
                        3'b011: decoded = 5'd22; // W (.--)
                        3'b100: decoded = 5'd3;  // D (-..)
                        3'b101: decoded = 5'd10; // K (-.-)
                        3'b110: decoded = 5'd6;  // G (--.)
                        3'b111: decoded = 5'd14; // O (---)
                       endcase

                    // Length 4
                    4: case(stack[3:0])
                        4'b0000: decoded = 5'd7;  // H (....)
                        4'b0001: decoded = 5'd21; // V (...-)
                        4'b0010: decoded = 5'd5;  // F (..-.)
                        // 4'b0011: unused
                        4'b0100: decoded = 5'd11; // L (.-..)
                        // 4'b0101: unused
                        4'b0110: decoded = 5'd15; // P (.--.)
                        4'b0111: decoded = 5'd9;  // J (.---)
                        4'b1000: decoded = 5'd1;  // B (-...)
                        4'b1001: decoded = 5'd23; // X (-..-)
                        4'b1010: decoded = 5'd2;  // C (-.-.)
                        4'b1011: decoded = 5'd24; // Y (-.--)
                        4'b1100: decoded = 5'd25; // Z (--..)
                        4'b1101: decoded = 5'd16; // Q (--.-)
                       endcase
                endcase
                
                // Shift into display buffer (Shift Left)
                shift_reg <= {shift_reg[34:0], decoded};
                
                // Reset for next char
                stack <= 0;
                count <= 0;
            end

            key_prev <= iKEY;
        end
    end
endmodule