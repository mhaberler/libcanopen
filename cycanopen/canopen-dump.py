"""
Read CAN frame, parse into CANopen frame, and dump to STDOUT.
"""

from canopen import *

canopen = CANopen(interface="can0")

while True:
    canopen_frame = canopen.read_frame()
    if canopen_frame:
        canopen_frame.dump()
    else:
        print("CANopen Frame parse error")
