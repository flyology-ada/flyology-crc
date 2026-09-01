with Ada.Text_IO;
with Flyology_CRC.Native_Features;
with Interfaces;

procedure Flyology_CRC.Native.Primitive_Tests is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   pragma Compile_Time_Error
     (Machine_Vector'Size /= 128,
      "native primitive tests require a 128-bit machine vector");
   subtype Vector is Machine_Vector;
   subtype Word is Interfaces.Unsigned_64;
   type Byte_Buffer is array (Natural range <>) of aliased Interfaces.Unsigned_8;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Lane (Value : Vector; High : Boolean) return Word is
      First  : constant Natural := (if High then 8 else 0);
      Result : Word := 0;
   begin
      for Index in 0 .. 7 loop
         Result :=
           Result or
           Interfaces.Shift_Left
             (Word (Value (First + Index)), 8 * Index);
      end loop;
      return Result;
   end Lane;

   function Carryless_Product (Left, Right : Word) return Vector is
      Low  : Word := 0;
      High : Word := 0;
   begin
      for Bit in 0 .. 63 loop
         if (Right and Interfaces.Shift_Left (Word'(1), Bit)) /= 0 then
            Low := Low xor Interfaces.Shift_Left (Left, Bit);
            if Bit /= 0 then
               High := High xor Interfaces.Shift_Right (Left, 64 - Bit);
            end if;
         end if;
      end loop;

      return Result : Vector do
         for Index in 0 .. 7 loop
            Result (Index) :=
              Interfaces.Unsigned_8
                (Interfaces.Shift_Right (Low, 8 * Index) and 16#FF#);
            Result (8 + Index) :=
              Interfaces.Unsigned_8
                (Interfaces.Shift_Right (High, 8 * Index) and 16#FF#);
         end loop;
      end return;
   end Carryless_Product;

   procedure Check_Product
     (Actual : Vector;
      Left   : Word;
      Right  : Word;
      Label  : String) is
   begin
      Check (Actual = Carryless_Product (Left, Right), Label);
   end Check_Product;

   Left_Bytes : aliased Vector :=
     [16#EF#, 16#CD#, 16#AB#, 16#89#, 16#67#, 16#45#, 16#23#, 16#01#,
      16#78#, 16#69#, 16#5A#, 16#4B#, 16#3C#, 16#2D#, 16#1E#, 16#0F#];
   Right_Bytes : aliased Vector :=
     [16#21#, 16#43#, 16#65#, 16#87#, 16#A9#, 16#CB#, 16#ED#, 16#0F#,
      16#F0#, 16#DE#, 16#BC#, 16#9A#, 16#78#, 16#56#, 16#34#, 16#12#];
   Unaligned_Bytes : aliased Byte_Buffer (0 .. 16) := [others => 0];
begin
   Check
     (Machine_Vector'Alignment = 16,
      "native primitive tests require 16-byte machine-vector alignment");
   Check
     (not Native_Features.PMULL_Available or else Compiled,
      "PMULL cannot be available when its backend is not compiled");

   if not Compiled then
      Ada.Text_IO.Put_Line ("AArch64 native primitive tests skipped by scalar build");
      return;
   end if;

   if not Native_Features.PMULL_Available then
      Ada.Text_IO.Put_Line ("AArch64 native primitive tests skipped: PMULL unavailable");
      return;
   end if;

   for Index in Vector'Range loop
      Unaligned_Bytes (Index + 1) := Left_Bytes (Index);
   end loop;

   declare
      Left             : constant Vector := Load_16 (Left_Bytes'Address);
      Right            : constant Vector := Load_16 (Right_Bytes'Address);
      Unaligned        : constant Vector := Load_16 (Unaligned_Bytes (1)'Address);
      Expected_Xor     : Vector;
      Expected_Reverse : Vector;
   begin
      Check (Left = Left_Bytes, "aligned 16-byte load");
      Check (Unaligned = Left_Bytes, "unaligned 16-byte load");

      for Index in Vector'Range loop
         Expected_Xor (Index) := Left (Index) xor Right (Index);
         Expected_Reverse (Index) := Left (Vector'Last - Index);
      end loop;

      Check (Xor_128 (Left, Right) = Expected_Xor, "128-bit XOR");
      Check
        (Reverse_Bytes_128 (Left) = Expected_Reverse,
         "128-bit byte reversal");

      Check_Product
        (Carryless_Multiply_00 (Left, Right),
         Lane (Left, False), Lane (Right, False), "PMULL low/low");
      Check_Product
        (Carryless_Multiply_01 (Left, Right),
         Lane (Left, True), Lane (Right, False), "PMULL selector 01 high/low");
      Check_Product
        (Carryless_Multiply_10 (Left, Right),
         Lane (Left, False), Lane (Right, True), "PMULL selector 10 low/high");
      Check_Product
        (Carryless_Multiply_11 (Left, Right),
         Lane (Left, True), Lane (Right, True), "PMULL high/high");
   end;

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " native primitive tests failed";
   end if;
   Ada.Text_IO.Put_Line ("All AArch64 native primitive tests passed");
end Flyology_CRC.Native.Primitive_Tests;
