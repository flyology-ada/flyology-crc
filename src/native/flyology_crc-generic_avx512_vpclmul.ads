with Interfaces;

private package Flyology_CRC.Generic_AVX512_VPCLMUL is
   function Compiled return Boolean;

   function Update_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16
   with Pre => Data'Length >= 256 and then Data'Length mod 128 = 0;

   function Update_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length >= 256 and then Data'Length mod 128 = 0;

   function Update_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64
   with Pre => Data'Length >= 256 and then Data'Length mod 128 = 0;
   --  Each function consumes the supplied complete 128-byte stripes and
   --  returns the raw algorithm-form register before Final_XOR.  Callers keep
   --  any suffix shorter than 128 bytes in their existing table path.
end Flyology_CRC.Generic_AVX512_VPCLMUL;
