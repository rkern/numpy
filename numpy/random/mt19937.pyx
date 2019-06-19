import operator

import numpy as np
cimport numpy as np

from .common cimport *
from .bit_generator cimport BitGenerator, SeedSequence
from .entropy import random_entropy

__all__ = ['MT19937']

np.import_array()

cdef extern from "src/mt19937/mt19937.h":

    struct s_mt19937_state:
        uint32_t key[624]
        int pos

    ctypedef s_mt19937_state mt19937_state

    uint64_t mt19937_next64(mt19937_state *state)  nogil
    uint32_t mt19937_next32(mt19937_state *state)  nogil
    double mt19937_next_double(mt19937_state *state)  nogil
    void mt19937_init_by_array(mt19937_state *state, uint32_t *init_key, int key_length)
    void mt19937_seed(mt19937_state *state, uint32_t seed)
    void mt19937_jump(mt19937_state *state)

cdef uint64_t mt19937_uint64(void *st) nogil:
    return mt19937_next64(<mt19937_state *> st)

cdef uint32_t mt19937_uint32(void *st) nogil:
    return mt19937_next32(<mt19937_state *> st)

cdef double mt19937_double(void *st) nogil:
    return mt19937_next_double(<mt19937_state *> st)

cdef uint64_t mt19937_raw(void *st) nogil:
    return <uint64_t>mt19937_next32(<mt19937_state *> st)

