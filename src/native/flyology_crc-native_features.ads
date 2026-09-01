private package Flyology_CRC.Native_Features is
   --  Each result is detected once at elaboration and fails closed.  CRC32
   --  and SHA3 are independent capability facts; callers of fused kernels
   --  must also establish PMULL availability.
   function PMULL_Available return Boolean
   with Inline_Always;

   function CRC32_Available return Boolean
   with Inline_Always;

   function SHA3_Available return Boolean
   with Inline_Always;

   function PMULL_64_1024_Reflected_Preferred return Boolean
   with Inline_Always;
   --  True only on the Linux AArch64 tier for which the fixed-geometry
   --  baseline PMULL leaf is intended.  Other platform bodies fail closed.
end Flyology_CRC.Native_Features;
