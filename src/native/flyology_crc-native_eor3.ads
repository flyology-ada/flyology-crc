with Interfaces;

private package Flyology_CRC.Native_EOR3 is
   function Compiled return Boolean;

   --  The 16-byte granularity is one Advanced SIMD vector.  Complete 128-byte
   --  stripes take the shared fold-by-eight geometry; every other block is
   --  folded one at a time.  This matches the baseline private PMULL entry
   --  points and is not a production dispatch threshold.
   function Update_PMULL_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16
   with Pre => Data'Length >= 16 and then Data'Length mod 16 = 0;

   function Update_PMULL_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length >= 16 and then Data'Length mod 16 = 0;

   function Update_PMULL_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64
   with Pre => Data'Length >= 16 and then Data'Length mod 16 = 0;
   --  These private entry points execute in the selected +aes+sha3 leaf.
   --  Callers must first establish both PMULL_Available and SHA3_Available.
   --  State is the raw algorithm-form register before Final_XOR.
end Flyology_CRC.Native_EOR3;
