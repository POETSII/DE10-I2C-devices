# DE10 I2C Device Modules

Various modules for accessing the I2C devices on the DE10-Pro board.

## Temp.bsv
Temperature sensor, exposes two interfaces:

```bluespec
interface Temp;
    interface I2C_Pins i2c;

    method Stmt init();
    
    method Stmt read_val(Reg#(Bit#(8)) result);
endinterface

module mkTemp #(parameter Bit#(7) slave_addr) (Temp);
```
Allows on demand polling of the sensor IC to read an 8bit temperature value.


```bluespec
interface TempReaderIfc;
    (* prefix = "TEMP_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(8) get_temp ();
endinterface

module mkTempReader (TempReaderIfc);
```
A bundled reader that automatically initialises and then constantly refreshes an internal stored value accessible via the get\_temp method. When given a 50MHz clock the reader will refresh the value once per second.
