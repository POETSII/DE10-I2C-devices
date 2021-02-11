package Temp;

import I2C::*;
import I2CUtil::*;
import StmtFSM::*;

function Stmt temp_init(I2C temp, Bit#(7) slave_addr) = seq
    i2c_write_byte(temp, slave_addr, 8'h0A, 8'b00010100);
endseq;

function Stmt temp_read_val(I2C temp, Bit#(7) slave_addr, Reg#(Bit#(8)) result);
    seq
        i2c_read_byte(temp, slave_addr, 8'h01);
        action
            let data <- i2c_get_byte(temp);
            result <= data;
        endaction
    endseq;
endfunction

interface Temp;
    interface I2C_Pins i2c;

    method Action start_read();
    method Bit#(8) get_temp();
endinterface

module mkTemp #(parameter Bit#(7) slave_addr) (Temp);
    I2C temp <- mkI2C(125);

    Wire#(Bit#(8)) value <- mkWire();
    PulseWire trigger <- mkPulseWire();

    Stmt fsm =
    seq
        temp_init(temp, slave_addr);
        while(True) seq
            await(trigger);
            temp_read_val(temp, slave_addr, value);
        endseq
    endseq;

    FSM main <- mkFSM( fsm );

    rule run_main;
        main.start();
    endrule

    method Action start_read();
        trigger.send();
    endmethod

    method Bit#(8) get_temp();
        return value;
    endmethod
    
    interface I2C_Pins i2c = temp.i2c;
endmodule: mkTemp

interface TempReaderIfc;
    (* prefix = "TEMP_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(8) get_temp ();
endinterface

(* synthesize *)
module mkTempReader (TempReaderIfc);
    Reg#(Bit#(8)) cur_temp <- mkReg(0);

    Reg#(Bit#(32)) cnt <- mkReg(50000000);

    Temp temp <- mkTemp(7'b0011100); //DE10 Temp IC addr 0x1C

    rule counter (cnt > 0);
        cnt <= cnt-1;
    endrule

    rule counter_rst (cnt == 0);
        cnt <= 50000000;
        temp.start_read();
    endrule

    rule temp_update;
        cur_temp <= temp.get_temp();
    endrule

    interface I2C_Pins i2c = temp.i2c;

    method Bit#(8) get_temp();
        return cur_temp;
    endmethod
endmodule
endpackage: Temp
