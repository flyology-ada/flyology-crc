package body Flyology_CRC.Native is
   function Compiled return Boolean is (False);

   function Load_16 (Source : System.Address) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Xor_128 (Left, Right : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Reverse_Bytes_128 (Value : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Carryless_Multiply_00
     (Left, Right : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Carryless_Multiply_01
     (Left, Right : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Carryless_Multiply_10
     (Left, Right : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Carryless_Multiply_11
     (Left, Right : Machine_Vector) return Machine_Vector is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Update_PMULL_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Update_PMULL_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Update_PMULL_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");

   function Update_PMULL_64_1024_Reflected
     (State  : Interfaces.Unsigned_64;
      Keys   : Folding_Keys;
      Source : System.Address) return Interfaces.Unsigned_64 is
     (raise Program_Error with "the AArch64 CRC native backend is not compiled");
end Flyology_CRC.Native;
