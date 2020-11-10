package Power;

import I2C::*;
import I2CUtil::*;
import StmtFSM::*;

interface Power;
    interface I2C_Pins i2c;

    method Stmt init();

    method Stmt test_mode_enable();
    method Stmt test_mode_disable();

    method Stmt reset_power_min_max();
    
    method Stmt read_power_min(Reg#(Bit#(24)) result);
    method Stmt read_power_max(Reg#(Bit#(24)) result);
endinterface

module mkPower #(parameter Bit#(7) slave_addr) (Power);
    I2C power <- mkI2C(125);
    
    method Stmt init() = seq
            i2c_write_byte(power, slave_addr, 8'h00, 8'b00000101);
            i2c_write_byte(power, slave_addr, 8'h01, 8'b00000000);
        endseq;

    method Stmt test_mode_enable() = seq
            i2c_write_byte(power, slave_addr, 8'h00, 8'b00010101);
        endseq;

    method Stmt test_mode_disable() = seq
            i2c_write_byte(power, slave_addr, 8'h00, 8'b00000101);
        endseq;

    method Stmt reset_power_min_max() = seq
            i2c_write_byte(power, slave_addr, 8'h08, 8'h00);
            i2c_write_byte(power, slave_addr, 8'h09, 8'h00);
            i2c_write_byte(power, slave_addr, 8'h0A, 8'h00);
            i2c_write_byte(power, slave_addr, 8'h0B, 8'hFF);
            i2c_write_byte(power, slave_addr, 8'h0C, 8'hFF);
            i2c_write_byte(power, slave_addr, 8'h0D, 8'hFF);
        endseq;

    method Stmt read_power_min(Reg#(Bit#(24)) result);
        seq
            i2c_read_byte(power, slave_addr, 8'h0B);
            action
                let data <- i2c_get_byte(power);
                result <= {data, result[15:0]};
            endaction
            i2c_read_byte(power, slave_addr, 8'h0C);
            action
                let data <- i2c_get_byte(power);
                result <= {result[23:16], data, result[7:0]};
            endaction
            i2c_read_byte(power, slave_addr, 8'h0D);
            action
                let data <- i2c_get_byte(power);
                result <= {result[23:8], data};
            endaction
        endseq;
    endmethod

    method Stmt read_power_max(Reg#(Bit#(24)) result);
        seq
            i2c_read_byte(power, slave_addr, 8'h08);
            action
                let data <- i2c_get_byte(power);
                result <= {data, result[15:0]};
            endaction
            i2c_read_byte(power, slave_addr, 8'h09);
            action
                let data <- i2c_get_byte(power);
                result <= {result[23:16], data, result[7:0]};
            endaction
            i2c_read_byte(power, slave_addr, 8'h0A);
            action
                let data <- i2c_get_byte(power);
                result <= {result[23:8], data};
            endaction
        endseq;
    endmethod
    
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

(* synthesize *)
module mkPowerReader (PowerReaderIfc);
    Reg#(Bit#(24)) cur_power_min <- mkReg(0);
    Reg#(Bit#(24)) cur_power_max <- mkReg(0);

    Reg#(Bit#(32)) cnt <- mkReg(50000000);

    Power power12 <- mkPower(7'b1101010); //DE10 12v Power IC addr 0xD4/D5

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
        power12.init();
        while(True) seq
            power12.test_mode_enable();
            power12.read_power_min(cur_power_min);
            power12.read_power_max(cur_power_max);
            power12.reset_power_min_max();
            power12.test_mode_disable();
            pw.send();
            await(cnt == 0);
        endseq
    endseq;

    FSM main <- mkFSM( test );

    rule run_main;
        main.start();
    endrule

    interface I2C_Pins i2c = power12.i2c;

    method Bit#(24) get_power_min();
        return cur_power_min;
    endmethod

    method Bit#(24) get_power_max();
        return cur_power_max;
    endmethod
endmodule
endpackage: Power
