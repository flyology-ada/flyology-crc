with Interfaces;

private package Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3 is
   --  State is the raw reflected CRC-32C register before Final_XOR.  The
   --  caller must establish AArch64 CRC32, PMULL, and SHA3 availability before
   --  calling with nonempty data.  Empty input always returns State; the
   --  scalar-selected body raises Program_Error for nonempty input.
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32;

   function Update_1024_V12
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length = 1_024;
   --  Exact-length v12e_v1 leaf.  The same CRC32+PMULL+SHA3 feature gate as
   --  Update applies; no vector state crosses its single asm boundary.
end Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3;
