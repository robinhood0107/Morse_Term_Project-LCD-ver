module SevenSeg_Array_Driver(
    input  wire       iCLK,
    input  wire       iRST,
    input  wire [4:0] char0,
    input  wire [4:0] char1,
    input  wire [4:0] char2,
    input  wire [4:0] char3,
    input  wire [4:0] char4,
    input  wire [4:0] char5,
    input  wire [4:0] char6,
    input  wire [4:0] char7,
    output wire [6:0] oSEG,      // a~g (Active Low) -> 공통 세그먼트 라인
    output reg  [7:0] oDIGIT     // 각 자리 Common 단자 (Active Low 가정)
);

    // 자리 스캔용 분주기 (시뮬/실측에서 필요에 따라 조정 가능)
    reg [15:0] scan_cnt;
    reg [2:0]  cur_digit;  // 0 ~ 7

    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            scan_cnt  <= 16'd0;
            cur_digit <= 3'd0;
        end else begin
            scan_cnt <= scan_cnt + 16'd1;
            // 대략 수십 kHz 수준으로 자리 전환 (50MHz 기준, 50000분주면 1kHz)
            if (scan_cnt == 16'd50000) begin
                scan_cnt  <= 16'd0;
                cur_digit <= cur_digit + 3'd1;
            end
        end
    end

    // 현재 선택된 자리의 문자 인덱스 선택
    reg [4:0] cur_char;
    always @(*) begin
        case (cur_digit)
            3'd0: cur_char = char0;
            3'd1: cur_char = char1;
            3'd2: cur_char = char2;
            3'd3: cur_char = char3;
            3'd4: cur_char = char4;
            3'd5: cur_char = char5;
            3'd6: cur_char = char6;
            3'd7: cur_char = char7;
            default: cur_char = 5'd31;
        endcase
    end

    // 기존 1글자용 디코더 재사용 (Active Low 7-Seg)
    Seven_Seg_Decoder u_dec (
        .iData(cur_char),
        .oSeg(oSEG)
    );

    // Common 단자 스캔 (Active Low: 선택된 자리만 0)
    always @(*) begin
        oDIGIT = 8'b1111_1111;
        case (cur_digit)
            3'd0: oDIGIT = 8'b1111_1110; // Digit 0
            3'd1: oDIGIT = 8'b1111_1101; // Digit 1
            3'd2: oDIGIT = 8'b1111_1011; // Digit 2
            3'd3: oDIGIT = 8'b1111_0111; // Digit 3
            3'd4: oDIGIT = 8'b1110_1111; // Digit 4
            3'd5: oDIGIT = 8'b1101_1111; // Digit 5
            3'd6: oDIGIT = 8'b1011_1111; // Digit 6
            3'd7: oDIGIT = 8'b0111_1111; // Digit 7
            default: oDIGIT = 8'b1111_1111;
        endcase
    end

endmodule


