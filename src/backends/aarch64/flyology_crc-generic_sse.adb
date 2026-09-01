package body Flyology_CRC.Generic_SSE is
   function Compiled return Boolean is (False);

   function Update_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
     (raise Program_Error with "the x86-64 generic SSE backend is not compiled");

   function Update_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
     (raise Program_Error with "the x86-64 generic SSE backend is not compiled");

   function Update_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
     (raise Program_Error with "the x86-64 generic SSE backend is not compiled");
end Flyology_CRC.Generic_SSE;
