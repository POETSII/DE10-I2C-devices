# DE10 I2C Device Modules

Various modules for accessing the I2C devices on the DE10-Pro board.

## Temp.bsv
Temperature sensor, exposes two interfaces:

```bluespec
typedef union tagged {
    void ReadTemp;
} TempReq
  deriving (Bits);

typedef union tagged {
    Bit#(8) TempVal;
} TempRsp
  deriving (Bits);

interface Temp;
    interface I2C_Pins i2c;

    interface Server#(TempReq, TempRsp) data;
endinterface

module mkTemp #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (Temp);
```
Allows on demand polling of a sensor IC to read an 8bit temperature value.


```bluespec
interface TempReaderIfc;
    (* prefix = "TEMP_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(8) get_temp ();
endinterface

module mkTempReader #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (TempReaderIfc);
module mkDE10TempReader (TempReaderIfc);
```
A bundled reader that automatically initialises and then constantly refreshes an internal stored value accessible via the get\_temp method. Refreshes the value once per second.

mkDE10TempReader auto sets the slave\_addr to the appropriate value for the DE10 and clk\_freq to 50MHz.


## Power.bsv
Power monitor, exposes two interfaces:

```bluespec
typedef union tagged {
    Bool SetTestMode;
    void ResetPowerMinMax;
    void ReadPowerMin;
    void ReadPowerMax;
} PowerReq
  deriving (Bits);

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
```
Allows on demand polling of the sensor IC to read 24bit values for min and max observed power. Also allows for reset of the min/max registers, test mode must be enabled before ResetPowerMinMax is sent, and must be disabled before normal function resumes.


```bluespec
interface PowerReaderIfc;
    (* prefix = "POWER_I2C" *)
    interface I2C_Pins i2c;

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_min();

    (* always_enabled, always_ready *)
    method Bit#(24) get_power_max();
endinterface

module mkPowerReader #(parameter Bit#(7) slave_addr, parameter Integer clk_freq) (PowerReaderIfc);
module mkDE10PowerReader(PowerReaderIfc);
```
A bundled reader that automatically initialises and then constantly refreshes an internal stored value accessible via the get\_power\_min and get\_power\_max methods. The values show the min/max power over the past second, with the values being reset each time the reader refreshes the values. The reader refreshs the value once per second.

DE10PowerReader creates a PowerReader with the slave\_addr set for the DE10 12V power monitor chip and for a 50MHz clock.
