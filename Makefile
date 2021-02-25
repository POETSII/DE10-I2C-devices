
BSCFLAGS = -p +:Recipe:Recipe/BlueBasics
BSCFLAGS += -cpp -Xcpp -IRecipe
BSCFLAGS += -verilog
BSCFLAGS += -bdir build


all:
	bsc $(BSCFLAGS) -u Temp.bsv
	bsc $(BSCFLAGS) -u Power.bsv

