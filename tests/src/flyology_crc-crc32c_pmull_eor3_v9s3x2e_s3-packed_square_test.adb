with Ada.Text_IO;
with Interfaces;
with System.Machine_Code;

procedure Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3.Packed_Square_Test is
   use System.Machine_Code;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   type Vector is array (0 .. 15) of U8;
   for Vector'Alignment use 16;
   pragma Machine_Attribute (Vector, "vector_type");

   function Packed_Byte_Square (Item : U32) return U64 is
      Result  : U64;
      Input   : Vector;
      Squared : Vector;
   begin
      Asm
        (Template =>
           "movi %1.2d, #0" & ASCII.LF & ASCII.HT &
           "ins %1.s[0], %w3" & ASCII.LF & ASCII.HT &
           "pmull %2.8h, %1.8b, %1.8b" & ASCII.LF & ASCII.HT &
           "umov %x0, %2.d[0]",
         Outputs =>
           [U64'Asm_Output ("=r", Result),
            Vector'Asm_Output ("=&w", Input),
            Vector'Asm_Output ("=&w", Squared)],
         Inputs  => U32'Asm_Input ("r", Item));
      return Result;
   end Packed_Byte_Square;

   function Scalar_Square (Item : U32) return U64 is
      Result : U64 := 0;
   begin
      for Bit in 0 .. 31 loop
         if (Item and Interfaces.Shift_Left (U32 (1), Bit)) /= 0 then
            Result := Result or Interfaces.Shift_Left (U64 (1), Bit * 2);
         end if;
      end loop;
      return Result;
   end Scalar_Square;

   Failures : Natural := 0;

   procedure Check (Item : U32) is
   begin
      if Packed_Byte_Square (Item) /= Scalar_Square (Item) then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "FAIL packed square" & U32'Image (Item));
      end if;
   end Check;
begin
   Check (0);
   Check (1);
   Check (16#FFFF_FFFF#);
   Check (16#8000_0000#);
   Check (16#A5C3_6987#);
   for Index in 1 .. 10_000 loop
      Check (U32 (Index) * 16#9E37_79B9# xor U32 (Index / 7));
   end loop;
   if Failures /= 0 then
      raise Program_Error with Failures'Image & " packed-byte PMULL tests failed";
   end if;
   Ada.Text_IO.Put_Line ("packed-byte PMULL matches scalar GF(2) squaring");
end Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3.Packed_Square_Test;