cdef class MT19937(BitGenerator):
    """
    MT19937(seed=None)

    Container for the Mersenne Twister pseudo-random number generator.

    Parameters
    ----------
    seed : {None, int, array_like, SeedSequence}, optional
        Random seed used to initialize the pseudo-random number generator.  Can
        be any integer between 0 and 2**32 - 1 inclusive, an array (or other
        sequence) of unsigned 32-bit integers, a `SeedSequence`, or ``None``
        (the default).  If `seed` is ``None``, a 32-bit unsigned integer is
        read from ``/dev/urandom`` (or the Windows equivalent) if available. If
        unavailable, a 32-bit hash of the time and process ID is used.

    Attributes
    ----------
    lock: threading.Lock
        Lock instance that is shared so that the same bit git generator can
        be used in multiple Generators without corrupting the state. Code that
        generates values from a bit generator should hold the bit generator's
        lock.

    Notes
    -----
    ``MT19937`` provides a capsule containing function pointers that produce
    doubles, and unsigned 32 and 64- bit integers [1]_. These are not
    directly consumable in Python and must be consumed by a ``Generator``
    or similar object that supports low-level access.

    The Python stdlib module "random" also contains a Mersenne Twister
    pseudo-random number generator.

    **State and Seeding**

    The ``MT19937`` state vector consists of a 768-element array of
    32-bit unsigned integers plus a single integer value between 0 and 768
    that indexes the current position within the main array.

    ``MT19937`` is seeded using either a single 32-bit unsigned integer
    or a vector of 32-bit unsigned integers.  In either case, the input seed is
    used as an input (or inputs) for a hashing function, and the output of the
    hashing function is used as the initial state. Using a single 32-bit value
    for the seed can only initialize a small range of the possible initial
    state values.

    **Parallel Features**

    The preferred way to use a BitGenerator in parallel applications is to use
    the `SeedSequence.spawn` method to obtain entropy values, and to use these
    to generate new BitGenerators:

    >>> from numpy.random import Generator, MT19937, SeedSequence
    >>> sg = SeedSequence(1234)
    >>> rg = [Generator(MT19937(s)) for s in sg.spawn(10)]

    Another method is to use `MT19937.jumped` which advances the state as-if
    :math:`2^{128}` random numbers have been generated ([1]_, [2]_). This
    allows the original sequence to be split so that distinct segments can be
    used in each worker process. All generators should be chained to ensure
    that the segments come from the same sequence.

    >>> from numpy.random.entropy import random_entropy
    >>> from numpy.random import Generator, MT19937
    >>> seed = random_entropy()
    >>> bit_generator = MT19937(seed)
    >>> rg = []
    >>> for _ in range(10):
    ...    rg.append(Generator(bit_generator))
    ...    # Chain the BitGenerators
    ...    bit_generator = bit_generator.jumped()

    **Compatibility Guarantee**

    ``MT19937`` makes a guarantee that a fixed seed and will always produce
    the same random integer stream.

    References
    ----------
    .. [1] Hiroshi Haramoto, Makoto Matsumoto, and Pierre L\'Ecuyer, "A Fast
        Jump Ahead Algorithm for Linear Recurrences in a Polynomial Space",
        Sequences and Their Applications - SETA, 290--298, 2008.
    .. [2] Hiroshi Haramoto, Makoto Matsumoto, Takuji Nishimura, François
        Panneton, Pierre L\'Ecuyer, "Efficient Jump Ahead for F2-Linear
        Random Number Generators", INFORMS JOURNAL ON COMPUTING, Vol. 20,
        No. 3, Summer 2008, pp. 385-390.

    """
    cdef mt19937_state rng_state

    def __init__(self, seed=None):
        BitGenerator.__init__(self, seed)
        self.seed(seed)

        self._bitgen.state = &self.rng_state
        self._bitgen.next_uint64 = &mt19937_uint64
        self._bitgen.next_uint32 = &mt19937_uint32
        self._bitgen.next_double = &mt19937_double
        self._bitgen.next_raw = &mt19937_raw

    def seed(self, seed=None):
        """
        seed(seed=None)

        Seed the generator.

        Parameters
        ----------
        seed : {None, int, array_like, SeedSequence}, optional
            Random seed initializing the pseudo-random number generator.
            Can be an integer in [0, 2**32-1], array of integers in
            [0, 2**32-1], a `SeedSequence, or ``None`` (the default). If `seed`
            is ``None``, then ``MT19937`` will try to read entropy from
            ``/dev/urandom`` (or the Windows equivalent) if available to
            produce a 32-bit seed. If unavailable, a 32-bit hash of the time
            and process ID is used.

        Raises
        ------
        ValueError
            If seed values are out of range for the PRNG.
        """
        cdef np.ndarray obj
        with self.lock:
            try:
                if seed is None:
                    try:
                        seed = random_entropy(1)
                    except RuntimeError:
                        seed = random_entropy(1, 'fallback')
                    mt19937_seed(&self.rng_state, seed[0])
                elif isinstance(seed, SeedSequence):
                    val = self._seed_seq.generate_state(1, np.uint32)
                    mt19937_seed(&self.rng_state, val[0])
                else:
                    if hasattr(seed, 'squeeze'):
                        seed = seed.squeeze()
                    idx = operator.index(seed)
                    if idx > int(2**32 - 1) or idx < 0:
                        raise ValueError("Seed must be between 0 and 2**32 - 1")
                    mt19937_seed(&self.rng_state, seed)
            except TypeError:
                obj = np.asarray(seed)
                if obj.size == 0:
                    raise ValueError("Seed must be non-empty")
                obj = obj.astype(np.int64, casting='safe')
                if obj.ndim != 1:
                    raise ValueError("Seed array must be 1-d")
                if ((obj > int(2**32 - 1)) | (obj < 0)).any():
                    raise ValueError("Seed must be between 0 and 2**32 - 1")
                obj = obj.astype(np.uint32, casting='unsafe', order='C')
                mt19937_init_by_array(&self.rng_state, <uint32_t*> obj.data, np.PyArray_DIM(obj, 0))

    cdef jump_inplace(self, iter):
        """
        Jump state in-place

        Not part of public API

        Parameters
        ----------
        iter : integer, positive
            Number of times to jump the state of the rng.
        """
        cdef np.npy_intp i
        for i in range(iter):
            mt19937_jump(&self.rng_state)


    def jumped(self, np.npy_intp jumps=1):
        """
        jumped(jumps=1)

        Returns a new bit generator with the state jumped

        The state of the returned big generator is jumped as-if
        2**(128 * jumps) random numbers have been generated.

        Parameters
        ----------
        jumps : integer, positive
            Number of times to jump the state of the bit generator returned

        Returns
        -------
        bit_generator : MT19937
            New instance of generator jumped iter times
        """
        cdef MT19937 bit_generator

        bit_generator = self.__class__()
        bit_generator.state = self.state
        bit_generator.jump_inplace(jumps)

        return bit_generator

    @property
    def state(self):
        """
        Get or set the PRNG state

        Returns
        -------
        state : dict
            Dictionary containing the information required to describe the
            state of the PRNG
        """
        key = np.zeros(624, dtype=np.uint32)
        for i in range(624):
            key[i] = self.rng_state.key[i]

        return {'bit_generator': self.__class__.__name__,
                'state': {'key': key, 'pos': self.rng_state.pos}}

    @state.setter
    def state(self, value):
        if isinstance(value, tuple):
            if value[0] != 'MT19937' or len(value) not in (3, 5):
                raise ValueError('state is not a legacy MT19937 state')
            value ={'bit_generator': 'MT19937',
                    'state': {'key': value[1], 'pos': value[2]}}

        if not isinstance(value, dict):
            raise TypeError('state must be a dict')
        bitgen = value.get('bit_generator', '')
        if bitgen != self.__class__.__name__:
            raise ValueError('state must be for a {0} '
                             'PRNG'.format(self.__class__.__name__))
        key = value['state']['key']
        for i in range(624):
            self.rng_state.key[i] = key[i]
        self.rng_state.pos = value['state']['pos']
