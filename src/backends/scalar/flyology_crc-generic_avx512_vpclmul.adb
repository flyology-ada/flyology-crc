package body Flyology_CRC.Generic_AVX512_VPCLMUL is
   function Compiled return Boolean is (False);

   function Update_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
      pragma Unreferenced (Reflected, Keys);
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the generic x86-64 AVX-512 VPCLMUL kernel is unavailable";
   end Update_16;

   function Update_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
      pragma Unreferenced (Reflected, Keys);
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the generic x86-64 AVX-512 VPCLMUL kernel is unavailable";
   end Update_32;

   function Update_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
      pragma Unreferenced (Reflected, Keys);
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the generic x86-64 AVX-512 VPCLMUL kernel is unavailable";
   end Update_64;
end Flyology_CRC.Generic_AVX512_VPCLMUL;
