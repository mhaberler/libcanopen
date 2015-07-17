from libc.stdint cimport *

cdef extern from "canopen/can-if.h":

    int can_socket_open(char *interface)
    int can_socket_close(int socket)

    int can_filter_node_set(int socket, uint8_t node)
    int can_filter_clear(int socket)


