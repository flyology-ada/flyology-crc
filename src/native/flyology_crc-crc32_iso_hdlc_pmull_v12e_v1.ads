with Interfaces;
with System;

private package Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1 is
   use type Interfaces.Unsigned_32;

   --  State is the raw reflected CRC register before Final_XOR.  The caller
   --  must establish both AArch64 CRC32 and PMULL availability before calling
   --  with nonempty data.  Empty input is an identity operation; the
   --  scalar-selected body raises Program_Error for nonempty input.
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32
   with Post => (if Data'Length = 0 then Update'Result = State);

   function Update_V12_64_Tail
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length >= 448 and then (Data'Length - 256) mod 192 = 0;

   function Update_1024_V12
     (State  : Interfaces.Unsigned_32;
      Source : System.Address) return Interfaces.Unsigned_32;
   --  Source borrows exactly 1,024 readable bytes.  The caller establishes
   --  CRC32+PMULL availability; the leaf performs no allocation or copy.

end Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1;
