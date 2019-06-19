.. _bit_generator:

.. currentmodule:: numpy.random

Bit Generators
--------------

The random values produced by :class:`~Generator`
orignate in a BitGenerator.  The BitGenerators do not directly provide
random numbers and only contains methods used for seeding, getting or
setting the state, jumping or advancing the state, and for accessing
low-level wrappers for consumption by code that can efficiently
access the functions provided, e.g., `numba <https://numba.pydata.org>`_.

.. toctree::
   :maxdepth: 1

   BitGenerator <bitgenerators>
   DSFMT <dsfmt>
   MT19937 <mt19937>
   PCG32 <pcg32>
   PCG64 <pcg64>
   Philox <philox>
   ThreeFry <threefry>
   Xoshiro256** <xoshiro256>
   Xoshiro512** <xoshiro512>

Seeding and Entropy
-------------------

A BitGenerator provides a stream of random values. In order to generate
reproducableis streams, BitGenerators support setting their initial state via a
seed. But how best to seed the BitGenerator? On first impulse one would like to
do something like ``[bg(i) for i in range(12)]`` to obtain 12 non-correlated,
independent BitGenerators. However using a highly correlated set of seed could
generate BitGenerators that are correlated or overlap within a few samples.
NumPy uses a `SeedSequence` class to mix the seed in a reproducable way that
introduces the necesarry entroy to produce independent and largely non-
overlapping streams.

.. autosummary::
   :toctree: generated/

    SeedSequence
