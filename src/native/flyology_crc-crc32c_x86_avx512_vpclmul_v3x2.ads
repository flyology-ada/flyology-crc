with Interfaces;

private package Flyology_CRC.CRC32C_X86_AVX512_VPCLMUL_V3X2 is
   --  State is the raw reflected CRC register before Final_XOR.  The caller
   --  must establish X86_Features.CRC32C_VPCLMUL_Available before calling
   --  Update with nonempty data.  Empty input always returns State; non-x86
   --  selected bodies raise Program_Error for nonempty input.
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32;

   --  Private source-selection fact used only by the dedicated stub tests.
   function Compiled return Boolean;
end Flyology_CRC.CRC32C_X86_AVX512_VPCLMUL_V3X2;
