package body Flyology_CRC.X86_Features is
   function Generic_SSE_Available return Boolean is (False);

   function CRC32C_SSE_Available return Boolean is (False);

   function AVX512_Ternary_Available return Boolean is (False);

   function CRC32C_VPCLMUL_Available return Boolean is (False);

   function AVX512_VPCLMUL_Available return Boolean is (False);
end Flyology_CRC.X86_Features;
