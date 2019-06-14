
from .distributions cimport bitgen_t

cdef class BitGenerator():
    cdef public object _seed
    cdef public object lock
    cdef bitgen_t _bitgen
    cdef public object _ctypes
    cdef public object _cffi
    cdef public object capsule
