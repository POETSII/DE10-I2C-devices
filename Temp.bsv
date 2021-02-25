package Temp;

import I2C::*;
import I2CUtil::*;
import StmtFSM::*;
import GetPut::*;
import ClientServer::*;
import FIFO::*;
import List::*;

import ListExtra::*;
import Recipe::*;
#include "RecipeMacros.h"

typedef union tagged {
    void ReadTemp;
} TempReq
  deriving (Bits);

function Bool isReadTemp(TempReq val) = val matches tagged ReadTemp ? True : False;

typedef union tagged {
    Bit#(8) TempVal;
} TempRsp
  deriving (Bits);

interface Temp;
    interface I2C_Pins i2c;
    
    interface Server#(TempReq, TempRsp) data;
endinterface

module mkTemp #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (Temp);
    let i2c_prescale = clk_freq / 400000;
    I2C temp <- mkI2C(i2c_prescale);


    function Recipe dev_init() = Seq
        rAct(i2c_write_byte(temp, slave_addr, 8'h0A, 8'b00010100))
    End;

    function Recipe read_val(Wire#(TempRsp) result) = Seq
        rAct(i2c_read_byte(temp, slave_addr, 8'h01)),
        rAct(action
            let data <- i2c_get_byte(temp);
            result <= TempVal(data);
        endaction)
    End; 
    

    FIFO#(TempReq) dataIn <- mkFIFO1();
    Wire#(TempRsp) dataOut <- mkWire();

    Recipe fsm = Seq
        dev_init(),
        While(True) Seq
            rOneMatch(list( isReadTemp(dataIn.first) ),
                      list( read_val(dataOut) ),
                      rAct(noAction)),
            rAct(dataIn.deq())
        End
        End
    End;

    RecipeFSM main <- mkRecipeFSM( fsm );

    rule run_main;
        main.trigger();
    endrule

    interface I2C_Pins i2c = temp.i2c;

    interface Server data;
        interface Put request = toPut(dataIn);

        interface Get response;
            method get = actionvalue
                return dataOut;
            endactionvalue;
        endinterface
    endinterface
endmodule: mkTemp

interface TempReaderIfc;
    (* prefix = "TEMP_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(8) get_temp ();
endinterface


module mkTempReader #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (TempReaderIfc);
    Reg#(Bit#(8)) cur_temp <- mkReg(0);

    Reg#(Bit#(32)) cnt <- mkReg(fromInteger(clk_freq));

    Temp temp <- mkTemp(slave_addr, clk_freq);

    rule counter (cnt > 0);
        cnt <= cnt-1;
    endrule

    rule counter_rst (cnt == 0);
        cnt <= fromInteger(clk_freq);
        temp.data.request.put(ReadTemp);
    endrule

    rule temp_update;
        let rsp <- temp.data.response.get();
        if ( rsp matches tagged TempVal .t ) 
            cur_temp <= t;
    endrule

    interface I2C_Pins i2c = temp.i2c;

    method get_temp() = cur_temp;
endmodule

(* synthesize *)
module mkDE10TempReader (TempReaderIfc);
    TempReaderIfc temp <- mkTempReader(7'b0011100, 50000000); //DE10 Temp IC addr 0x1C, 50MHz Clock
    return temp;
endmodule

endpackage: Temp
