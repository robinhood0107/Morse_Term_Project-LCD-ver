module TX_Module(
    input wire iCLK,
    input wire iRST,
    input wire iEnable,
    input wire [4:0] iKEY, // KEY[1]: Next, KEY[2]: Save, KEY[0]: Reset A, KEY[3]: Send, KEY[4]: Clear Buffer(#)
    input wire [3:0] iHalfSec,
    output reg [4:0] oCurrentChar, // Index for browsing (0-25)
    output reg [39:0] oDisplayData, // Stored chars (8 chars buffer)
    output wire oLED
);
    reg [139:0] tx_buffer; // Bit stream buffer for transmission (LSB-first)
    reg [7:0]   tx_idx;     // 현재 송신 중인 비트 인덱스 (0 ~ tx_len-1)
    reg [7:0]   tx_len;     // 버퍼에 실제로 채워진 비트 개수
    reg         is_transmitting;

    // Morse 인코딩용 임시 레지스터 (한 문자 기준, 시간 확장된 비트열)
    reg [31:0]  morse_bits; // LSB-first, Dot/Dash 및 간격(0)을 시간 확장해서 저장
    reg [5:0]   morse_len;  // 사용되는 비트 길이 (최대 약 20비트 이내)

    // Dot/Dash 심볼 패턴 (최대 4심볼) 및 길이
    reg [3:0]   sym_bits;   // LSB-first: 각 비트가 Dot(0)/Dash(1) 의미
    reg [2:0]   sym_len;    // 사용 심볼 개수 (0~4)

    integer i;              // 시간 확장용 for-loop 인덱스
    
    // Key Edge Detection
    reg [4:0] key_prev;

    // Output assignment
    // tx_buffer[tx_idx] 비트를 0.5초마다 하나씩 LED로 출력 (LSB부터 순차 전송)
    assign oLED = is_transmitting ? tx_buffer[tx_idx] : 1'b0;

    // Transmission Timing Logic에서 사용하는 이전 half_sec 값
    reg [3:0] prev_half_sec;

    // 메인 상태/제어 로직 + 송신 타이밍 로직을 한 always 블록에서 모두 처리
    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            oCurrentChar    <= 0;
            oDisplayData    <= {5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31}; // Empty (8 chars)
            tx_buffer       <= 0;
            tx_idx          <= 0;
            tx_len          <= 0;
            is_transmitting <= 0;
            key_prev        <= 5'b11111;
            prev_half_sec   <= 4'd0;
        end else begin
            // 1) 키 입력/버퍼 관련 로직은 iEnable 이 켜져 있고 송신 중이 아닐 때만 동작
            //    송신 중에는 버퍼를 변경하면 안 되므로 모든 키 입력 무시
            if (iEnable && !is_transmitting) begin
                // 1. Character Selection Logic (Browsing)
                if (key_prev[1] && !iKEY[1]) begin // KEY1: Next Char
                    if (oCurrentChar == 25) oCurrentChar <= 0;
                    else oCurrentChar <= oCurrentChar + 1;
                end 
                else if (key_prev[0] && !iKEY[0]) begin // KEY0: Reset to A
                    oCurrentChar <= 0;
                end

                // 2. Save Logic
                else if (key_prev[2] && !iKEY[2]) begin // KEY2: Save
                    // 2-1. 문자 버퍼에 저장 (7-Seg용)
                    oDisplayData <= {oDisplayData[34:0], oCurrentChar}; // Shift in (8 chars buffer)

                    // 2-2. Morse 인코딩 → Dot/Dash 심볼 패턴 생성 후,
                    //      실제 시간 패턴(Dot=1, Dash=111, intra-symbol=0, inter-char=000)으로 확장

                    // (1) Dot/Dash 심볼 패턴 정의 (RX의 모스 트리와 동일 의미)
                    //     sym_bits: LSB-first, 각 비트가 Dot(0)/Dash(1)
                    //     sym_len : 사용 심볼 개수
                    sym_bits = 4'd0;
                    sym_len  = 3'd0;

                    case (oCurrentChar)
                        // A=0, B=1, ..., Z=25
                        // sym_bits[i] (i = 0..sym_len-1): Dot=0, Dash=1, i=0이 첫 번째 심볼
                        5'd0:  begin sym_bits = 4'b0010; sym_len = 3'd2; end // A (.-)    → 0,1
                        5'd1:  begin sym_bits = 4'b0001; sym_len = 3'd4; end // B (-...)  → 1,0,0,0
                        5'd2:  begin sym_bits = 4'b0101; sym_len = 3'd4; end // C (-.-.)  → 1,0,1,0
                        5'd3:  begin sym_bits = 4'b0001; sym_len = 3'd3; end // D (-..)   → 1,0,0
                        5'd4:  begin sym_bits = 4'b0000; sym_len = 3'd1; end // E (.)     → 0
                        5'd5:  begin sym_bits = 4'b0100; sym_len = 3'd4; end // F (..-.)  → 0,0,1,0
                        5'd6:  begin sym_bits = 4'b0011; sym_len = 3'd3; end // G (--.)   → 1,1,0
                        5'd7:  begin sym_bits = 4'b0000; sym_len = 3'd4; end // H (....)  → 0,0,0,0
                        5'd8:  begin sym_bits = 4'b0000; sym_len = 3'd2; end // I (..)    → 0,0
                        5'd9:  begin sym_bits = 4'b1110; sym_len = 3'd4; end // J (.---)  → 0,1,1,1
                        5'd10: begin sym_bits = 4'b0101; sym_len = 3'd3; end // K (-.-)   → 1,0,1
                        5'd11: begin sym_bits = 4'b0100; sym_len = 3'd4; end // L (.-..)  → 0,1,0,0
                        5'd12: begin sym_bits = 4'b0011; sym_len = 3'd2; end // M (--)    → 1,1
                        5'd13: begin sym_bits = 4'b0001; sym_len = 3'd2; end // N (-.)    → 1,0
                        5'd14: begin sym_bits = 4'b0111; sym_len = 3'd3; end // O (---)   → 1,1,1
                        5'd15: begin sym_bits = 4'b0110; sym_len = 3'd4; end // P (.--.)  → 0,1,1,0
                        5'd16: begin sym_bits = 4'b1011; sym_len = 3'd4; end // Q (--.-)  → 1,1,0,1
                        5'd17: begin sym_bits = 4'b0100; sym_len = 3'd3; end // R (.-.)   → 0,1,0
                        5'd18: begin sym_bits = 4'b0000; sym_len = 3'd3; end // S (...)   → 0,0,0
                        5'd19: begin sym_bits = 4'b0001; sym_len = 3'd1; end // T (-)     → 1
                        5'd20: begin sym_bits = 4'b0100; sym_len = 3'd3; end // U (..-)   → 0,0,1
                        5'd21: begin sym_bits = 4'b1000; sym_len = 3'd4; end // V (...-)  → 0,0,0,1
                        5'd22: begin sym_bits = 4'b0110; sym_len = 3'd3; end // W (.--)   → 0,1,1
                        5'd23: begin sym_bits = 4'b1001; sym_len = 3'd4; end // X (-..-)  → 1,0,0,1
                        5'd24: begin sym_bits = 4'b1011; sym_len = 3'd4; end // Y (-.--)  → 1,0,1,1
                        5'd25: begin sym_bits = 4'b0011; sym_len = 3'd4; end // Z (--..)  → 1,1,0,0
                        default: begin
                            sym_bits = 4'd0;
                            sym_len  = 3'd0;
                        end
                    endcase

                    // (2) 심볼 패턴(sym_bits)을 실제 시간 패턴(morse_bits)으로 확장
                    //     Dot(0)  = "1"
                    //     Dash(1) = "111"
                    //     Dot/Dash 사이 = "0"
                    //     문자 사이 = "000"
                    morse_bits = 32'd0;
                    morse_len  = 6'd0;

                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < sym_len) begin
                            // Dot / Dash ON 구간
                            if (sym_bits[i] == 1'b0) begin
                                // Dot: 1 tick ON
                                morse_bits[morse_len] = 1'b1;
                                morse_len = morse_len + 1;
                            end else begin
                                // Dash: 3 ticks ON
                                morse_bits[morse_len]     = 1'b1;
                                morse_bits[morse_len + 1] = 1'b1;
                                morse_bits[morse_len + 2] = 1'b1;
                                morse_len = morse_len + 3;
                            end

                            // 심볼 사이 간격: 마지막 심볼이 아니면 0 한 개
                            if (i < (sym_len - 1)) begin
                                morse_bits[morse_len] = 1'b0;
                                morse_len = morse_len + 1;
                            end
                        end
                    end

                    // 문자 간 간격: 0 세 개 (글자 사이 구분)
                    morse_bits[morse_len]     = 1'b0;
                    morse_bits[morse_len + 1] = 1'b0;
                    morse_bits[morse_len + 2] = 1'b0;
                    morse_len = morse_len + 3;

                    // (3) tx_buffer에 시간 확장된 Morse 비트 스트림을 이어붙이기 (LSB-first)
                    //     tx_len: 현재까지 채워진 비트 수
                    if (morse_len != 0 && (tx_len + morse_len) <= 8'd140) begin
                        // tx_buffer[tx_len + k] = morse_bits[k] (k = 0..morse_len-1)
                        tx_buffer <= tx_buffer | ( ({{108{1'b0}}, morse_bits}) << tx_len );
                        tx_len    <= tx_len + morse_len;
                    end
                end

                // 3. Transmit Logic
                else if (key_prev[3] && !iKEY[3]) begin // KEY3: Send
                    // 비트 스트림이 하나 이상 있을 때만 송신 시작
                    if (tx_len != 0) begin
                        is_transmitting <= 1;
                        tx_idx          <= 0;
                    end
                end
                // 4. Buffer Clear (#): 과거 버퍼 전체 삭제 (현재 선택 문자는 그대로)
                else if (key_prev[4] && !iKEY[4]) begin // KEY4: Clear Buffer (#)
                    oDisplayData <= {5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31, 5'd31};
                    tx_buffer    <= 0;
                    tx_len       <= 0;
                    // 송신 중이었다면 송신도 중단
                    is_transmitting <= 0;
                    tx_idx          <= 0;
                end

                key_prev <= iKEY;
            end else if (iEnable) begin
                // 송신 중일 때는 키 입력을 무시하지만, key_prev는 업데이트해야 함
                key_prev <= iKEY;
            end

            // 2) 송신 중일 때 0.5초마다 인덱스 업데이트 (iEnable 과 무관하게 동작)
            if (is_transmitting) begin
                if (prev_half_sec != iHalfSec) begin // On 0.5s tick
                    // tx_len 비트까지만 송신하고 자동 종료
                    if (tx_len == 0 || tx_idx >= (tx_len - 1)) begin
                        is_transmitting <= 0;
                        tx_idx          <= 0;
                    end else begin
                        tx_idx <= tx_idx + 1;
                    end
                end
            end

            // 항상 half_sec 변화 감지용 레지스터 갱신
            prev_half_sec <= iHalfSec;
        end
    end

endmodule