package I2CUtil;

import I2C::*;
import ClientServer::*;
import GetPut::*;

function Action i2c_write_byte(I2C i2c, Bit#(7) dev_addr, Bit#(8) cfgr, Bit#(8) val) =
    i2c.user.request.put(I2CRequest { write: True, slaveaddr: dev_addr, address: cfgr, data: val });


function Action i2c_read_byte(I2C i2c, Bit#(7) dev_addr, Bit#(8) cfgr) =
    i2c.user.request.put(I2CRequest { write: False, slaveaddr: dev_addr, address: cfgr, data: 8'b0 });

function ActionValue#(Bit#(8)) i2c_get_byte(I2C i2c) = 
    actionvalue
        let rsp <- i2c.user.response.get();
        return rsp.data;
    endactionvalue;

endpackage: I2CUtil
