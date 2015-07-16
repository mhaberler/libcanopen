cimport cython
from cpython.bool cimport *
from os import strerror,getpid

from .can cimport *
from .canopen cimport *


def hello():
    print "hello world!"
