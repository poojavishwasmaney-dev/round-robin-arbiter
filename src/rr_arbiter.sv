//======================================================================
// File name    : rr_arbiter.sv
// Author       : Pooja Ramesh
// Date         : 2026-05-20
// Description  : Parametrised Round robin arbiter with one -hot encoded output
//======================================================================

module rr_arbiter #(
    parameter n = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [n-1:0] grant_request,
    input  wire        grant_valid,
    
    output reg  [n-1:0] o_grant,
    output reg          o_grant_valid
);

// Priority pointer: indicates which requester has highest priority
reg [$clog2(n)-1:0] priority_ptr;
reg [n-1:0]         next_grant;
reg                 next_grant_valid;
reg [$clog2(n)-1:0] next_priority_ptr;

integer i, idx;
always @(*) begin
    next_grant          = 'b0;
    next_grant_valid    = 1'b0;
    next_priority_ptr   = priority_ptr;  
    
    if (grant_valid) begin
        // Search starting from priority_ptr, wrap around
        for (i = 0; i < n; i++) begin
            idx = (priority_ptr + i) % n;
            if (grant_request[idx]) begin
                next_grant[idx]     = 1'b1;
                next_grant_valid    = 1'b1;
                next_priority_ptr   = (idx + 1) % n;  // Next starts after granted
                break;
            end
        end
    end
end

// Register all outputs 
always @(posedge clk ) begin
    if (!rst_n) begin
        o_grant       <= 'b0;
        o_grant_valid <= 1'b0;
        priority_ptr  <= 0;
    end else begin
        o_grant       <= next_grant;
        o_grant_valid <= next_grant_valid;
        priority_ptr  <= next_priority_ptr;
    end  
end

endmodule