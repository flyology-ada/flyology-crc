--  The 4-ZMM folding geometry and generated-key indices are arithmetic
--  contract, not implementation policy. See THIRD_PARTY_NOTICES.md for the
--  folding and lane-collapse provenance.

with System.Machine_Code;

package body Flyology_CRC.Generic_AVX512_VPCLMUL is
   use System.Machine_Code;
   use type Interfaces.Unsigned_64;
   use type System.Bit_Order;

   subtype U64 is Interfaces.Unsigned_64;

   type Vector_128 is array (Natural range 0 .. 1) of U64 with Alignment => 16;
   pragma Machine_Attribute (Vector_128, "vector_type");

   type Vector_512 is array (Natural range 0 .. 7) of U64 with Alignment => 64;
   pragma Machine_Attribute (Vector_512, "vector_type");

   --  Pinned-oracle constants for reversing all 64 bytes in a ZMM register:
   --  VPSHUFB reverses within 128-bit lanes, then VPERMUTEXVARQ reverses the
   --  eight 64-bit lanes.
   Byte_Reverse_Mask : aliased constant Vector_512 :=
     (16#0001_0203_0405_0607#, 16#0809_0A0B_0C0D_0E0F#,
      16#0001_0203_0405_0607#, 16#0809_0A0B_0C0D_0E0F#,
      16#0001_0203_0405_0607#, 16#0809_0A0B_0C0D_0E0F#,
      16#0001_0203_0405_0607#, 16#0809_0A0B_0C0D_0E0F#);
   Reverse_Lane_Indices : aliased constant Vector_512 := (7, 6, 5, 4, 3, 2, 1, 0);

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the generic x86-64 AVX-512 VPCLMUL kernel requires little-endian byte order");
   pragma Compile_Time_Error
     (System.Word_Size /= 64,
      "the generic x86-64 AVX-512 VPCLMUL kernel requires 64-bit words");

   function Xor_128 (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128 := Left;
   begin
      Asm
        ("pxor %1, %0",
         Vector_128'Asm_Output ("+x", Result),
         Vector_128'Asm_Input ("x", Right));
      return Result;
   end Xor_128;
   pragma Inline_Always (Xor_128);

   function Shift_Left (Value : Vector_128; Bytes : Natural) return Vector_128 is
      Result : Vector_128 := Value;
   begin
      case Bytes is
         when 4 =>
            Asm ("pslldq $4, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when 8 =>
            Asm ("pslldq $8, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when 12 =>
            Asm ("pslldq $12, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when others => raise Program_Error with "unsupported x86 byte shift";
      end case;
      return Result;
   end Shift_Left;
   pragma Inline_Always (Shift_Left);

   function Shift_Right (Value : Vector_128; Bytes : Natural) return Vector_128 is
      Result : Vector_128 := Value;
   begin
      case Bytes is
         when 4 =>
            Asm ("psrldq $4, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when 8 =>
            Asm ("psrldq $8, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when 12 =>
            Asm ("psrldq $12, %0", Vector_128'Asm_Output ("+x", Result), Volatile => True);
         when others => raise Program_Error with "unsupported x86 byte shift";
      end case;
      return Result;
   end Shift_Right;
   pragma Inline_Always (Shift_Right);

   function And_128 (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128 := Left;
   begin
      Asm
        ("pand %1, %0",
         Vector_128'Asm_Output ("+x", Result),
         Vector_128'Asm_Input ("xm", Right));
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
         Outputs => Vector_128'Asm_Output ("=&x", Result),
         Inputs  => [U64'Asm_Input ("r", Low), U64'Asm_Input ("r", High)]);
      return Result;
   end Pair;
   pragma Inline_Always (Pair);

   function Lane (Item : Vector_128; High : Boolean) return U64 is
      Result : U64;
   begin
      if High then
         Asm
           ("pextrq $1, %1, %0",
            U64'Asm_Output ("=r", Result), Vector_128'Asm_Input ("x", Item));
      else
         Asm
           ("movq %1, %0",
            U64'Asm_Output ("=r", Result), Vector_128'Asm_Input ("x", Item));
      end if;
      return Result;
   end Lane;
   pragma Inline_Always (Lane);

   function CLMUL
     (Left, Right : Vector_128; Selector : Natural) return Vector_128 is
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
         when others => raise Program_Error with "invalid PCLMULQDQ selector";
      end case;
      return Result;
   end CLMUL;
   pragma Inline_Always (CLMUL);

   Reflected_Initial : constant String :=
     "vmovdqu64 0(%0), %%zmm0" & ASCII.LF & ASCII.HT &
     "vmovdqu64 64(%0), %%zmm1" & ASCII.LF & ASCII.HT &
     "vmovdqu64 128(%0), %%zmm2" & ASCII.LF & ASCII.HT &
     "vmovdqu64 192(%0), %%zmm3" & ASCII.LF & ASCII.HT &
     "vpxorq 0(%5), %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vmovdqu 168(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $1, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $2, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $3, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $0x55, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "addq $256, %0" & ASCII.LF & ASCII.HT;

   Forward_Initial : constant String :=
     "vmovdqu64 0(%0), %%zmm0" & ASCII.LF & ASCII.HT &
     "vmovdqu64 64(%0), %%zmm1" & ASCII.LF & ASCII.HT &
     "vmovdqu64 128(%0), %%zmm2" & ASCII.LF & ASCII.HT &
     "vmovdqu64 192(%0), %%zmm3" & ASCII.LF & ASCII.HT &
     "vmovdqu64 0(%6), %%zmm10" & ASCII.LF & ASCII.HT &
     "vmovdqu64 0(%7), %%zmm11" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm0, %%zmm11, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm1, %%zmm11, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm2, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm2, %%zmm11, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm3, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm3, %%zmm11, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpxorq 0(%5), %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vmovdqu 168(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $1, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $2, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $3, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "addq $256, %0" & ASCII.LF & ASCII.HT;

   Reflected_Pair_Loop : constant String :=
     "testq %2, %2" & ASCII.LF & ASCII.HT &
     "jz 2f" & ASCII.LF & ASCII.HT &
     "1:" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 0(%0), %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 64(%0), %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm2, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm2, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 128(%0), %%zmm12, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm3, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm3, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 192(%0), %%zmm12, %%zmm3" & ASCII.LF & ASCII.HT &
     "addq $256, %0" & ASCII.LF & ASCII.HT &
     "decq %2" & ASCII.LF & ASCII.HT &
     "jnz 1b" & ASCII.LF & ASCII.HT &
     "2:" & ASCII.LF & ASCII.HT;

   Forward_Pair_Loop : constant String :=
     "testq %2, %2" & ASCII.LF & ASCII.HT &
     "jz 2f" & ASCII.LF & ASCII.HT &
     "1:" & ASCII.LF & ASCII.HT &
     "vmovdqu64 0(%0), %%zmm4" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm4, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm4, %%zmm11, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm4, %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vmovdqu64 64(%0), %%zmm4" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm4, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm4, %%zmm11, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm4, %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "vmovdqu64 128(%0), %%zmm4" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm4, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm4, %%zmm11, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm2, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm2, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm4, %%zmm12, %%zmm2" & ASCII.LF & ASCII.HT &
     "vmovdqu64 192(%0), %%zmm4" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm4, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm4, %%zmm11, %%zmm4" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm3, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm3, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm4, %%zmm12, %%zmm3" & ASCII.LF & ASCII.HT &
     "addq $256, %0" & ASCII.LF & ASCII.HT &
     "decq %2" & ASCII.LF & ASCII.HT &
     "jnz 1b" & ASCII.LF & ASCII.HT &
     "2:" & ASCII.LF & ASCII.HT;

   Reflected_Collapse : constant String :=
     "vmovdqu 24(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $1, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $2, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $3, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $0x55, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm2, %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm3, %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "testq %3, %3" & ASCII.LF & ASCII.HT &
     "jz 3f" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 0(%0), %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, 64(%0), %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "3:" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm1, %%xmm4" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $1, %%zmm1, %%xmm5" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $2, %%zmm1, %%xmm6" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $3, %%zmm1, %%xmm7" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $1, %%zmm0, %%xmm1" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $2, %%zmm0, %%xmm2" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $3, %%zmm0, %%xmm3" & ASCII.LF & ASCII.HT;

   Forward_Collapse : constant String :=
     "vmovdqu 24(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $1, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $2, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vinserti32x4 $3, %%xmm8, %%zmm8, %%zmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm2, %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm3, %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "testq %3, %3" & ASCII.LF & ASCII.HT &
     "jz 3f" & ASCII.LF & ASCII.HT &
     "vmovdqu64 0(%0), %%zmm2" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm2, %%zmm2" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm2, %%zmm11, %%zmm2" & ASCII.LF & ASCII.HT &
     "vmovdqu64 64(%0), %%zmm3" & ASCII.LF & ASCII.HT &
     "vpshufb %%zmm10, %%zmm3, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpermq %%zmm3, %%zmm11, %%zmm3" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm0, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm0, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm2, %%zmm12, %%zmm0" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%zmm8, %%zmm1, %%zmm12" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%zmm8, %%zmm1, %%zmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%zmm3, %%zmm12, %%zmm1" & ASCII.LF & ASCII.HT &
     "3:" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm1, %%xmm7" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $1, %%zmm1, %%xmm6" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $2, %%zmm1, %%xmm5" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $3, %%zmm1, %%xmm4" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm0, %%xmm3" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $1, %%zmm0, %%xmm2" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $2, %%zmm0, %%xmm1" & ASCII.LF & ASCII.HT &
     "vextracti32x4 $3, %%zmm0, %%xmm0" & ASCII.LF & ASCII.HT;

   Reflected_Lane_Folds : constant String :=
     "vmovdqu 72(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm0, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm0, %%xmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm0" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm0, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 88(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm1, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm1, %%xmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm1" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm1, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 104(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm2, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm2, %%xmm2" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm2" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm2, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 120(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm3, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm3, %%xmm3" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm3" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm3, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 136(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm4, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm4, %%xmm4" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm4" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm4, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 152(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm5, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm5, %%xmm5" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm5" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm5, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 8(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpermilpd $1, %%xmm8, %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm6, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm6, %%xmm6" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm6" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm6, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm7, %1" & ASCII.LF & ASCII.HT & "vzeroupper";

   Forward_Lane_Folds : constant String :=
     "vmovdqu 72(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm0, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm0, %%xmm0" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm0" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm0, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 88(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm1, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm1, %%xmm1" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm1" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm1, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 104(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm2, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm2, %%xmm2" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm2" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm2, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 120(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm3, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm3, %%xmm3" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm3" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm3, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 136(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm4, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm4, %%xmm4" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm4" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm4, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 152(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm5, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm5, %%xmm5" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm5" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm5, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqu 8(%4), %%xmm8" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $0, %%xmm8, %%xmm6, %%xmm9" & ASCII.LF & ASCII.HT &
     "vpclmulqdq $17, %%xmm8, %%xmm6, %%xmm6" & ASCII.LF & ASCII.HT &
     "vpternlogq $0x96, %%xmm7, %%xmm9, %%xmm6" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm6, %%xmm7" & ASCII.LF & ASCII.HT &
     "vmovdqa %%xmm7, %1" & ASCII.LF & ASCII.HT & "vzeroupper";

   function Fold_To_128
     (Positioned : aliased Vector_512;
      Reflected : Boolean;
      Keys : Folding_Keys;
      Data : Byte_Array) return Vector_128 is
      Pointer : System.Address := Data (Data'First)'Address;
      Block_Count : constant Natural := Data'Length / 128;
      Pair_Count : U64 := U64 ((Block_Count - 2) / 2);
      Odd : constant U64 := U64 ((Block_Count - 2) mod 2);
      Result : Vector_128;
   begin
      if Reflected then
         Asm
           (Template =>
              Reflected_Initial & Reflected_Pair_Loop & Reflected_Collapse & Reflected_Lane_Folds,
            Outputs =>
              [System.Address'Asm_Output ("+&r", Pointer),
               Vector_128'Asm_Output ("=&x", Result),
               U64'Asm_Output ("+&r", Pair_Count)],
            Inputs =>
              [U64'Asm_Input ("r", Odd),
               System.Address'Asm_Input ("r", Keys'Address),
               System.Address'Asm_Input ("r", Positioned'Address),
               System.Address'Asm_Input ("r", Byte_Reverse_Mask'Address),
               System.Address'Asm_Input ("r", Reverse_Lane_Indices'Address)],
            Clobber =>
              "cc,memory,zmm0,zmm1,zmm2,zmm3,zmm4,zmm5,zmm6,zmm7,zmm8,zmm9,zmm10,zmm11,zmm12",
            Volatile => True);
      else
         Asm
           (Template => Forward_Initial & Forward_Pair_Loop & Forward_Collapse & Forward_Lane_Folds,
            Outputs =>
              [System.Address'Asm_Output ("+&r", Pointer),
               Vector_128'Asm_Output ("=&x", Result),
               U64'Asm_Output ("+&r", Pair_Count)],
            Inputs =>
              [U64'Asm_Input ("r", Odd),
               System.Address'Asm_Input ("r", Keys'Address),
               System.Address'Asm_Input ("r", Positioned'Address),
               System.Address'Asm_Input ("r", Byte_Reverse_Mask'Address),
               System.Address'Asm_Input ("r", Reverse_Lane_Indices'Address)],
            Clobber =>
              "cc,memory,zmm0,zmm1,zmm2,zmm3,zmm4,zmm5,zmm6,zmm7,zmm8,zmm9,zmm10,zmm11,zmm12",
            Volatile => True);
      end if;
      return Result;
   end Fold_To_128;
   pragma Inline_Always (Fold_To_128);

   generic
      type Value is mod <>;
      Width : Positive;
   package Engine is
      function Update
        (State : Value; Reflected : Boolean; Keys : Folding_Keys; Data : Byte_Array) return Value;
   end Engine;

   package body Engine is
      function Coefficient (High, Low : U64; Reflected : Boolean) return Vector_128 is
        (if Reflected then Pair (High => Low, Low => High) else Pair (High => High, Low => Low));

      function Fold_Width_32
        (State : Vector_128; High, Low : U64; Reflected : Boolean) return Vector_128 is
         Low_Coefficient  : constant Vector_128 := Pair (High => 0, Low => Low);
         High_Coefficient : constant Vector_128 := Pair (High => High, Low => 0);
         First_Fold, Masked, Product : Vector_128;
      begin
         if Reflected then
            First_Fold := Xor_128 (CLMUL (State, Low_Coefficient, 0), Shift_Right (State, 8));
            Masked := And_128 (First_Fold, Pair (U64'Last, 16#FFFF_FFFF_0000_0000#));
            Product := CLMUL (Shift_Left (First_Fold, 12), High_Coefficient, 17);
         else
            First_Fold := Xor_128 (CLMUL (State, Low_Coefficient, 1), Shift_Left (State, 8));
            Masked := And_128 (First_Fold, Pair (16#0000_0000_FFFF_FFFF#, U64'Last));
            Product := CLMUL (Shift_Right (First_Fold, 12), High_Coefficient, 16);
         end if;
         return Xor_128 (Product, Masked);
      end Fold_Width_32;

      function Final_32
        (State : Vector_128; Reflected : Boolean; Keys : Folding_Keys) return Value is
         Folded : constant Vector_128 := Fold_Width_32 (State, Keys (6), Keys (5), Reflected);
         Mu_Polynomial : constant Vector_128 := Pair (Keys (8), Keys (7));
         First_Product, Second_Product, Reduced : Vector_128;
      begin
         if Reflected then
            First_Product := CLMUL (Folded, Mu_Polynomial, 0);
            Second_Product := CLMUL (First_Product, Mu_Polynomial, 16);
            Reduced := Xor_128 (Folded, Second_Product);
         else
            First_Product := Shift_Left (CLMUL (Folded, Mu_Polynomial, 1), 4);
            Second_Product := Shift_Left (CLMUL (First_Product, Mu_Polynomial, 17), 4);
            Reduced := Xor_128 (Second_Product, Folded);
         end if;
         if Width = 16 then
            return
              (if Reflected then Value (Lane (Reduced, True) and 16#FFFF#)
               else Value (Interfaces.Shift_Right (Lane (Reduced, False), 48) and 16#FFFF#));
         else
            return
              (if Reflected then Value (Lane (Reduced, True) and 16#FFFF_FFFF#)
               else Value (Interfaces.Shift_Right (Lane (Reduced, False), 32) and 16#FFFF_FFFF#));
         end if;
      end Final_32;

      function Final_64
        (State : Vector_128; Reflected : Boolean; Keys : Folding_Keys) return Value is
         Coeff : constant Vector_128 := Coefficient (Keys (6), Keys (5), Reflected);
         Folded : Vector_128;
         Mu_Polynomial : constant Vector_128 := Coefficient (Keys (7), Keys (8), Reflected);
         First_Product, Second_Product, Reduced : Vector_128;
      begin
         if Reflected then
            Folded := Xor_128 (CLMUL (Coeff, State, 1), Shift_Right (State, 8));
            First_Product := CLMUL (Folded, Mu_Polynomial, 0);
            Second_Product := CLMUL (First_Product, Mu_Polynomial, 16);
            Reduced := Xor_128 (Xor_128 (Second_Product, Shift_Left (First_Product, 8)), Folded);
            return Value (Lane (Reduced, True));
         else
            Folded := Xor_128 (CLMUL (State, Coeff, 1), Shift_Left (State, 8));
            declare
               High_Only : constant Vector_128 := And_128 (Folded, Pair (U64'Last, 0));
            begin
               First_Product := CLMUL (High_Only, Mu_Polynomial, 17);
               Second_Product := CLMUL (Xor_128 (First_Product, High_Only), Mu_Polynomial, 1);
               Reduced := Xor_128 (Second_Product, Folded);
            end;
            return Value (Lane (Reduced, False));
         end if;
      end Final_64;

      function Update
        (State : Value; Reflected : Boolean; Keys : Folding_Keys; Data : Byte_Array) return Value is
         Positioned : aliased Vector_512 := (others => 0);
         Folded : Vector_128;
      begin
         if Reflected then
            Positioned (0) := U64 (State);
         else
            Positioned (7) := Interfaces.Shift_Left (U64 (State), 64 - Width);
         end if;
         Folded := Fold_To_128 (Positioned, Reflected, Keys, Data);
         return (if Width <= 32 then Final_32 (Folded, Reflected, Keys)
                 else Final_64 (Folded, Reflected, Keys));
      end Update;
   end Engine;

   package Engine_16 is new Engine (Interfaces.Unsigned_16, 16);
   package Engine_32 is new Engine (Interfaces.Unsigned_32, 32);
   package Engine_64 is new Engine (Interfaces.Unsigned_64, 64);

   function Compiled return Boolean is (True);

   function Update_16
     (State : Interfaces.Unsigned_16; Reflected : Boolean;
      Keys : Folding_Keys; Data : Byte_Array) return Interfaces.Unsigned_16 is
     (Engine_16.Update (State, Reflected, Keys, Data));

   function Update_32
     (State : Interfaces.Unsigned_32; Reflected : Boolean;
      Keys : Folding_Keys; Data : Byte_Array) return Interfaces.Unsigned_32 is
     (Engine_32.Update (State, Reflected, Keys, Data));

   function Update_64
     (State : Interfaces.Unsigned_64; Reflected : Boolean;
      Keys : Folding_Keys; Data : Byte_Array) return Interfaces.Unsigned_64 is
     (Engine_64.Update (State, Reflected, Keys, Data));
end Flyology_CRC.Generic_AVX512_VPCLMUL;
