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
Allows on demand polling of a sensor IC to read an 8bit temperature value.


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


## Power.bsv
Power monitor, exposes two interfaces:

```bluespec
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
```
Allows on demand polling of the sensor IC to read 24bit values for min and max observed power. Also allows for reset of the min/max registers, test mode must be enabled before reset_power_min_max is called, and must be disabled before normal function resumes.


```bluespec
interface PowerReaderIfc;
    (* prefix = "POWER_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_min();

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_max();
endinterface

module mkPowerReader (PowerReaderIfc);
```
A bundled reader that automatically initialises and then constantly refreshes an internal stored value accessible via the get_power_min and get_power_max methods. The values show the min/max power over the past second, with the values being reset each time the reader refreshes the values. When given a 50MHz clock the reader will refresh the value once per second.