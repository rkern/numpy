
from .distributions cimport bitgen_t
cimport numpy as np

cdef class BitGenerator():
    cdef public object _seed_seq
    cdef public object lock
    cdef bitgen_t _bitgen
    cdef public object _ctypes
    cdef public object _cffi
    cdef public object capsule


cdef class SeedSequence():
    cdef readonly object entropy
    cdef readonly object program_entropy
    cdef readonly tuple spawn_key
    cdef readonly int pool_size
    cdef readonly object pool
    cdef readonly int n_children_spawned

    cdef mix_entropy(self, np.ndarray[np.npy_uint32, ndim=1] mixer,
                     np.ndarray[np.npy_uint32, ndim=1] entropy_array)
