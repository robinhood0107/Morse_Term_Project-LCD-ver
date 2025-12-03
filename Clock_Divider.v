module Clock_Divider(
    input wire iCLK,
    input wire iRST,
    output wire [3:0] oSec,
    output wire [3:0] oHalfSec
);
    // Assuming 50MHz Clock. 
    // 0.5 sec = 25,000,000 cycles.
    reg [25:0] cnt; 
    reg [3:0] sec_reg;
    reg [3:0] half_sec_reg;

    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            cnt <= 0;
            sec_reg <= 0;
            half_sec_reg <= 0;
        end else begin
            if (cnt >= 24_999_999) begin // 0.5 second
                cnt <= 0;
                half_sec_reg <= half_sec_reg + 1;
                if (half_sec_reg[0] == 1'b1) begin // Every 2 half-secs = 1 sec
                    sec_reg <= sec_reg + 1;
                end
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

    assign oSec = sec_reg;
    assign oHalfSec = half_sec_reg;

endmodule