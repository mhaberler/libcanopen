cimport cython
from cpython.bool cimport *
from os import strerror,getpid
from cpython.bytes cimport PyBytes_AsString, PyBytes_Size, PyBytes_FromStringAndSize
from cpython.string cimport PyString_FromStringAndSize
from libc.string cimport memcpy,memset
from libc.stdlib cimport malloc, free
cimport posix.unistd# cimport read,write
from buffer cimport PyBuffer_FillInfo

from .canopen cimport *

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
    cdef can_frame f

    def __cinit__(self, can_id=0, data=None):
        memset(<void *>&self.f, 0, sizeof(can_frame))
        self.f.can_id = can_id
        self.f.can_dlc = 0
        self.data = data

    property can_id:
        def __get__(self): return self.f.can_id
        def __set__(self,uint32_t value):  self.f.can_id = value

    property can_dlc:
        def __get__(self): return self.f.can_dlc
        def __set__(self,uint8_t value):  self.f.can_dlc = value

    property data:
        def __get__(self): return  memoryview(mview(<long>&self.f.data, self.f.can_dlc))
        def __set__(self,s):
            if s:
                size = PyBytes_Size(s)
                if size > CAN_MAX_DLEN:
                    raise RuntimeError("data size %d too large" % size)
                self.f.can_dlc = size
                memcpy(self.f.data, PyBytes_AsString(s), size)

    def __str__(self):
        d = ""
        for i in range(self.f.can_dlc):
            d += " %.2x" % (self.f.data[i])
        return "CAN Frame: ID=%.2x DLC=%.2x DATA=[%s]" % (self.f.can_id,
                                                          self.f.can_dlc, d)


cdef class CANopenFrame:
    cdef canopen_frame_t cf

    def __cinit__(self, rtr=0, function_code=0, type=0, id=0, data=None):
        self.cf.rtr = rtr
        self.cf.function_code = function_code
        self.cf.type = type
        self.cf.id = id
        self.cf.data_len = 0
        self.data = data

    property rtr:
        def __get__(self): return self.cf.rtr
        def __set__(self,uint8_t value):  self.cf.rtr = value

    property function_code:
        def __get__(self): return self.cf.function_code
        def __set__(self,uint8_t value):  self.cf.function_code = value

    property type:
        def __get__(self): return self.cf.type
        def __set__(self,uint8_t value):  self.cf.type = value

    property id:
        def __get__(self): return self.cf.id
        def __set__(self,uint32_t value):  self.cf.id = value

    property data:
        def __get__(self): return  memoryview(mview(<long>self.cf.payload.data, self.cf.can_data_len))
        def __set__(self,s):
            if s:
                size = PyBytes_Size(s)
                if size > CAN_MAX_DLEN: # FIXME is this right?
                    raise RuntimeError("data size %d too large" % size)
                self.cf.data_len = size
                memcpy(self.cf.payload.data, PyBytes_AsString(s), size)

    def dump(self):
        canopen_frame_dump_short(&self.cf)

    def send(self, socket):
        cdef can_frame f
        if canopen_frame_pack(&self.cf, &f) != 0:
            raise RuntimeError("pack failed")
        n = posix.unistd.write(socket, &f, sizeof(can_frame))
        if n < sizeof(can_frame):
            raise RuntimeError("write failed rc=%d" % n)

    def __str__(self):
        d = ""
        for i in range(self.cf.data_len):
            d += " %.2x" % (self.cf.payload.data[i])
        return "CANopen Frame: RTR=%d FC=0x%.2x ID=0x%.2x [len=%d] %s" % (
            self.cf.rtr,
            self.cf.function_code,
            self.cf.id,
            self.cf.data_len, d)


cdef class NMTFrame(CANopenFrame):
    def __cinit__(self, int node, int cs):
        if cs == 0:
            canopen_frame_set_nmt_ng(&self.cf, node)
        else:
            canopen_frame_set_nmt_mc(&self.cf, cs, node)


class CANopen:

    def __init__(self, interface="can0", timeout=0):
        """
        Constructor for CANopen class. Optionally takes an interface 
        name for which to bind a socket to. Defaults to interface "can0"
        optionally set a read timeout in ms
        defaults to blocking forever
        """
        self.sock = can_socket_open(interface, timeout)

    def nmt_send(self, int node, int cs):
        nf = NMTFrame(node, cs)
        nf.send(self.sock)

    def open(self, interface, timeout=0):
        """
        Open a new socket. If open socket already exist, close it first.
        """
        if self.sock:
            self.close()
        self.sock = can_socket_open(interface, timeout)

    def close(self):
        """
        Close the socket associated with this class instance.
        """
        if self.sock:
            can_socket_close(self.sock)
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


    def parse_can_frame(self, CANFrame cf):
        """
        Low level function: Parse a given CAN frame into CANopen frame
        """
        cof = CANopenFrame()
        if canopen_frame_parse(&cof.cf, &cf.f) == 0:

            return cof
        else:
            raise Exception("CANopen Frame parse error")


    def read_frame(self):
        """
        Read a CANopen frame from socket. First read a CAN frame, then parse
        into a CANopen frame and return it.
        """
        can_frame = self.read_can_frame()
        if not can_frame:
            raise Exception("CAN Frame read error")

        canopen_frame = self.parse_can_frame(can_frame)
        if not canopen_frame:
            raise Exception("CANopen Frame parse error")

        return canopen_frame

    # #---------------------------------------------------------------------------
    # # SDO related functions
    # #

    # #
    # # EXPEDIATED
    # #

    def SDOUploadExp(self, uint8_t node, uint16_t index, uint8_t subindex):
        """
        Expediated SDO upload
        """
        cdef uint32_t res
        ret = canopen_sdo_upload_exp(self.sock, node, index, subindex, &res)

        if ret != 0:
            raise Exception("CANopen Expediated SDO upload error ret=%d" % ret)
        return res


    def SDODownloadExp(self,  uint8_t node, uint16_t index, uint8_t subindex, uint32_t data, uint16_t size):
        """
        Expediated SDO download
        """

        ret = canopen_sdo_download_exp(self.sock, node, index, subindex, data, size)

        if ret != 0:
            raise Exception("CANopen Expediated SDO download error ret=%d" % ret)



    # #
    # # SEGMENTED

    def SDOUploadSeg(self, uint8_t node, uint16_t index, uint8_t subindex, uint16_t size):
        """
        Segmented SDO upload
        """
        cdef uint8_t *ptr
        ptr = <uint8_t *>malloc(size*cython.sizeof(uint8_t))
        if ptr is NULL:
            raise MemoryError()
        ret = canopen_sdo_upload_seg(self.sock, node, index, subindex, ptr, size)
        if ret < 0:
            raise Exception("CANopen Segmented SDO upload error: ret = %d" % ret)

        hex_str = "".join(["%.2x" % ord(ptr[i]) for i in range(ret)])
        free(<void *>ptr)
        #[0:-2]

        return hex_str

       
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

    
