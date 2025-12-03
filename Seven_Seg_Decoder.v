module Seven_Seg_Decoder(
    input wire [4:0] iData,
    output reg [6:0] oSeg
);
    // 0=A, 1=B, ..., 25=Z
    // Active High Output (1 turns on segment) for common cathode
    // 이미지 기준: '1' 표시 = "01100000" (8비트: h, g, f, e, d, c, b, a) = b, c만 켜짐
    // oSeg[6:0] = [a, b, c, d, e, f, g] 순서로 가정 (LSB부터)
    // '1' 표시: b, c만 켜짐 = 7'b1001111 (oSeg[1]=b=1, oSeg[2]=c=1, Active High이므로 1이 켜짐)
    // 모든 비트가 반전됨 (Active Low → Active High)
    always @(*) begin
        case(iData)
            5'd0 : oSeg = 7'b1110111; // A
            5'd1 : oSeg = 7'b1111100; // B
            5'd2 : oSeg = 7'b0111001; // C
            5'd3 : oSeg = 7'b1011110; // D
            5'd4 : oSeg = 7'b1111001; // E
            5'd5 : oSeg = 7'b1110001; // F
            5'd6 : oSeg = 7'b1101111; // G (Fixed)
            5'd7 : oSeg = 7'b1110110; // H
            5'd8 : oSeg = 7'b0110000; // I (숫자 1처럼 표시: b, c만 켜짐)
            5'd9 : oSeg = 7'b0001110; // J
            5'd10: oSeg = 7'b1111010; // K (Approximated)
            5'd11: oSeg = 7'b0111000; // L
            5'd12: oSeg = 7'b1010101; // M (Approximated)
            5'd13: oSeg = 7'b0110111; // N (Approximated)
            5'd14: oSeg = 7'b1111110; // O (Fixed)
            5'd15: oSeg = 7'b1110011; // P
            5'd16: oSeg = 7'b1100111; // Q
            5'd17: oSeg = 7'b0000101; // R (Approximated)
            5'd18: oSeg = 7'b1101101; // S
            5'd19: oSeg = 7'b1111000; // T (Approximated)
            5'd20: oSeg = 7'b0111110; // U
            5'd21: oSeg = 7'b0111110; // V (Same as U)
            5'd22: oSeg = 7'b0101010; // W (Inverted M)
            5'd23: oSeg = 7'b1001001; // X (H with bars)
            5'd24: oSeg = 7'b1101110; // Y
            5'd25: oSeg = 7'b1011011; // Z
            default: oSeg = 7'b0000000; // OFF
        endcase
    end
endmodule