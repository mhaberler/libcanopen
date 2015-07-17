cimport cython
from cpython.bool cimport *
from os import strerror,getpid
from cpython.bytes cimport PyBytes_AsString, PyBytes_Size, PyBytes_FromStringAndSize
from cpython.string cimport PyString_FromStringAndSize
from libc.string cimport memcpy
cimport posix.unistd# cimport read,write
from buffer cimport PyBuffer_FillInfo

from .can cimport *
#from .can_if cimport *
#from .canopen cimport *

    # ctypedef struct X_frame:
    #     canid_t can_id  # 32 bit CAN_ID + EFF/RTR/ERR flags */
    #     uint8_t can_dlc # frame payload length in byte (0 .. CAN_MAX_DLEN) */
    #     uint8_t *data   #[CAN_MAX_DLEN] __attribute__((aligned(8)))

cdef class mview:
    cdef void *base
    cdef int size

    def __cinit__(self, long base, size):
        self.base = <void *>base
        self.size = size

    def __getbuffer__(self, Py_buffer *view, int flags):
        r = PyBuffer_FillInfo(view, self, self.base, self.size, 0, flags)
        view.obj = self

cdef class CANFrame:
    cdef canopen_nmt_ng_t x
    cdef can_frame f

    def __cinit__(self, can_id=0, data=None):
        self.f.can_id = 0
        self.f.can_dlc = 0
        self.data = data

    property can_id:
        def __get__(self): return self.f.can_id
        def __set__(self,uint32_t value):  self.f.can_id = value

    property can_dlc:
        def __get__(self): return self.f.can_dlc
        def __set__(self,uint8_t value):  self.f.can_dlc = value

    property data:
        def __get__(self): return  memoryview(mview(<long>&self.f.data, self.dlen))
        def __set__(self,s):
            if s:
                size = PyBytes_Size(s)
                if size > CAN_MAX_DLEN:
                    raise RuntimeError("data size %d too large" % size)
                self.f.can_dlc = size
                memcpy(self.f.data, PyBytes_AsString(s), size)

    def __str__(self):
        data_str = " ".join(["%.2x" % (x,) for x in self.f.data])
        return "CAN Frame: ID=%.2x DLC=%.2x DATA=[%s]" % (self.f.can_id, self.f.can_dlc, data_str)

# class CANopenFrame(Structure):
#     _fields_ = [("rtr",           c_uint8),
#                 ("function_code", c_uint8),
#                 ("type",          c_uint8),
#                 ("id",            c_uint32),
#                 ("data",          c_uint8 * 8), # should be a union...
#                 ("data_len",      c_uint8)]

#     def __str__(self):
#         data_str = " ".join(["%.2x" % (x,) for x in self.data])    
#         return "CANopen Frame: RTR=%d FC=0x%.2x ID=0x%.2x [len=%d] %s" % (self.rtr, self.function_code, self.id, self.data_len, data_str)



class CANopen:

    def __init__(self, interface="can0"):
        """
        Constructor for CANopen class. Optionally takes an interface 
        name for which to bind a socket to. Defaults to interface "can0"
        """
        pass #self.sock = can_socket_open(interface)

    def open(self, interface):
        """
        Open a new socket. If open socket already exist, close it first.
        """
        if self.sock:
            self.close()
        pass #self.sock = can_socket_open(interface)

    def close(self):
        """
        Close the socket associated with this class instance.
        """
        if self.sock:
            pass #can_socket_close(self.sock)
            self.sock = None

    def read_can_frame(self):
        """
        Low-level function: Read a CAN frame from socket.
        """
        if self.sock:
            cf = CANFrame()
            if posix.unistd.read(self.sock, <void *>&cf.f, 16) != 16:
                raise Exception("CAN frame read error")
            return cf
        else:
            raise Exception("CAN fram read error: socket not connected")

        
    # def parse_can_frame(self, can_frame):
    #     """
    #     Low level function: Parse a given CAN frame into CANopen frame
    #     """
    #     canopen_frame = CANopenFrame()
    #     if canopen_frame_parse(byref(canopen_frame), byref(can_frame)) == 0:
    #         return canopen_frame
    #     else:
    #         raise Exception("CANopen Frame parse error")

    # def read_frame(self):
    #     """
    #     Read a CANopen frame from socket. First read a CAN frame, then parse
    #     into a CANopen frame and return it.
    #     """
    #     can_frame = self.read_can_frame()
    #     if not can_frame:
    #         raise Exception("CAN Frame read error")

    #     canopen_frame = self.parse_can_frame(can_frame)
    #     if not canopen_frame:
    #         raise Exception("CANopen Frame parse error")

    #     return canopen_frame

    # #---------------------------------------------------------------------------
    # # SDO related functions
    # #

    # #
    # # EXPEDIATED
    # #

    # def SDOUploadExp(self, node, index, subindex):
    #     """
    #     Expediated SDO upload
    #     """
    #     res = c_uint32()
    #     ret = libcanopen.canopen_sdo_upload_exp(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), byref(res))

    #     if ret != 0:
    #         raise Exception("CANopen Expediated SDO upload error")

    #     return res.value
        

    # def SDODownloadExp(self, node, index, subindex, data, size):
    #     """
    #     Expediated SDO download
    #     """

    #     ret = canopen_sdo_download_exp(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), c_uint32(data), c_uint16(size))

    #     if ret != 0:
    #         raise Exception("CANopen Expediated SDO download error")


    # #
    # # SEGMENTED
    # #      
        
    # def SDOUploadSeg(self, node, index, subindex, size):
    #     """
    #     Segmented SDO upload
    #     """
    #     data = create_string_buffer(size)
    #     ret = canopen_sdo_upload_seg(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), data, c_uint16(size));

    #     if ret < 0:
    #         raise Exception("CANopen Segmented SDO upload error: ret = %d" % ret)

    #     hex_str = "".join(["%.2x" % ord(data[i]) for i in range(ret)])
    #     #[0:-2]

    #     return hex_str

       
    # def SDODownloadSeg(self, node, index, subindex, str_data, size):
    #     """
    #     Segmented SDO download
    #     """
    #     n = len(str_data)/2
    #     data = create_string_buffer(''.join([chr(int(str_data[2*n:2*n+2],16)) for n in range(n)]))

    #     ret = canopen_sdo_download_seg(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), data, c_uint16(n));

    #     if ret != 0:
    #         raise Exception("CANopen Segmented SDO download error")

    # #
    # # BLOCK
    # #

    # def SDOUploadBlock(self, node, index, subindex, size):
    #     """
    #     Block SDO upload.
    #     """
    #     data = create_string_buffer(size)
    #     ret = canopen_sdo_upload_block(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), data, c_uint16(size));

    #     if ret != 0:
    #         raise Exception("CANopen Block SDO upload error")

    #     hex_str = "".join(["%.2x" % ord(d) for d in data])[0:-2]

    #     return hex_str
        
        
    # def SDODownloadBlock(self, node, index, subindex, str_data, size):
    #     """
    #     Block SDO download.
    #     """
    #     n = len(str_data)/2
    #     data = create_string_buffer(''.join([chr(int(str_data[2*n:2*n+2],16)) for n in range(n)]))

    #     ret = canopen_sdo_download_block(self.sock, c_uint8(node), c_uint16(index), c_uint8(subindex), data, c_uint16(n+1));

    #     if ret != 0:
    #         raise Exception("CANopen Block SDO download error")

    
