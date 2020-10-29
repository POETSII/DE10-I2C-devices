package Temp;

import I2C::*;
import I2CUtil::*;
import StmtFSM::*;

interface Temp;
    interface I2C_Pins i2c;

    method Stmt init();
    
    method Stmt read_val(Reg#(Bit#(8)) result);
endinterface

module mkTemp #(parameter Bit#(7) slave_addr) (Temp);
    I2C temp <- mkI2C(125);
    
    method Stmt init() = seq
            i2c_write_byte(temp, slave_addr, 8'h0A, 8'b00010100);
        endseq;

    method Stmt read_val(Reg#(Bit#(8)) result);
        seq
            i2c_read_byte(temp, slave_addr, 8'h01);
            action
                let data <- i2c_get_byte(temp);
                result <= data;
            endaction
        endseq;
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

    PulseWire pw <- mkPulseWire;

    (* fire_when_enabled, no_implicit_conditions *)
    rule counter (cnt > 0);
        cnt <= cnt-1;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule counter_rst (cnt == 0 && pw);
        cnt <= 50000000;
    endrule

    Stmt test =
    seq
        await(cnt == 0);
        temp.init();
        while(True) seq
            temp.read_val(cur_temp);
            pw.send();
            await(cnt == 0);
        endseq
    endseq;

    FSM main <- mkFSM( test );

    rule run_main;
        main.start();
    endrule

    interface I2C_Pins i2c = temp.i2c;

    method Bit#(8) get_temp();
        return cur_temp;
    endmethod
endmodule
endpackage: Temp
