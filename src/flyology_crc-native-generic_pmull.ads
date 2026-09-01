with Flyology_CRC.Native_Features;

private package Flyology_CRC.Native.Generic_PMULL is
   generic
      type Value is mod <>;
      Width : Positive;
   package Engine is
      function Update_Aligned_Blocks
        (State     : Value;
         Reflected : Boolean;
         Keys      : Folding_Keys;
         Data      : Byte_Array) return Value
      with
        Pre =>
          Width in 16 | 32 | 64
          and then Data'Length >= 128
          and then Data'Length mod 128 = 0
          and then Compiled
          and then Native_Features.PMULL_Available;
      --  State is the raw algorithm-form register, before Final_XOR.  In
      --  particular, a reflected CRC-16 initial value has already been bit
      --  reversed by Generic_Core.Create; CRC-32 and CRC-64 values have not.
   end Engine;
end Flyology_CRC.Native.Generic_PMULL;
