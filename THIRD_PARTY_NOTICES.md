# Third-party provenance and notices

Flyology CRC is an independent Ada implementation. Some implementation
techniques and constants were adapted from the sources below. This file keeps
their provenance and license notices in one place instead of repeating
benchmark-oracle details throughout the Ada sources.

## CRC parameter catalogue

The predefined algorithm names and Rocksoft-model parameters in
`catalogue/crc-catalogue.toml` are transcribed from Greg Cook's
[Catalogue of parametrised CRC algorithms](https://reveng.sourceforge.io/crc-catalogue/all.htm).
The catalogue provides the literature and standards references supporting each
parameter set.

## Generic carry-less-multiplication folding

The generic folding and Barrett-reduction design follows Intel's
[_Fast CRC Computation for Generic Polynomials Using PCLMULQDQ Instruction_](https://web.archive.org/web/20131224125630/https://www.intel.com/content/dam/www/public/us/en/documents/white-papers/fast-crc-computation-generic-polynomials-pclmulqdq-paper.pdf).
Flyology CRC extends the paper's parallel folding geometry and expresses the
same GF(2) operations through x86-64 PCLMULQDQ/VPCLMULQDQ and AArch64 PMULL.

Some fold layout, dispatch, and reduction code was adapted from
[`crc-fast` 1.10.0](https://github.com/awesomized/crc-fast-rust/tree/3a853cc7daf2cd47cc4466f198680cabdfb0b5fa),
commit `3a853cc7daf2cd47cc4466f198680cabdfb0b5fa`.

Copyright 2025 Don MacAskill

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## CRC-32 instruction fusion

The CRC-32/ISCSI and CRC-32/ISO-HDLC fusion geometries and constants were
generated from Peter Cawley's
[`corsix/fast-crc32`](https://github.com/corsix/fast-crc32) project. The
AArch64 method is also described in Dougall Johnson's
[_Faster CRC32 on the Apple M1_](https://dougallj.wordpress.com/2022/05/22/faster-crc32-on-the-apple-m1/).
The generated implementations were altered and translated to Ada.

Copyright (c) 2023 Peter Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Checksum combination

The width-generic GF(2) matrix method used by `Combine` is an altered Ada
translation of Mark Adler's generalized `crccomb.c` method.

Copyright (C) 2015 Mark Adler

This software is provided 'as-is', without any express or implied warranty. In
no event will the author be held liable for any damages arising from the use of
this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely,
subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim
   that you wrote the original software. If you use this software in a
   product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

Mark Adler

madler@alumni.caltech.edu
