--  AArch64 EOR3 specialization of the generic folding and reduction kernel.
--  See THIRD_PARTY_NOTICES.md for implementation provenance.

with Flyology_CRC.Generic_PMULL_Kernel;
with System.Machine_Code;

package body Flyology_CRC.Native_EOR3 is
   use System.Machine_Code;
   use type System.Bit_Order;

   --  Keep the vector primitives in this selected unit so GNAT can inline the
   --  complete stripe loop under +sha3.  Calling the baseline Native helpers
   --  across a unit boundary would put helper calls back in the hot loop.

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the AArch64 CRC EOR3 backend requires little-endian byte order");

   type Machine_Vector is array (0 .. 15) of Interfaces.Unsigned_8;
   for Machine_Vector'Alignment use 16;
   pragma Machine_Attribute (Machine_Vector, "vector_type");

   pragma Compile_Time_Error
     (Machine_Vector'Size /= 128,
      "the CRC EOR3 native vector must be exactly 128 bits");

   type Byte_Block is array (0 .. 15) of Interfaces.Unsigned_8;
   type Byte_Block_32 is array (0 .. 31) of Interfaces.Unsigned_8;
   type Byte_Block_128 is array (0 .. 127) of Interfaces.Unsigned_8;

   function Compiled return Boolean is (True);

   function Load_16 (Source : System.Address) return Machine_Vector is
      Bytes  : constant Byte_Block with Import, Address => Source;
      Result : Machine_Vector;
   begin
      Asm
        (Template => "ldr %q0, %1",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   => Byte_Block'Asm_Input ("Q", Bytes));
      return Result;
   end Load_16;

   procedure Load_16_Pair_Advance
     (Source        : in out System.Address;
      First, Second : out Machine_Vector) is
      Bytes : constant Byte_Block_32 with Import, Address => Source;
   begin
      Asm
        (Template => "ldp %q1, %q2, [%0], #32",
         Outputs  =>
           [System.Address'Asm_Output ("+r", Source),
            Machine_Vector'Asm_Output ("=&w", First),
            Machine_Vector'Asm_Output ("=&w", Second)],
         Inputs   => Byte_Block_32'Asm_Input ("Q", Bytes));
   end Load_16_Pair_Advance;
   pragma Inline_Always (Load_16_Pair_Advance);

   procedure Load_Initial_Stripe_8
     (Source : System.Address;
      X0, X1, X2, X3, X4, X5, X6, X7 : out Machine_Vector) is
      Bytes : constant Byte_Block_128 with Import, Address => Source;
   begin
      Asm
        (Template =>
           "ldp %q0, %q1, [%8]" & ASCII.LF & ASCII.HT &
           "ldp %q2, %q3, [%8, #32]" & ASCII.LF & ASCII.HT &
           "ldp %q4, %q5, [%8, #64]" & ASCII.LF & ASCII.HT &
           "ldp %q6, %q7, [%8, #96]",
         Outputs  =>
           [Machine_Vector'Asm_Output ("=&w", X0),
            Machine_Vector'Asm_Output ("=&w", X1),
            Machine_Vector'Asm_Output ("=&w", X2),
            Machine_Vector'Asm_Output ("=&w", X3),
            Machine_Vector'Asm_Output ("=&w", X4),
            Machine_Vector'Asm_Output ("=&w", X5),
            Machine_Vector'Asm_Output ("=&w", X6),
            Machine_Vector'Asm_Output ("=&w", X7)],
         Inputs   =>
           [System.Address'Asm_Input ("r", Source),
            Byte_Block_128'Asm_Input ("Q", Bytes)]);
   end Load_Initial_Stripe_8;
   pragma Inline_Always (Load_Initial_Stripe_8);

   procedure Fold_Forward_Stripes_8
     (Source      : in out System.Address;
      End_Address : System.Address;
      Reflected   : Boolean;
      Coeff       : Machine_Vector;
      X0, X1, X2, X3, X4, X5, X6, X7 : in out Machine_Vector) is
      pragma Unreferenced (Reflected);
      P0, P1                  : Machine_Vector;
      First_Data, Second_Data : Machine_Vector;
      Forward_Reverse_Mask : constant Machine_Vector :=
        (15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
   begin
      --  The generic engine calls this hook only for forward input and with
      --  complete 128-byte stripes.  TBL performs each byte reversal in one
      --  instruction while EOR3 retains the selected SHA3 tier's three-input
      --  fold; reflected input stays on the unchanged generated loop.
      Asm
        (Template =>
           "1:" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %1.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "ldp %q11, %q12, [%x0]" & ASCII.LF & ASCII.HT &
           "tbl %11.16b, {%11.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %1.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %1.16b, %9.16b, %10.16b, %11.16b" & ASCII.LF & ASCII.HT &
           "tbl %12.16b, {%12.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %2.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %2.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %2.16b, %9.16b, %10.16b, %12.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %3.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "ldp %q11, %q12, [%x0, #32]" & ASCII.LF & ASCII.HT &
           "tbl %11.16b, {%11.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %3.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %3.16b, %9.16b, %10.16b, %11.16b" & ASCII.LF & ASCII.HT &
           "tbl %12.16b, {%12.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %4.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %4.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %4.16b, %9.16b, %10.16b, %12.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %5.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "ldp %q11, %q12, [%x0, #64]" & ASCII.LF & ASCII.HT &
           "tbl %11.16b, {%11.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %5.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %5.16b, %9.16b, %10.16b, %11.16b" & ASCII.LF & ASCII.HT &
           "tbl %12.16b, {%12.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %6.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %6.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %6.16b, %9.16b, %10.16b, %12.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %7.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "ldp %q11, %q12, [%x0, #96]" & ASCII.LF & ASCII.HT &
           "tbl %11.16b, {%11.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %7.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %7.16b, %9.16b, %10.16b, %11.16b" & ASCII.LF & ASCII.HT &
           "tbl %12.16b, {%12.16b}, %15.16b" & ASCII.LF & ASCII.HT &
           "pmull %9.1q, %8.1d, %14.1d" & ASCII.LF & ASCII.HT &
           "pmull2 %10.1q, %8.2d, %14.2d" & ASCII.LF & ASCII.HT &
           "eor3 %8.16b, %9.16b, %10.16b, %12.16b" & ASCII.LF & ASCII.HT &
           "add %x0, %x0, #128" & ASCII.LF & ASCII.HT &
           "cmp %x0, %x13" & ASCII.LF & ASCII.HT &
           "b.ne 1b",
         Outputs =>
           [System.Address'Asm_Output ("+&r", Source),
            Machine_Vector'Asm_Output ("+&w", X0),
            Machine_Vector'Asm_Output ("+&w", X1),
            Machine_Vector'Asm_Output ("+&w", X2),
            Machine_Vector'Asm_Output ("+&w", X3),
            Machine_Vector'Asm_Output ("+&w", X4),
            Machine_Vector'Asm_Output ("+&w", X5),
            Machine_Vector'Asm_Output ("+&w", X6),
            Machine_Vector'Asm_Output ("+&w", X7),
            Machine_Vector'Asm_Output ("=&w", P0),
            Machine_Vector'Asm_Output ("=&w", P1),
            Machine_Vector'Asm_Output ("=&w", First_Data),
            Machine_Vector'Asm_Output ("=&w", Second_Data)],
         Inputs =>
           [System.Address'Asm_Input ("r", End_Address),
            Machine_Vector'Asm_Input ("w", Coeff),
            Machine_Vector'Asm_Input ("w", Forward_Reverse_Mask)],
         Clobber  => "cc,memory",
         Volatile => True);
   end Fold_Forward_Stripes_8;
   pragma Inline_Always (Fold_Forward_Stripes_8);

   function Xor_128 (Left, Right : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template => "eor %0.16b, %1.16b, %2.16b",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end Xor_128;

   function Xor_3
     (First, Second, Third : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template => "eor3 %0.16b, %1.16b, %2.16b, %3.16b",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   =>
           [Machine_Vector'Asm_Input ("w", First),
            Machine_Vector'Asm_Input ("w", Second),
            Machine_Vector'Asm_Input ("w", Third)]);
      return Result;
   end Xor_3;
   pragma Inline_Always (Xor_3);

   function Reverse_Bytes_128 (Value : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template =>
           "rev64 %0.16b, %1.16b" & ASCII.LF & ASCII.HT &
           "ext %0.16b, %0.16b, %0.16b, #8",
         Outputs => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs  => Machine_Vector'Asm_Input ("w", Value));
      return Result;
   end Reverse_Bytes_128;

   function Carryless_Multiply_00
     (Left, Right : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template => "pmull %0.1q, %1.1d, %2.1d",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end Carryless_Multiply_00;

   function Carryless_Multiply_01
     (Left, Right : Machine_Vector) return Machine_Vector is
      Result    : Machine_Vector;
      Left_High : Machine_Vector;
   begin
      Asm
        (Template =>
           "ext %1.16b, %2.16b, %2.16b, #8" & ASCII.LF & ASCII.HT &
           "pmull %0.1q, %1.1d, %3.1d",
         Outputs =>
           [Machine_Vector'Asm_Output ("=&w", Result),
            Machine_Vector'Asm_Output ("=&w", Left_High)],
         Inputs  =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end Carryless_Multiply_01;

   function Carryless_Multiply_10
     (Left, Right : Machine_Vector) return Machine_Vector is
      Result     : Machine_Vector;
      Right_High : Machine_Vector;
   begin
      Asm
        (Template =>
           "ext %1.16b, %3.16b, %3.16b, #8" & ASCII.LF & ASCII.HT &
           "pmull %0.1q, %2.1d, %1.1d",
         Outputs =>
           [Machine_Vector'Asm_Output ("=&w", Result),
            Machine_Vector'Asm_Output ("=&w", Right_High)],
         Inputs  =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end Carryless_Multiply_10;

   function Carryless_Multiply_11
     (Left, Right : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template => "pmull2 %0.1q, %1.2d, %2.2d",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end Carryless_Multiply_11;

   function Shift_Left
     (Value : Machine_Vector; Bytes : Natural) return Machine_Vector is
      Result : Machine_Vector;
      Zero   : Machine_Vector;
   begin
      case Bytes is
         when 4 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %1.16b, %2.16b, #12",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when 8 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %1.16b, %2.16b, #8",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when 12 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %1.16b, %2.16b, #4",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when others =>
            Result := (others => 0);
            for Index in Value'Range loop
               if Index >= Bytes then
                  Result (Index) := Value (Index - Bytes);
               end if;
            end loop;
      end case;
      return Result;
   end Shift_Left;

   function Shift_Right
     (Value : Machine_Vector; Bytes : Natural) return Machine_Vector is
      Result : Machine_Vector;
      Zero   : Machine_Vector;
   begin
      case Bytes is
         when 4 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %2.16b, %1.16b, #4",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when 8 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %2.16b, %1.16b, #8",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when 12 =>
            Asm
              (Template =>
                 "movi %1.4s, #0" & ASCII.LF & ASCII.HT &
                 "ext %0.16b, %2.16b, %1.16b, #12",
               Outputs =>
                 [Machine_Vector'Asm_Output ("=&w", Result),
                  Machine_Vector'Asm_Output ("=&w", Zero)],
               Inputs => Machine_Vector'Asm_Input ("w", Value));
         when others =>
            Result := (others => 0);
            for Index in Value'Range loop
               if Index + Bytes <= Value'Last then
                  Result (Index) := Value (Index + Bytes);
               end if;
            end loop;
      end case;
      return Result;
   end Shift_Right;

   function And_128
     (Left, Right : Machine_Vector) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template => "and %0.16b, %1.16b, %2.16b",
         Outputs  => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs   =>
           [Machine_Vector'Asm_Input ("w", Left),
            Machine_Vector'Asm_Input ("w", Right)]);
      return Result;
   end And_128;

   function Pair
     (High, Low : Interfaces.Unsigned_64) return Machine_Vector is
      Result : Machine_Vector;
   begin
      Asm
        (Template =>
           "ins %0.d[0], %x1" & ASCII.LF & ASCII.HT &
           "ins %0.d[1], %x2",
         Outputs => Machine_Vector'Asm_Output ("=&w", Result),
         Inputs  =>
           [Interfaces.Unsigned_64'Asm_Input ("r", Low),
            Interfaces.Unsigned_64'Asm_Input ("r", High)]);
      return Result;
   end Pair;
   pragma Inline_Always (Pair);

   function Lane
     (Item : Machine_Vector; High : Boolean) return Interfaces.Unsigned_64 is
      Result : Interfaces.Unsigned_64;
   begin
      if High then
         Asm
           (Template => "umov %x0, %1.d[1]",
            Outputs  => Interfaces.Unsigned_64'Asm_Output ("=r", Result),
            Inputs   => Machine_Vector'Asm_Input ("w", Item));
      else
         Asm
           (Template => "umov %x0, %1.d[0]",
            Outputs  => Interfaces.Unsigned_64'Asm_Output ("=r", Result),
            Inputs   => Machine_Vector'Asm_Input ("w", Item));
      end if;
      return Result;
   end Lane;
   pragma Inline_Always (Lane);

   package PMULL_16 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_16,
        Width                 => 16,
        Vector_Type           => Machine_Vector,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Forward_Stripes_8,
        Use_Custom_Stripe_Loop => False,
        Use_Custom_Forward_Stripe_Loop => True,
        Xor_128               => Xor_128,
        Xor_3                 => Xor_3,
        Reverse_Bytes_128     => Reverse_Bytes_128,
        Shift_Left            => Shift_Left,
        Shift_Right           => Shift_Right,
        And_128               => And_128,
        Pair                  => Pair,
        Lane                  => Lane,
        Carryless_Multiply_00 => Carryless_Multiply_00,
        Carryless_Multiply_01 => Carryless_Multiply_01,
        Carryless_Multiply_10 => Carryless_Multiply_10,
        Carryless_Multiply_11 => Carryless_Multiply_11);

   package PMULL_32 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_32,
        Width                 => 32,
        Vector_Type           => Machine_Vector,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Forward_Stripes_8,
        Use_Custom_Stripe_Loop => False,
        Use_Custom_Forward_Stripe_Loop => True,
        Use_Custom_Initial_Load => True,
        Load_Initial_Stripe_8 => Load_Initial_Stripe_8,
        Xor_128               => Xor_128,
        Xor_3                 => Xor_3,
        Reverse_Bytes_128     => Reverse_Bytes_128,
        Shift_Left            => Shift_Left,
        Shift_Right           => Shift_Right,
        And_128               => And_128,
        Pair                  => Pair,
        Lane                  => Lane,
        Carryless_Multiply_00 => Carryless_Multiply_00,
        Carryless_Multiply_01 => Carryless_Multiply_01,
        Carryless_Multiply_10 => Carryless_Multiply_10,
        Carryless_Multiply_11 => Carryless_Multiply_11);

   package PMULL_64 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_64,
        Width                 => 64,
        Vector_Type           => Machine_Vector,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Forward_Stripes_8,
        Use_Custom_Stripe_Loop => False,
        Use_Custom_Forward_Stripe_Loop => True,
        Xor_128               => Xor_128,
        Xor_3                 => Xor_3,
        Reverse_Bytes_128     => Reverse_Bytes_128,
        Shift_Left            => Shift_Left,
        Shift_Right           => Shift_Right,
        And_128               => And_128,
        Pair                  => Pair,
        Lane                  => Lane,
        Carryless_Multiply_00 => Carryless_Multiply_00,
        Carryless_Multiply_01 => Carryless_Multiply_01,
        Carryless_Multiply_10 => Carryless_Multiply_10,
        Carryless_Multiply_11 => Carryless_Multiply_11);

   function Update_PMULL_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
   begin
      return PMULL_16.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_PMULL_16;

   function Update_PMULL_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return PMULL_32.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_PMULL_32;

   function Update_PMULL_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
   begin
      return PMULL_64.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_PMULL_64;
end Flyology_CRC.Native_EOR3;
