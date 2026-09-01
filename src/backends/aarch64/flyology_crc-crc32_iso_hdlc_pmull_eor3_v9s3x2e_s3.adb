with Ada.Streams;
with System;
with System.Machine_Code;
with System.Storage_Elements;

--  The exact-1KiB leaf in this SHA3-selected unit uses the generated v12e_v1
--  constants and folding geometry. See THIRD_PARTY_NOTICES.md.

package body Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3 is
   use System.Machine_Code;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;
   use type System.Bit_Order;
   use type System.Storage_Elements.Integer_Address;
   use type System.Storage_Elements.Storage_Offset;

   subtype Offset_Type is Ada.Streams.Stream_Element_Offset;
   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the AArch64 ISO-HDLC EOR3 backend requires little-endian byte order");

   type Vector_128 is array (0 .. 1) of U64;
   for Vector_128'Alignment use 16;
   pragma Machine_Attribute (Vector_128, "vector_type");

   type Accumulator_Array is array (Natural range 0 .. 8) of Vector_128;
   for Accumulator_Array'Alignment use 16;

   pragma Compile_Time_Error
     (Vector_128'Size /= 128, "the CRC fusion vector must be exactly 128 bits");
   pragma Compile_Time_Error
     (Vector_128'Alignment /= 16, "the CRC fusion vector must be 16-byte aligned");

   type Byte_Block_8 is array (0 .. 7) of U8;
   type Byte_Block_16 is array (0 .. 15) of U8;

   --  Generated v12e_v1 polynomial constants used only by the exact-1KiB
   --  whole-operation leaf below.
   V12_K_Fold_12 : aliased constant Vector_128 :=
     (16#0000_0000_596C_8D81#, 16#0000_0000_F5E4_8C85#);
   V12_K_Pair : aliased constant Vector_128 :=
     (16#0000_0000_AE68_9191#, 16#0000_0000_CCAA_009E#);
   V12_K_Four : aliased constant Vector_128 :=
     (16#0000_0000_F1DA_05AA#, 16#0000_0000_8125_6527#);
   V12_K_Final : aliased constant Vector_128 :=
     (16#0000_0000_8F35_2D95#, 16#0000_0000_1D95_13D7#);

   function Update_1024_V12
     (State : U32;
      Data  : Byte_Array) return U32 is
      Pointer : System.Address := Data (Data'First)'Address;
      Result  : U32;
   begin
      --  Fixed registers follow the pinned Rust v12e_v1 allocation and are
      --  all caller-saved under AAPCS64.  The exact length makes the entire
      --  operation one region: no accumulator crosses the asm boundary and
      --  arbitrary input alignment remains valid for AArch64 LDP.
      Asm
        (Template =>
           "ldp q19, q17, [%x1]" & ASCII.LF & ASCII.HT &
           "ldp q18, q2, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "ldp q16, q6, [%x1, #64]" & ASCII.LF & ASCII.HT &
           "ldp q7, q1, [%x1, #96]" & ASCII.LF & ASCII.HT &
           "ldp q5, q3, [%x1, #128]" & ASCII.LF & ASCII.HT &
           "ldp q4, q0, [%x1, #160]" & ASCII.LF & ASCII.HT &
           "movi v20.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v20.s[0], %w2" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v19.16b, v20.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x3]" & ASCII.LF & ASCII.HT &
           "add %x1, %x1, #192" & ASCII.LF & ASCII.HT &
           "mov x9, #4" & ASCII.LF & ASCII.HT &
           "1:" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1]" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v23.16b, v22.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v17.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v17.16b, v24.16b, v22.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "eor3 v18.16b, v23.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v2.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v2.16b, v24.16b, v22.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v16.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #64]" & ASCII.LF & ASCII.HT &
           "eor3 v16.16b, v23.16b, v22.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v6.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v6.16b, v24.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v7.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #96]" & ASCII.LF & ASCII.HT &
           "eor3 v7.16b, v23.16b, v22.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v1.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v1.16b, v24.16b, v22.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v5.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #128]" & ASCII.LF & ASCII.HT &
           "eor3 v5.16b, v23.16b, v22.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v3.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v3.16b, v24.16b, v22.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v4.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #160]" & ASCII.LF & ASCII.HT &
           "eor3 v4.16b, v23.16b, v22.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v0.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v0.16b, v24.16b, v22.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "add %x1, %x1, #192" & ASCII.LF & ASCII.HT &
           "subs x9, x9, #1" & ASCII.LF & ASCII.HT &
           "b.ne 1b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x4]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v18.16b, v18.16b, v22.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v16.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v16.16b, v16.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v7.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v7.16b, v7.16b, v22.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v5.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v5.16b, v5.16b, v22.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v4.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v4.16b, v4.16b, v22.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x5]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v16.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v16.16b, v16.16b, v22.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v5.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v5.16b, v5.16b, v22.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x6]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v19.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v19.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10" & ASCII.LF & ASCII.HT &
           "movi v20.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v20.s[0], %w0" & ASCII.LF & ASCII.HT &
           "ldp q19, q17, [%x1]" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v19.16b, v20.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x4]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "ldp q17, q18, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor3 v19.16b, v19.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v19.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v19.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10",
         Outputs =>
           [U32'Asm_Output ("=&r", Result),
            System.Address'Asm_Output ("+&r", Pointer)],
         Inputs   =>
           [U32'Asm_Input ("r", State),
            System.Address'Asm_Input ("r", V12_K_Fold_12'Address),
            System.Address'Asm_Input ("r", V12_K_Pair'Address),
            System.Address'Asm_Input ("r", V12_K_Four'Address),
            System.Address'Asm_Input ("r", V12_K_Final'Address)],
         Clobber  =>
           "cc,memory,x9,x10," &
           "v0,v1,v2,v3,v4,v5,v6,v7,v16,v17,v18,v19,v20,v22,v23,v24",
         Volatile => True);
      return Result;
   end Update_1024_V12;

   function Address_At
     (Base : System.Address; Offset : Offset_Type) return System.Address is
     (Base + System.Storage_Elements.Storage_Offset (Offset));
   pragma Inline_Always (Address_At);

   function Load_1 (Source : System.Address) return U8 is
      Value : constant U8 with Import, Address => Source;
   begin
      return Value;
   end Load_1;
   pragma Inline_Always (Load_1);

   function Load_8 (Source : System.Address) return U64 is
      Bytes  : constant Byte_Block_8 with Import, Address => Source;
      Result : U64;
   begin
      Asm
        (Template => "ldr %0, %1",
         Outputs  => U64'Asm_Output ("=&r", Result),
         Inputs   => Byte_Block_8'Asm_Input ("Q", Bytes));
      return Result;
   end Load_8;
   pragma Inline_Always (Load_8);

   function Load_16 (Source : System.Address) return Vector_128 is
      Bytes  : constant Byte_Block_16 with Import, Address => Source;
      Result : Vector_128;
   begin
      Asm
        (Template => "ldr %q0, %1",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   => Byte_Block_16'Asm_Input ("Q", Bytes));
      return Result;
   end Load_16;
   pragma Inline_Always (Load_16);

   function Xor_128 (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template => "eor %0.16b, %1.16b, %2.16b",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   =>
           [Vector_128'Asm_Input ("w", Left),
            Vector_128'Asm_Input ("w", Right)]);
      return Result;
   end Xor_128;
   pragma Inline_Always (Xor_128);

   function EOR3
     (First, Second, Third : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template => "eor3 %0.16b, %1.16b, %2.16b, %3.16b",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   =>
           [Vector_128'Asm_Input ("w", First),
            Vector_128'Asm_Input ("w", Second),
            Vector_128'Asm_Input ("w", Third)]);
      return Result;
   end EOR3;
   pragma Inline_Always (EOR3);

   procedure Fold_192_Loop
     (Vector_Ptr  : in out System.Address;
      Stream0_Ptr : in out System.Address;
      Stream1_Ptr : in out System.Address;
      Stream2_Ptr : in out System.Address;
      Iterations  : Offset_Type;
      CRC0        : in out U32;
      CRC1        : in out U32;
      CRC2        : in out U32;
      K           : Vector_128;
      X           : in out Accumulator_Array) is
      Loop_Count : Offset_Type := Iterations;
   begin
      --  Keep the nine fold accumulators and all three scalar CRC streams in
      --  registers for the complete pinned 192-byte loop.  Fixed registers
      --  avoid copy-in/out traffic on every iteration, while the three CRC
      --  streams retain the low0/low1/low2/high0/high1/high2 order.
      Asm
        (Template =>
           "ldp q0, q1, [%x8]" & ASCII.LF & ASCII.HT &
           "ldp q2, q3, [%x8, #32]" & ASCII.LF & ASCII.HT &
           "ldp q4, q5, [%x8, #64]" & ASCII.LF & ASCII.HT &
           "ldp q6, q7, [%x8, #96]" & ASCII.LF & ASCII.HT &
           "ldr q8, [%x8, #128]" & ASCII.LF & ASCII.HT &
           "ldr q12, [%x9]" & ASCII.LF & ASCII.HT &
           "1:" & ASCII.LF & ASCII.HT &
           "ldp q9, q10, [%x0], #32" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v0.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v0.16b, v0.16b, v11.16b, v9.16b" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v1.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v1.16b, v1.16b, v11.16b, v10.16b" & ASCII.LF & ASCII.HT &
           "ldp q9, q10, [%x0], #32" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v2.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v2.16b, v2.16b, v11.16b, v9.16b" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v3.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v3.16b, v3.16b, v11.16b, v10.16b" & ASCII.LF & ASCII.HT &
           "ldp q9, q10, [%x0], #32" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v4.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v4.16b, v4.16b, v11.16b, v9.16b" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v5.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v5.16b, v5.16b, v11.16b, v10.16b" & ASCII.LF & ASCII.HT &
           "ldp q9, q10, [%x0], #32" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v6.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v6.16b, v6.16b, v11.16b, v9.16b" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v7.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v7.16b, v7.16b, v11.16b, v10.16b" & ASCII.LF & ASCII.HT &
           "ldr q9, [%x0], #16" & ASCII.LF & ASCII.HT &
           "pmull v11.1q, v8.1d, v12.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v8.1q, v8.2d, v12.2d" & ASCII.LF & ASCII.HT &
           "eor3 v8.16b, v8.16b, v11.16b, v9.16b" & ASCII.LF & ASCII.HT &
           "ldp x9, x10, [%x1], #16" & ASCII.LF & ASCII.HT &
           "ldp x11, x12, [%x2], #16" & ASCII.LF & ASCII.HT &
           "ldp x13, x14, [%x3], #16" & ASCII.LF & ASCII.HT &
           "crc32x %w5, %w5, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w6, %w6, x11" & ASCII.LF & ASCII.HT &
           "crc32x %w7, %w7, x13" & ASCII.LF & ASCII.HT &
           "crc32x %w5, %w5, x10" & ASCII.LF & ASCII.HT &
           "crc32x %w6, %w6, x12" & ASCII.LF & ASCII.HT &
           "crc32x %w7, %w7, x14" & ASCII.LF & ASCII.HT &
           "subs %x4, %x4, #1" & ASCII.LF & ASCII.HT &
           "b.ne 1b" & ASCII.LF & ASCII.HT &
           "stp q0, q1, [%x8]" & ASCII.LF & ASCII.HT &
           "stp q2, q3, [%x8, #32]" & ASCII.LF & ASCII.HT &
           "stp q4, q5, [%x8, #64]" & ASCII.LF & ASCII.HT &
           "stp q6, q7, [%x8, #96]" & ASCII.LF & ASCII.HT &
           "str q8, [%x8, #128]",
         Outputs =>
           [System.Address'Asm_Output ("+&r", Vector_Ptr),
            System.Address'Asm_Output ("+&r", Stream0_Ptr),
            System.Address'Asm_Output ("+&r", Stream1_Ptr),
            System.Address'Asm_Output ("+&r", Stream2_Ptr),
            Offset_Type'Asm_Output ("+&r", Loop_Count),
            U32'Asm_Output ("+&r", CRC0),
            U32'Asm_Output ("+&r", CRC1),
            U32'Asm_Output ("+&r", CRC2)],
         Inputs   =>
           [System.Address'Asm_Input ("r", X'Address),
            System.Address'Asm_Input ("r", K'Address)],
         Clobber  =>
           "cc,memory,x9,x10,x11,x12,x13,x14," &
           "v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12",
         Volatile => True);
   end Fold_192_Loop;
   pragma Inline_Always (Fold_192_Loop);

   function CLMUL_Low (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template => "pmull %0.1q, %1.1d, %2.1d",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   =>
           [Vector_128'Asm_Input ("w", Left),
            Vector_128'Asm_Input ("w", Right)]);
      return Result;
   end CLMUL_Low;
   pragma Inline_Always (CLMUL_Low);

   function CLMUL_High (Left, Right : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template => "pmull2 %0.1q, %1.2d, %2.2d",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   =>
           [Vector_128'Asm_Input ("w", Left),
            Vector_128'Asm_Input ("w", Right)]);
      return Result;
   end CLMUL_High;
   pragma Inline_Always (CLMUL_High);

   function CLMUL_Scalar (Left, Right : U32) return Vector_128 is
   begin
      return CLMUL_Low ((U64 (Left), 0), (U64 (Right), 0));
   end CLMUL_Scalar;
   pragma Inline_Always (CLMUL_Scalar);

   function Square_P8_Low_Scalar (Value : U32) return U64 is
      Result     : U64 := 0;
      Byte_Value : U64;
      Product    : U64;
   begin
      --  vmull_p8 squares four nonzero polynomial-byte lanes from the U32
      --  accumulator.  GF(2) cross terms cancel, so input bit I maps to
      --  product bit 2*I within each independent 16-bit result lane.
      for Lane in 0 .. 3 loop
         Byte_Value :=
           Interfaces.Shift_Right (U64 (Value), 8 * Lane) and 16#FF#;
         Product := 0;
         for Bit in 0 .. 7 loop
            if (Byte_Value and Interfaces.Shift_Left (U64'(1), Bit)) /= 0 then
               Product := Product xor Interfaces.Shift_Left (U64'(1), 2 * Bit);
            end if;
         end loop;
         Result := Result xor Interfaces.Shift_Left (Product, 16 * Lane);
      end loop;
      return Result;
   end Square_P8_Low_Scalar;

   function Square_P8_Low (Value : U32) return U64 is
      Source : constant Vector_128 := (U64 (Value), 0);
      Result : Vector_128;
   begin
      --  This is the packed-byte vmull_p8 used by the pinned Rust xnmodp
      --  helper, not the 64-by-64 PMULL used by the folding loop.
      Asm
        (Template => "pmull %0.8h, %1.8b, %1.8b",
         Outputs  => Vector_128'Asm_Output ("=&w", Result),
         Inputs   => Vector_128'Asm_Input ("w", Source));
      pragma Assert (Result (0) = Square_P8_Low_Scalar (Value));
      return Result (0);
   end Square_P8_Low;
   pragma Inline_Always (Square_P8_Low);

   function CRC_Byte (State : U32; Value : U8) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32b %w0, %w1, %w2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", State), U8'Asm_Input ("r", Value)]);
      return Result;
   end CRC_Byte;
   pragma Inline_Always (CRC_Byte);

   function CRC_Word (State, Value : U32) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32w %w0, %w1, %w2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", State), U32'Asm_Input ("r", Value)]);
      return Result;
   end CRC_Word;
   pragma Inline_Always (CRC_Word);

   function CRC_64 (State : U32; Value : U64) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32x %w0, %w1, %2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", State), U64'Asm_Input ("r", Value)]);
      return Result;
   end CRC_64;
   pragma Inline_Always (CRC_64);

   function XNModP (Exponent : U64) return U32 is
      N     : U64 := Exponent;
      Stack : U64 := not U64'(1);
      Acc   : U32;
      Low   : U32;
      Y     : U64;
   begin
      --  The constants describe the generated addition chain and CRC-32
      --  polynomial bit positions used by XNModP.
      while N > 191 loop
         Stack := Interfaces.Shift_Left (Stack, 1) + (N and 1);
         N := Interfaces.Shift_Right (N, 1) - 16;
      end loop;
      Stack := not Stack;
      Acc := Interfaces.Shift_Right (U32'(16#8000_0000#), Natural (N and 31));
      N := Interfaces.Shift_Right (N, 5);

      while N > 0 loop
         Acc := CRC_Word (Acc, 0);
         N := N - 1;
      end loop;

      loop
         Low := U32 (Stack and 1);
         Stack := Interfaces.Shift_Right (Stack, 1);
         exit when Stack = 0;
         Y := Square_P8_Low (Acc);
         Acc := CRC_64 (0, Interfaces.Shift_Left (Y, Natural (Low)));
      end loop;
      return Acc;
   end XNModP;
   pragma Inline_Always (XNModP);

   function CRC_Shift (CRC : U32; Byte_Length : U64) return Vector_128 is
   begin
      return CLMUL_Scalar (CRC, XNModP (Byte_Length * 8 - 33));
   end CRC_Shift;
   pragma Inline_Always (CRC_Shift);

   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
      --  Generated by corsix/fast-crc32 with
      --  `./generate -i neon_eor3 -p crc32 -a v9s3x2e_s3`, then altered and
      --  translated to Ada. The folding constants below must stay paired with
      --  standard CRC32, never Castagnoli CRC32C, instructions. See
      --  THIRD_PARTY_NOTICES.md.
      CRC0      : U32 := State;
      Offset    : Offset_Type := 0;
      Remaining : Offset_Type := Data'Length;
      Base      : System.Address := System.Null_Address;
   begin
      if Remaining = 0 then
         return State;
      end if;

      Base := Data (Data'First)'Address;

      while Remaining > 0
        and then System.Storage_Elements.To_Integer (Address_At (Base, Offset)) mod 8 /= 0
      loop
         CRC0 := CRC_Byte (CRC0, Load_1 (Address_At (Base, Offset)));
         Offset := Offset + 1;
         Remaining := Remaining - 1;
      end loop;

      if Remaining >= 8
        and then System.Storage_Elements.To_Integer (Address_At (Base, Offset)) mod 16 /= 0
      then
         CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset)));
         Offset := Offset + 8;
         Remaining := Remaining - 8;
      end if;

      if Remaining >= 192 then
         declare
            End_Offset  : constant Offset_Type := Offset + Remaining;
            Block_Count : constant Offset_Type := Remaining / 192;
            Iterations  : constant Offset_Type := Block_Count - 1;
            K_Length    : constant Offset_Type := Block_Count * 16;
            Buffer_2    : Offset_Type := Offset + K_Length * 3;
            Scalar_0    : System.Address := Address_At (Base, Offset);
            Scalar_1    : System.Address := Address_At (Base, Offset + K_Length);
            Scalar_2    : System.Address := Address_At (Base, Offset + K_Length * 2);
            Vector_Data : System.Address :=
              Address_At (Base, Buffer_2 + 144);
            CRC1        : U32 := 0;
            CRC2        : U32 := 0;
            X           : Accumulator_Array :=
              (0 => Load_16 (Address_At (Base, Buffer_2)),
               1 => Load_16 (Address_At (Base, Buffer_2 + 16)),
               2 => Load_16 (Address_At (Base, Buffer_2 + 32)),
               3 => Load_16 (Address_At (Base, Buffer_2 + 48)),
               4 => Load_16 (Address_At (Base, Buffer_2 + 64)),
               5 => Load_16 (Address_At (Base, Buffer_2 + 80)),
               6 => Load_16 (Address_At (Base, Buffer_2 + 96)),
               7 => Load_16 (Address_At (Base, Buffer_2 + 112)),
               8 => Load_16 (Address_At (Base, Buffer_2 + 128)));
            K           : Vector_128 := (16#26B7_0C3D#, 16#3F41_287A#);
            Y0, Y2      : Vector_128;
            Y4, Y6      : Vector_128;
            VC0, VC1    : Vector_128;
            VC2         : Vector_128;
            VC          : U64;
         begin
            if Iterations > 0 then
               Fold_192_Loop
                 (Vector_Data, Scalar_0, Scalar_1, Scalar_2, Iterations,
                  CRC0, CRC1, CRC2, K, X);
            end if;

            Offset := Offset + Iterations * 16;
            Buffer_2 := Buffer_2 + Block_Count * 144;

            K := (16#AE68_9191#, 16#CCAA_009E#);
            Y0 := CLMUL_Low (X (0), K);
            X (0) := CLMUL_High (X (0), K);
            X (0) := EOR3 (X (0), Y0, X (1));
            X (1) := X (2);
            X (2) := X (3);
            X (3) := X (4);
            X (4) := X (5);
            X (5) := X (6);
            X (6) := X (7);
            X (7) := X (8);

            Y0 := CLMUL_Low (X (0), K);
            X (0) := CLMUL_High (X (0), K);
            Y2 := CLMUL_Low (X (2), K);
            X (2) := CLMUL_High (X (2), K);
            Y4 := CLMUL_Low (X (4), K);
            X (4) := CLMUL_High (X (4), K);
            Y6 := CLMUL_Low (X (6), K);
            X (6) := CLMUL_High (X (6), K);
            X (0) := EOR3 (X (0), Y0, X (1));
            X (2) := EOR3 (X (2), Y2, X (3));
            X (4) := EOR3 (X (4), Y4, X (5));
            X (6) := EOR3 (X (6), Y6, X (7));

            K := (16#F1DA_05AA#, 16#8125_6527#);
            Y0 := CLMUL_Low (X (0), K);
            X (0) := CLMUL_High (X (0), K);
            Y4 := CLMUL_Low (X (4), K);
            X (4) := CLMUL_High (X (4), K);
            X (0) := EOR3 (X (0), Y0, X (2));
            X (4) := EOR3 (X (4), Y4, X (6));

            K := (16#8F35_2D95#, 16#1D95_13D7#);
            Y0 := CLMUL_Low (X (0), K);
            X (0) := CLMUL_High (X (0), K);
            X (0) := EOR3 (X (0), Y0, X (4));

            CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset)));
            CRC1 := CRC_64 (CRC1, Load_8 (Address_At (Base, Offset + K_Length)));
            CRC2 := CRC_64 (CRC2, Load_8 (Address_At (Base, Offset + K_Length * 2)));
            CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset + 8)));
            CRC1 := CRC_64 (CRC1, Load_8 (Address_At (Base, Offset + K_Length + 8)));
            CRC2 := CRC_64 (CRC2, Load_8 (Address_At (Base, Offset + K_Length * 2 + 8)));

            VC0 := CRC_Shift (CRC0, U64 (K_Length * 2 + Block_Count * 144));
            VC1 := CRC_Shift (CRC1, U64 (K_Length + Block_Count * 144));
            VC2 := CRC_Shift (CRC2, U64 (Block_Count * 144));
            VC := EOR3 (VC0, VC1, VC2) (0);

            CRC0 := CRC_64 (0, X (0) (0));
            CRC0 := CRC_64 (CRC0, VC xor X (0) (1));

            Offset := Buffer_2;
            Remaining := End_Offset - Offset;
         end;
      end if;

      if Remaining >= 32 then
         declare
            K_Length : constant Offset_Type := ((Remaining - 8) / 24) * 8;
            CRC1     : U32 := 0;
            CRC2     : U32 := 0;
            VC0      : Vector_128;
            VC1      : Vector_128;
            VC       : U64;
         begin
            loop
               CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset)));
               CRC1 := CRC_64 (CRC1, Load_8 (Address_At (Base, Offset + K_Length)));
               CRC2 := CRC_64 (CRC2, Load_8 (Address_At (Base, Offset + K_Length * 2)));
               Offset := Offset + 8;
               Remaining := Remaining - 24;
               exit when Remaining < 32;
            end loop;

            VC0 := CRC_Shift (CRC0, U64 (K_Length * 2 + 8));
            VC1 := CRC_Shift (CRC1, U64 (K_Length + 8));
            VC := Xor_128 (VC0, VC1) (0);

            Offset := Offset + K_Length * 2;
            CRC0 := CRC2;
            CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset)) xor VC);
            Offset := Offset + 8;
            Remaining := Remaining - 8;
         end;
      end if;

      while Remaining >= 8 loop
         CRC0 := CRC_64 (CRC0, Load_8 (Address_At (Base, Offset)));
         Offset := Offset + 8;
         Remaining := Remaining - 8;
      end loop;

      while Remaining > 0 loop
         CRC0 := CRC_Byte (CRC0, Load_1 (Address_At (Base, Offset)));
         Offset := Offset + 1;
         Remaining := Remaining - 1;
      end loop;

      return CRC0;
   end Update;
end Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3;
