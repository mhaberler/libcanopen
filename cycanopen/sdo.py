"""
Read node info from a CANopen node

# talking to the trinamic:
# mah@nwheezy:~/src/can/libcanopen/cycanopen$ python sdo.py 1
# reply: STANDARD [0x181] FC=0x3 ID=0x01 [2] 0x18 0x06  => PDO1 TX Node=0x1 0x18 0x06 
#  Vendor  ID   = 0x00000286
# Product ID   = 0x00000488
# Software Ver = 0x00030012
# reply: STANDARD [0x701] FC=0xE ID=0x01 [1] 0x05  => NMT [Node Guarding] Node=0x01 State='Operational'
#  ** no reply **
# ** no reply **


"""

import sys,time
from canopen import *


def tryread():
    try:
        f = canopen.read_frame()
        print "reply: ",
        f.dump()
        return f
    except Exception:
        print "** no reply **"

canopen = CANopen(interface="can0",timeout=300)

if len(sys.argv) == 2:
    # get the node address from the first command-line argument
    node = int(sys.argv[1])
else:
    print("usage: %s NODE" % sys.argv[0])
    exit(1)

canopen.nmt_send(node, 1) # start
tryread()

value = canopen.SDOUploadExp(node, 0x1018, 0x01)
print("Vendor  ID   = 0x%.8X" % value)

value = canopen.SDOUploadExp(node, 0x1018, 0x02)
print("Product ID   = 0x%.8X" % value)

value = canopen.SDOUploadExp(node, 0x1018, 0x03)
print("Software Ver = 0x%.8X" % value)

canopen.nmt_send(node, 0) # poll
tryread()
canopen.nmt_send(node, 1) # start
tryread()

canopen.nmt_send(node, 2) # stop
tryread()



