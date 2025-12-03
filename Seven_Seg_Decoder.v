module Seven_Seg_Decoder(
    input wire [4:0] iData,
    output reg [6:0] oSeg
);
    // 0=A, 1=B, ..., 25=Z
    // Active Low Output (0 turns on segment) for common anode
    always @(*) begin
        case(iData)
            5'd0 : oSeg = 7'b0001000; // A
            5'd1 : oSeg = 7'b0000011; // B
            5'd2 : oSeg = 7'b1000110; // C
            5'd3 : oSeg = 7'b0100001; // D
            5'd4 : oSeg = 7'b0000110; // E
            5'd5 : oSeg = 7'b0001110; // F
            5'd6 : oSeg = 7'b0010000; // G (Fixed)
            5'd7 : oSeg = 7'b0001001; // H
            5'd8 : oSeg = 7'b1001111; // I (Fixed to 1)
            5'd9 : oSeg = 7'b1110001; // J
            5'd10: oSeg = 7'b0000101; // K (Approximated)
            5'd11: oSeg = 7'b1000111; // L
            5'd12: oSeg = 7'b0101010; // M (Approximated)
            5'd13: oSeg = 7'b1001000; // N (Approximated)
            5'd14: oSeg = 7'b0000001; // O (Fixed)
            5'd15: oSeg = 7'b0001100; // P
            5'd16: oSeg = 7'b0011000; // Q
            5'd17: oSeg = 7'b1111010; // R (Approximated)
            5'd18: oSeg = 7'b0010010; // S
            5'd19: oSeg = 7'b0000111; // T (Approximated)
            5'd20: oSeg = 7'b1000001; // U
            5'd21: oSeg = 7'b1000001; // V (Same as U)
            5'd22: oSeg = 7'b1010101; // W (Inverted M)
            5'd23: oSeg = 7'b0110110; // X (H with bars)
            5'd24: oSeg = 7'b0010001; // Y
            5'd25: oSeg = 7'b0100100; // Z
            default: oSeg = 7'b1111111; // OFF
        endcase
    end
endmodule