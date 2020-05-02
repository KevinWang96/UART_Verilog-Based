/*
 * @Author: Yihao Wang
 * @Date: 2020-05-02 00:26:41
 * @LastEditTime: 2020-05-02 02:37:57
 * @LastEditors: Please set LastEditors
 * @Description: 
 *      a. Sending logic of Tx side driven by bit clock (generated by clk generator)
 *      b. Supporting error detection by attaching 1-bit parity (MSB) to data frame 
 * @FilePath: /uart/src/uart_tx_send_logic.v
 */
 `timescale 1ns/1ps
 module uart_tx_send_logic #(
     parameter  DATA_FRAME_WIDTH    =   8   // not include parity bit (MSB)                     
 )
 (
     bit_clk,
     reset,
     uart_tx_en,
     uart_tx_din, // data frame
     uart_tx_dout, // 1-bit
     uart_tx_done
 );
    input                               bit_clk;            // postive edge triggering
    input                               reset;          // sync reset
    input                               uart_tx_en;     // enable signal; If enbale is asserted, input data is ready and transferring can start
    input   [0:DATA_FRAME_WIDTH - 1]    uart_tx_din;    // parallel data frame input
    output                              uart_tx_dout;   // 1-bit serial data out
    output                              uart_tx_done;   // 1 indicates data transferring has finished

    // FSM states definition:
    localparam  IDLE    =   2'b00, // inactive
                INIT    =   2'b01, // generates start bit
                ACTIVE  =   2'b10, // transfer data 
                STOP    =   2'b11; // transfer 2-bit stop bits

    reg [0:1]                                   state;      // state memory
    reg [0:$clog2(DATA_FRAME_WIDTH + 1) - 1]    counter;    // counter used by FSM
    reg [0:DATA_FRAME_WIDTH]                    shift_reg;  // shifter register used to serilize input data
    reg                                         parity_bit; // 1-bit parity bit used for error detection

    // Parity bit generator
    always @(*) begin : parity_generator
        integer i;
        parity_bit = 0;
        for(i = 0; i < DATA_FRAME_WIDTH; i = i + 1)
            parity_bit = (parity_bit ^ uart_tx_din[i]);
    end

    // FSM: NSL + SM 
    always @(posedge bit_clk) begin
        if(reset) begin
            state <= IDLE;
            counter <= 0;
            shift_reg <= 1; // since output is 1 in IDLE state
        end
        else 
            case(state)
                IDLE : begin
                    if(uart_tx_en) begin
                        shift_reg[DATA_FRAME_WIDTH] <= 0; // generates start bir (1'b0)
                        state <= INIT; // state transition
                    end
                end
                INIT : begin
                    shift_reg <= {parity_bit, uart_tx_din}; // load parallel data (including parity) into shifter registers
                    counter <= 0;
                    state <= ACTIVE; // state transition
                end
                ACTIVE : begin
                    if(counter < DATA_FRAME_WIDTH) begin : shift_loop
                        integer i;
                        for(i = 1; i <= DATA_FRAME_WIDTH; i = i + 1) 
                            shift_reg[i] <= shift_reg[i - 1]; // right shift by 1 bit
                        
                        counter <= counter + 1;
                    end
                    else begin
                        shift_reg[DATA_FRAME_WIDTH] <= 1; // used to generate stop bit 
                        counter <= 0;

                        state <= STOP; // state transition
                    end
                end
                STOP : begin   
                    if(counter == 1) state <= IDLE; // state transition
                    else counter <= counter + 1;
                end
            endcase
    end

    assign  uart_tx_dout    =   shift_reg[DATA_FRAME_WIDTH];    // generates serial data out
    assign  uart_tx_done    =   (state == IDLE);                    // generates done signal
                 
 endmodule