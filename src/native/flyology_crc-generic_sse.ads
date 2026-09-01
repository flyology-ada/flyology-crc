with Interfaces;

private package Flyology_CRC.Generic_SSE is
   function Compiled return Boolean;

   function Update_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;

   function Update_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;

   function Update_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;
   --  These raw-state entry points are isolated in a source-selected leaf.
   --  Callers must establish X86_Features.Generic_SSE_Available before using
   --  an x86-64 body; the other architecture bodies fail closed.
end Flyology_CRC.Generic_SSE;
