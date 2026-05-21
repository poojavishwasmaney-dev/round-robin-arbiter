//======================================================================
// File name    : rr_arbiter_tb.sv
// Author       : Pooja Ramesh
// Date         : 2026-05-20
// Description  : Testbench to check Parametrised Round robin arbiter with one -hot encoded output
//======================================================================
module tb_rr_arbiter;

    // Parameters
    parameter n = 8;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [n-1:0] grant_request;
    reg grant_valid;
    wire [n-1:0] o_grant;
    wire o_grant_valid;
    
    // Instantiate the module
    rr_arbiter #(
        .n(n)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .grant_request(grant_request),
        .grant_valid(grant_valid),
        .o_grant(o_grant),
        .o_grant_valid(o_grant_valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        grant_request = 0;
        grant_valid = 0;
        rst_n = 0;
        
        // Dump waves for waveform viewing
        $dumpfile("tb_rr_arbiter.vcd");
        $dumpvars(0, tb_rr_arbiter);
        
        // Release reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test 1: Single request
        $display("Test 1: Single request - bit 0");
        grant_request = 8'b00000001;
        grant_valid = 1;
        @(posedge clk);
        verify_grant(8'b00000001, 1);
        
        // Clear grant_valid after grant is accepted
        @(posedge clk);
        grant_valid = 0;
        @(posedge clk);
        
        // Test 2: Same request again should round-robin
        $display("Test 2: Same request again - should round-robin");
        grant_request = 8'b00000001;
        grant_valid = 1;
        @(posedge clk);
        verify_grant(8'b00000001, 1);
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 3: Multiple requests
        $display("Test 3: Multiple requests - 8'b10101010");
        grant_request = 8'b10101010;
        grant_valid = 1;
        @(posedge clk);
        verify_grant_one_of(8'b10101010, 1);
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 4: All requests
        $display("Test 4: All requests - 8'b11111111");
        grant_request = 8'b11111111;
        grant_valid = 1;
        for (int i = 0; i < 16; i++) begin
            @(posedge clk);
            verify_grant_one_of(8'b11111111, 1);
            grant_valid = 0;
            @(posedge clk);
            grant_valid = 1;
        end
        
        // Test 5: No requests
        $display("Test 5: No requests");
        grant_request = 8'b00000000;
        grant_valid = 1;
        @(posedge clk);
        verify_grant(8'b00000000, 0);
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 6: Changing requests dynamically
        $display("Test 6: Dynamic requests");
        grant_request = 8'b00010001;
        grant_valid = 1;
        @(posedge clk);
        verify_grant_one_of(8'b00010001, 1);
        
        grant_request = 8'b00100010;
        grant_valid = 0;
        @(posedge clk);
        grant_valid = 1;
        @(posedge clk);
        verify_grant_one_of(8'b00100010, 1);
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 7: Consecutive requests without deasserting grant_valid
        $display("Test 7: Consecutive requests with grant_valid high");
        grant_request = 8'b00001111;
        grant_valid = 1;
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            verify_grant_one_of(8'b00001111, 1);
            // Keep grant_valid high for next cycle
        end
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 8: Reset during operation
        $display("Test 8: Reset during operation");
        grant_request = 8'b11110000;
        grant_valid = 1;
        @(posedge clk);
        verify_grant_one_of(8'b11110000, 1);
        
        // Assert reset
        rst_n = 0;
        @(posedge clk);
        verify_grant(8'b00000000, 0);
        
        // Release reset
        rst_n = 1;
        @(posedge clk);
        verify_grant(8'b00000000, 0);
        
        // Test 9: Edge cases - alternating single bits
        $display("Test 9: Alternating single bits");
        for (int i = 0; i < n; i++) begin
            grant_request = 1 << i;
            grant_valid = 1;
            @(posedge clk);
            verify_grant(1 << i, 1);
            grant_valid = 0;
            @(posedge clk);
        end
        
        // Test 10: Test round-robin pattern
        $display("Test 10: Testing round-robin sequence");
        grant_request = 8'b11111111;
        grant_valid = 1;
        $display("Expected round-robin sequence:");
        for (int i = 0; i < 20; i++) begin
            @(posedge clk);
            $display("  Cycle %0d: Grant = %b", i, o_grant);
            verify_grant_one_of(8'b11111111, 1);
            // Keep grant_valid high to see the round-robin sequence
        end
        
        grant_valid = 0;
        @(posedge clk);
        
        // Test 11: Random requests
        $display("Test 11: Random requests");
        for (int i = 0; i < 50; i++) begin
            grant_request = $random;
            grant_valid = 1;
            @(posedge clk);
            if (grant_request != 0) begin
                verify_grant_one_of(grant_request, 1);
            end else begin
                verify_grant(8'b00000000, 0);
            end
            grant_valid = 0;
            @(posedge clk);
        end
        
        // End of tests
        $display("All tests completed!");
        $finish;
    end
    
    // Verification tasks
    task verify_grant;
        input [n-1:0] expected_grant;
        input expected_valid;
        begin
            if (o_grant_valid !== expected_valid) begin
                $error("VALID MISMATCH: Expected %0d, Got %0d at time %0t", 
                       expected_valid, o_grant_valid, $time);
            end
            if (o_grant !== expected_grant) begin
                $error("GRANT MISMATCH: Expected %b, Got %b at time %0t", 
                       expected_grant, o_grant, $time);
            end
            if (o_grant_valid == expected_valid && o_grant == expected_grant) begin
                $display("  PASS: grant=%b, valid=%0d", o_grant, o_grant_valid);
            end
        end
    endtask
    
    task verify_grant_one_of;
        input [n-1:0] request_mask;
        input expected_valid;
        begin
            if (o_grant_valid !== expected_valid) begin
                $error("VALID MISMATCH: Expected %0d, Got %0d at time %0t", 
                       expected_valid, o_grant_valid, $time);
            end
            if (o_grant_valid && (o_grant & request_mask) != o_grant) begin
                $error("GRANT MISMATCH: Grant %b not in request mask %b at time %0t", 
                       o_grant, request_mask, $time);
            end
            if (o_grant_valid && (o_grant & request_mask) == o_grant && o_grant != 0) begin
                $display("  PASS: grant=%b is in request mask %b", o_grant, request_mask);
            end else if (!o_grant_valid) begin
                $display("  PASS: No grant as expected");
            end
        end
    endtask
    
    // Monitor to check for spurious grants
    always @(posedge clk) begin
        if (!rst_n) begin
            assert (o_grant == 0 && o_grant_valid == 0) else
                $error("RESET VIOLATION: Grant not cleared during reset!");
        end
        if (o_grant_valid && (o_grant & grant_request) != o_grant) begin
            $error("PROTOCOL VIOLATION: Grant %b not requested by %b", 
                   o_grant, grant_request);
        end
    end
    
endmodule