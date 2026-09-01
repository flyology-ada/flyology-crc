package body Flyology_CRC.Native_EOR3 is
   function Compiled return Boolean is (False);

   function Update_PMULL_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
     (raise Program_Error with "the AArch64 CRC EOR3 backend is not compiled");

   function Update_PMULL_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
     (raise Program_Error with "the AArch64 CRC EOR3 backend is not compiled");

   function Update_PMULL_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
     (raise Program_Error with "the AArch64 CRC EOR3 backend is not compiled");
end Flyology_CRC.Native_EOR3;
