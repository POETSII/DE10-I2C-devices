package Power;

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
    Bool SetTestMode;
    void ResetPowerMinMax;
    void ReadPowerMin;
    void ReadPowerMax;
} PowerReq
  deriving (Bits);

function Bool isSetTestMode(PowerReq v) = v matches tagged SetTestMode .t ? True : False;
function Bool isResetPowerMinMax(PowerReq v) = v matches tagged ResetPowerMinMax ? True : False;
function Bool isReadPowerMin(PowerReq v) = v matches tagged ReadPowerMin ? True : False;
function Bool isReadPowerMax(PowerReq v) = v matches tagged ReadPowerMax ? True : False;
      
typedef union tagged {
    Bit#(24) PowerMinValue;
    Bit#(24) PowerMaxValue;
} PowerRsp
  deriving (Bits);


interface Power;
    interface I2C_Pins i2c;

    interface Server#(PowerReq, PowerRsp) data; 
endinterface

module mkPower #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (Power);
    let i2c_prescale = clk_freq / 400000; // Freq / 400kHz = I2C Prescale
    I2C power <- mkI2C(i2c_prescale); 
    Reg#(Bit#(24)) temp <- mkReg(?);


    function Recipe device_init() = Seq
        i2c_write_byte(power, slave_addr, 8'h00, 8'b00000101),
        i2c_write_byte(power, slave_addr, 8'h01, 8'b00000000)
    End;

    function Recipe test_mode_enable() = Seq
        i2c_write_byte(power, slave_addr, 8'h00, 8'b00010101)
    End;

    function Recipe test_mode_disable() = Seq
        i2c_write_byte(power, slave_addr, 8'h00, 8'b00000101)
    End;

    function Recipe reset_power_min_max() = Seq
        i2c_write_byte(power, slave_addr, 8'h08, 8'h00),
        i2c_write_byte(power, slave_addr, 8'h09, 8'h00),
        i2c_write_byte(power, slave_addr, 8'h0A, 8'h00),
        i2c_write_byte(power, slave_addr, 8'h0B, 8'hFF),
        i2c_write_byte(power, slave_addr, 8'h0C, 8'hFF),
        i2c_write_byte(power, slave_addr, 8'h0D, 8'hFF)
    End;


    function Recipe read_power_min(Wire#(PowerRsp) out) = Seq
        i2c_read_byte(power, slave_addr, 8'h0B),
        action
            let data <- i2c_get_byte(power);
            temp <= {data, temp[15:0]};
        endaction,
        i2c_read_byte(power, slave_addr, 8'h0C),
        action
            let data <- i2c_get_byte(power);
            temp <= {temp[23:16], data, temp[7:0]};
        endaction,
        i2c_read_byte(power, slave_addr, 8'h0D),
        action
            let data <- i2c_get_byte(power);
            temp <= {temp[23:8], data};
        endaction,
        action
            out <= PowerMinValue(temp);
        endaction
    End;

    function Recipe read_power_max(Wire#(PowerRsp) out) = Seq
        i2c_read_byte(power, slave_addr, 8'h08),
        action
            let data <- i2c_get_byte(power);
            temp <= {data, temp[15:0]};
        endaction,
        i2c_read_byte(power, slave_addr, 8'h09),
        action
            let data <- i2c_get_byte(power);
            temp <= {temp[23:16], data, temp[7:0]};
        endaction,
        i2c_read_byte(power, slave_addr, 8'h0A),
        action
            let data <- i2c_get_byte(power);
            temp <= {temp[23:8], data};
        endaction,
        action
            out <= PowerMaxValue(temp);
        endaction
    End;


    FIFO#(PowerReq) dataIn <- mkFIFO1();
    Wire#(PowerRsp) dataOut <- mkWire();

    Recipe fsm = Seq
        device_init(),
        While(True) Seq
            rOneMatch(list(isSetTestMode(dataIn.first),
                           isResetPowerMinMax(dataIn.first),
                           isReadPowerMin(dataIn.first),
                           isReadPowerMax(dataIn.first)),
                      list(Seq
                              If(dataIn.first.SetTestMode)  
                                  test_mode_enable()
                              Else
                                  test_mode_disable()
                              End
                          End,
                          reset_power_min_max(),
                          read_power_min(dataOut),
                          read_power_max(dataOut)),
                      rAct(noAction)),
            dataIn.deq()
            End
        End
    End;

    RecipeFSM main <- mkRecipeFSM( fsm );

    rule run_main;
        main.trigger;
    endrule
    
    interface Server data;
        interface Put request = toPut(dataIn);

        interface Get response;
            method get = actionvalue
                return dataOut;
            endactionvalue;
        endinterface
    endinterface

    interface I2C_Pins i2c = power.i2c;
endmodule: mkPower

interface PowerReaderIfc;
    (* prefix = "POWER_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_min();

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_max();
endinterface

module mkPowerReader #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (PowerReaderIfc);
    Reg#(Bit#(24)) cur_power_min <- mkReg(0);
    Reg#(Bit#(24)) cur_power_max <- mkReg(0);

    Reg#(Bit#(32)) cnt <- mkReg(fromInteger(clk_freq));

    Power power12 <- mkPower(slave_addr, clk_freq);

    PulseWire pw <- mkPulseWire;

    (* fire_when_enabled, no_implicit_conditions *)
    rule counter (cnt > 0);
        cnt <= cnt-1;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule counter_rst (cnt == 0);
        cnt <= fromInteger(50000000);
        pw.send();
    endrule

    Stmt test =
    seq
        while(True)seq
            await(pw);
            power12.data.request.put(SetTestMode(True));
            power12.data.request.put(ReadPowerMin);
            action
                let rsp <- power12.data.response.get();
                if(rsp matches tagged PowerMinValue .v)
                    cur_power_min <= v;
            endaction
            power12.data.request.put(ReadPowerMax); 
            action
                let rsp <- power12.data.response.get();
                if(rsp matches tagged PowerMaxValue .v)
                    cur_power_max <= v;
            endaction
            power12.data.request.put(ResetPowerMinMax);
            power12.data.request.put(SetTestMode(False));
        endseq
    endseq;

    FSM main <- mkFSM( test );

    rule run_main;
        main.start();
    endrule

    interface i2c = power12.i2c;

    method get_power_min = cur_power_min;

    method get_power_max = cur_power_max;
endmodule

(* synthesize *)
module mkDE10PowerReader(PowerReaderIfc);
    let t <- mkPowerReader(7'b1101010, 50000000); //DE10 12v Power IC addr 0xD4/D5 50MHz Clock Rate
    return t;
endmodule
endpackage: Power
