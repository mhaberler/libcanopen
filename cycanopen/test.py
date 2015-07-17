from canopen import *

f = CANFrame(can_id=47,data="foo")
print str(f),f.can_id,f.can_dlc

f.data = "AB"
print str(f),f.can_dlc
f.can_id = 0x42
print str(f)
f.data = "Z"
print str(f)

o = CANopenFrame()
print str(o)
o.data = "AB"
print str(o)

o2 = CANopenFrame(rtr=1,function_code=2,type=3,id=4,data="123")
print str(o2)
print o2.rtr,o2.function_code, o2.type, o2.id

c = CANopen(interface="vcan0")
print c
print "from another window, execute: 'cansend vcan0 123#DEADBEEF'"
f = c.read_can_frame()
print str(f)
cof = c.parse_can_frame(f)
print str(cof)

cof.dump()



cof2 = c.read_frame()
print str(cof2)

