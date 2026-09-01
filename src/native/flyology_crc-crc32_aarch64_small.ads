with Interfaces;

private package Flyology_CRC.CRC32_AArch64_Small is
   --  State is the raw reflected CRC register before Final_XOR.  The caller
   --  must establish AArch64 CRC32 availability before calling either
   --  operation with nonempty data.  Empty input always returns State; the
   --  scalar-selected body raises Program_Error for nonempty input.
   function Update_ISCSI
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32;

   function Update_ISO_HDLC
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32;
end Flyology_CRC.CRC32_AArch64_Small;
