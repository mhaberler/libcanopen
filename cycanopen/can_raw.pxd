
cdef extern from "linux/can/raw.h":
    int CAN_RAW_FILTER        # set 0 .. n can_filter(s)
    int	CAN_RAW_ERR_FILTER    # set filter for error frames
    int CAN_RAW_LOOPBACK      # local loopback (default:on)
    int CAN_RAW_RECV_OWN_MSGS # receive my own msgs (default:off)
    int CAN_RAW_FD_FRAMES     # allow CAN FD frames (default:off)
