private package Flyology_CRC.X86_Features is
   --  Results are immutable runtime capability facts.  The x86-64 body uses
   --  baseline-safe CPUID and guarded XGETBV; other selected bodies fail
   --  closed.  Callers must still select the matching isolated instruction
   --  leaf before executing optional instructions.
   function Generic_SSE_Available return Boolean
   with Inline_Always;

   function CRC32C_SSE_Available return Boolean
   with Inline_Always;

   function AVX512_Ternary_Available return Boolean
   with Inline_Always;

   function CRC32C_VPCLMUL_Available return Boolean
   with Inline_Always;

   function AVX512_VPCLMUL_Available return Boolean
   with Inline_Always;
end Flyology_CRC.X86_Features;
