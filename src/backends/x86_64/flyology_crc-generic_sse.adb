--  This leaf contains only the x86-64 mechanisms needed to express its
--  SSSE3/SSE4.1/PCLMULQDQ implementation; dispatch and suffix policy remain
--  in Ada callers compiled for baseline x86-64. See THIRD_PARTY_NOTICES.md
--  for the folding and reduction provenance.

with Flyology_CRC.Generic_PMULL_Kernel;
with System.Machine_Code;
with System.Storage_Elements;

package body Flyology_CRC.Generic_SSE is
   use System.Machine_Code;
   use type System.Bit_Order;
   use type System.Storage_Elements.Storage_Offset;

   subtype U64 is Interfaces.Unsigned_64;

   type Vector_128 is array (Natural range 0 .. 1) of U64 with Alignment => 16;
   pragma Machine_Attribute (Vector_128, "vector_type");

   type Byte_Block_16 is array (Natural range 0 .. 15) of Interfaces.Unsigned_8
   with Pack;

   Byte_Reverse_Mask : constant Vector_128 :=
     (16#0809_0A0B_0C0D_0E0F#, 16#0001_0203_0405_0607#);

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the x86-64 generic SSE CRC backend requires little-endian byte order");
   pragma Compile_Time_Error
     (System.Word_Size /= 64,
      "the x86-64 generic SSE CRC backend requires 64-bit words");
   pragma Compile_Time_Error
     (Vector_128'Size /= 128,
      "the x86-64 generic SSE CRC vector must be exactly 128 bits");

   function Compiled return Boolean is (True);

   function Load_16 (Source : System.Address) return Vector_128 is
      Bytes  : Byte_Block_16 with Import, Address => Source;
      Result : Vector_128;
   begin
      Asm
        (Template => "movdqu %1, %0",
         Outputs  => Vector_128'Asm_Output ("=&x", Result),
         Inputs   => Byte_Block_16'Asm_Input ("m", Bytes));
      return Result;
   end Load_16;
   pragma Inline_Always (Load_16);

   procedure Load_16_Pair_Advance
     (Source        : in out System.Address;
      First, Second : out Vector_128) is
      First_Bytes  : Byte_Block_16 with Import, Address => Source;
      Second_Bytes : Byte_Block_16 with Import, Address => Source + 16;
   begin
      Asm
        (Template =>
           "movdqu %3, %1" & ASCII.LF & ASCII.HT &
           "movdqu %4, %2" & ASCII.LF & ASCII.HT &
           "addq $32, %0",
         Outputs  =>
           [System.Address'Asm_Output ("+&r", Source),
            Vector_128'Asm_Output ("=&x", First),
            Vector_128'Asm_Output ("=&x", Second)],
         Inputs   =>
           [Byte_Block_16'Asm_Input ("m", First_Bytes),
            Byte_Block_16'Asm_Input ("m", Second_Bytes)],
         Clobber  => "memory");
   end Load_16_Pair_Advance;
   pragma Inline_Always (Load_16_Pair_Advance);

   procedure Fold_Stripes_8
     (Source      : in out System.Address;
      End_Address : System.Address;
      Reflected   : Boolean;
      Coeff       : Vector_128;
      X0, X1, X2, X3, X4, X5, X6, X7 : in out Vector_128) is
      Reflected_Template : constant String :=
        "1:" & ASCII.LF & ASCII.HT &
        "movdqa %1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %1" & ASCII.LF & ASCII.HT &
        "movdqu 0(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %1" & ASCII.LF & ASCII.HT &
        "movdqa %2, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %2" & ASCII.LF & ASCII.HT &
        "movdqu 16(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %2" & ASCII.LF & ASCII.HT &
        "movdqa %3, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %3" & ASCII.LF & ASCII.HT &
        "movdqu 32(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %3" & ASCII.LF & ASCII.HT &
        "movdqa %4, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %4" & ASCII.LF & ASCII.HT &
        "movdqu 48(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %4" & ASCII.LF & ASCII.HT &
        "movdqa %5, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %5" & ASCII.LF & ASCII.HT &
        "movdqu 64(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %5" & ASCII.LF & ASCII.HT &
        "movdqa %6, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %6" & ASCII.LF & ASCII.HT &
        "movdqu 80(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %6" & ASCII.LF & ASCII.HT &
        "movdqa %7, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %7" & ASCII.LF & ASCII.HT &
        "movdqu 96(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %7" & ASCII.LF & ASCII.HT &
        "movdqa %8, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %8" & ASCII.LF & ASCII.HT &
        "movdqu 112(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %8" & ASCII.LF & ASCII.HT &
        "addq $128, %0" & ASCII.LF & ASCII.HT &
        "cmpq %9, %0" & ASCII.LF & ASCII.HT &
        "jne 1b";
      Forward_Template : constant String :=
        "1:" & ASCII.LF & ASCII.HT &
        "movdqu 0(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %1" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %1" & ASCII.LF & ASCII.HT &
        "movdqu 16(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %2, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %2" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %2" & ASCII.LF & ASCII.HT &
        "movdqu 32(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %3, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %3" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %3" & ASCII.LF & ASCII.HT &
        "movdqu 48(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %4, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %4" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %4" & ASCII.LF & ASCII.HT &
        "movdqu 64(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %5, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %5" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %5" & ASCII.LF & ASCII.HT &
        "movdqu 80(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %6, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %6" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %6" & ASCII.LF & ASCII.HT &
        "movdqu 96(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %7, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %7" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %7" & ASCII.LF & ASCII.HT &
        "movdqu 112(%0), %%xmm1" & ASCII.LF & ASCII.HT &
        "pshufb %11, %%xmm1" & ASCII.LF & ASCII.HT &
        "movdqa %8, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $0, %10, %%xmm0" & ASCII.LF & ASCII.HT &
        "pclmulqdq $17, %10, %8" & ASCII.LF & ASCII.HT &
        "pxor %%xmm1, %%xmm0" & ASCII.LF & ASCII.HT &
        "pxor %%xmm0, %8" & ASCII.LF & ASCII.HT &
        "addq $128, %0" & ASCII.LF & ASCII.HT &
        "cmpq %9, %0" & ASCII.LF & ASCII.HT &
        "jne 1b";
   begin
      if Reflected then
         Asm
           (Template => Reflected_Template,
            Outputs  =>
              [System.Address'Asm_Output ("+&r", Source),
               Vector_128'Asm_Output ("+&x", X0),
               Vector_128'Asm_Output ("+&x", X1),
               Vector_128'Asm_Output ("+&x", X2),
               Vector_128'Asm_Output ("+&x", X3),
               Vector_128'Asm_Output ("+&x", X4),
               Vector_128'Asm_Output ("+&x", X5),
               Vector_128'Asm_Output ("+&x", X6),
               Vector_128'Asm_Output ("+&x", X7)],
            Inputs   =>
              [System.Address'Asm_Input ("r", End_Address),
               Vector_128'Asm_Input ("x", Coeff),
               Vector_128'Asm_Input ("x", Byte_Reverse_Mask)],
            Clobber  => "cc,memory,xmm0,xmm1",
            Volatile => True);
      else
         Asm
           (Template => Forward_Template,
            Outputs  =>
              [System.Address'Asm_Output ("+&r", Source),
               Vector_128'Asm_Output ("+&x", X0),
               Vector_128'Asm_Output ("+&x", X1),
               Vector_128'Asm_Output ("+&x", X2),
               Vector_128'Asm_Output ("+&x", X3),
               Vector_128'Asm_Output ("+&x", X4),
               Vector_128'Asm_Output ("+&x", X5),
               Vector_128'Asm_Output ("+&x", X6),
               Vector_128'Asm_Output ("+&x", X7)],
            Inputs   =>
              [System.Address'Asm_Input ("r", End_Address),
               Vector_128'Asm_Input ("x", Coeff),
               Vector_128'Asm_Input ("x", Byte_Reverse_Mask)],
            Clobber  => "cc,memory,xmm0,xmm1",
            Volatile => True);
      end if;
   end Fold_Stripes_8;
   pragma Inline_Always (Fold_Stripes_8);

   function Xor_128 (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128 := Left;
   begin
      Asm
        (Template => "pxor %1, %0",
         Outputs  => Vector_128'Asm_Output ("+x", Result),
         Inputs   => Vector_128'Asm_Input ("x", Right));
      return Result;
   end Xor_128;
   pragma Inline_Always (Xor_128);

   function Xor_3
     (First, Second, Third : Vector_128) return Vector_128 is
      Result : Vector_128 := First;
   begin
      Asm
        (Template =>
           "pxor %1, %0" & ASCII.LF & ASCII.HT &
           "pxor %2, %0",
         Outputs  => Vector_128'Asm_Output ("+x", Result),
         Inputs   =>
           [Vector_128'Asm_Input ("x", Second),
            Vector_128'Asm_Input ("xm", Third)]);
      return Result;
   end Xor_3;
   pragma Inline_Always (Xor_3);

   function Reverse_Bytes_128 (Value : Vector_128) return Vector_128 is
      Result : Vector_128 := Value;
   begin
      Asm
        (Template => "pshufb %1, %0",
         Outputs  => Vector_128'Asm_Output ("+x", Result),
         Inputs   => Vector_128'Asm_Input ("xm", Byte_Reverse_Mask));
      return Result;
   end Reverse_Bytes_128;
   pragma Inline_Always (Reverse_Bytes_128);

   function Shift_Left
     (Value : Vector_128; Bytes : Natural) return Vector_128 is
      Result : Vector_128 := Value;
   begin
      case Bytes is
         when 4 =>
            Asm
              (Template => "pslldq $4, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when 8 =>
            Asm
              (Template => "pslldq $8, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when 12 =>
            Asm
              (Template => "pslldq $12, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when others =>
            raise Program_Error with "unsupported x86 SSE byte shift";
      end case;
      return Result;
   end Shift_Left;
   pragma Inline_Always (Shift_Left);

   function Shift_Right
     (Value : Vector_128; Bytes : Natural) return Vector_128 is
      Result : Vector_128 := Value;
   begin
      case Bytes is
         when 4 =>
            Asm
              (Template => "psrldq $4, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when 8 =>
            Asm
              (Template => "psrldq $8, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when 12 =>
            Asm
              (Template => "psrldq $12, %0",
               Outputs  => Vector_128'Asm_Output ("+x", Result),
               Volatile => True);
         when others =>
            raise Program_Error with "unsupported x86 SSE byte shift";
      end case;
      return Result;
   end Shift_Right;
   pragma Inline_Always (Shift_Right);

   function And_128 (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128 := Left;
   begin
      Asm
        (Template => "pand %1, %0",
         Outputs  => Vector_128'Asm_Output ("+x", Result),
         Inputs   => Vector_128'Asm_Input ("xm", Right));
      return Result;
   end And_128;
   pragma Inline_Always (And_128);

   function Pair (High, Low : U64) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template =>
           "movq %1, %0" & ASCII.LF & ASCII.HT &
           "pinsrq $1, %2, %0",
         Outputs  => Vector_128'Asm_Output ("=&x", Result),
         Inputs   =>
           [U64'Asm_Input ("r", Low),
            U64'Asm_Input ("r", High)]);
      return Result;
   end Pair;
   pragma Inline_Always (Pair);

   function Lane
     (Item : Vector_128; High : Boolean) return U64 is
      Result : U64;
   begin
      if High then
         Asm
           (Template => "pextrq $1, %1, %0",
            Outputs  => U64'Asm_Output ("=r", Result),
            Inputs   => Vector_128'Asm_Input ("x", Item));
      else
         Asm
           (Template => "movq %1, %0",
            Outputs  => U64'Asm_Output ("=r", Result),
            Inputs   => Vector_128'Asm_Input ("x", Item));
      end if;
      return Result;
   end Lane;
   pragma Inline_Always (Lane);

   function Carryless_Multiply
     (Left, Right : Vector_128;
      Selector    : Natural) return Vector_128 is
      Result : Vector_128 := Left;
   begin
      case Selector is
         when 0 =>
            Asm
              ("pclmulqdq $0, %1, %0",
               Vector_128'Asm_Output ("+x", Result),
               Vector_128'Asm_Input ("x", Right));
         when 1 =>
            Asm
              ("pclmulqdq $1, %1, %0",
               Vector_128'Asm_Output ("+x", Result),
               Vector_128'Asm_Input ("x", Right));
         when 16 =>
            Asm
              ("pclmulqdq $16, %1, %0",
               Vector_128'Asm_Output ("+x", Result),
               Vector_128'Asm_Input ("x", Right));
         when 17 =>
            Asm
              ("pclmulqdq $17, %1, %0",
               Vector_128'Asm_Output ("+x", Result),
               Vector_128'Asm_Input ("x", Right));
         when others =>
            raise Program_Error with "invalid PCLMULQDQ selector";
      end case;
      return Result;
   end Carryless_Multiply;
   pragma Inline_Always (Carryless_Multiply);

   function Carryless_Multiply_00
     (Left, Right : Vector_128) return Vector_128 is
     (Carryless_Multiply (Left, Right, 0));
   pragma Inline_Always (Carryless_Multiply_00);

   function Carryless_Multiply_01
     (Left, Right : Vector_128) return Vector_128 is
     (Carryless_Multiply (Left, Right, 1));
   pragma Inline_Always (Carryless_Multiply_01);

   function Carryless_Multiply_10
     (Left, Right : Vector_128) return Vector_128 is
     (Carryless_Multiply (Left, Right, 16));
   pragma Inline_Always (Carryless_Multiply_10);

   function Carryless_Multiply_11
     (Left, Right : Vector_128) return Vector_128 is
     (Carryless_Multiply (Left, Right, 17));
   pragma Inline_Always (Carryless_Multiply_11);

   package SSE_16 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_16,
        Width                 => 16,
        Vector_Type           => Vector_128,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Stripes_8,
        Use_Custom_Stripe_Loop => True,
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

   package SSE_32 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_32,
        Width                 => 32,
        Vector_Type           => Vector_128,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Stripes_8,
        Use_Custom_Stripe_Loop => True,
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

   package SSE_64 is new
     Generic_PMULL_Kernel.Engine
       (Value                 => Interfaces.Unsigned_64,
        Width                 => 64,
        Vector_Type           => Vector_128,
        Load_16               => Load_16,
        Load_16_Pair_Advance  => Load_16_Pair_Advance,
        Fold_Stripes_8        => Fold_Stripes_8,
        Use_Custom_Stripe_Loop => True,
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

   function Update_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16 is
   begin
      return SSE_16.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_16;

   function Update_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return SSE_32.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_32;

   function Update_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64 is
   begin
      return SSE_64.Update_Aligned_Blocks (State, Reflected, Keys, Data);
   end Update_64;
end Flyology_CRC.Generic_SSE;
