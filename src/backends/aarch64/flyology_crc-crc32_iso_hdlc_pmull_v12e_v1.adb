with Ada.Streams;
with System.Machine_Code;
with System.Storage_Elements;

package body Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1 is
   use System.Machine_Code;
   use type Ada.Streams.Stream_Element_Offset;
   use type System.Bit_Order;
   use type System.Storage_Elements.Integer_Address;
   use type System.Storage_Elements.Storage_Offset;

   subtype Offset_Type is Ada.Streams.Stream_Element_Offset;
   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the AArch64 ISO-HDLC fusion backend requires little-endian byte order");

   type Vector_128 is array (0 .. 1) of U64;
   for Vector_128'Alignment use 16;
   pragma Machine_Attribute (Vector_128, "vector_type");

   pragma Compile_Time_Error
     (Vector_128'Size /= 128, "the CRC fusion vector must be exactly 128 bits");
   pragma Compile_Time_Error
     (Vector_128'Alignment /= 16, "the CRC fusion vector must be 16-byte aligned");

   type Byte_Block_8 is array (0 .. 7) of U8;
   type Byte_Block_16 is array (0 .. 15) of U8;

   --  Generated v12e_v1 polynomial constants.  Aligned static vectors avoid
   --  rebuilding both lanes from scalar immediates in every call.
   K_Fold_12 : aliased constant Vector_128 :=
     (16#596C_8D81#, 16#F5E4_8C85#);
   K_Pair : aliased constant Vector_128 :=
     (16#AE68_9191#, 16#CCAA_009E#);
   K_Four : aliased constant Vector_128 :=
     (16#F1DA_05AA#, 16#8125_6527#);
   K_Final : aliased constant Vector_128 :=
     (16#8F35_2D95#, 16#1D95_13D7#);

   function Update_V12_64_Tail
     (State : U32;
      Data  : Byte_Array) return U32 is
      Pointer : System.Address := Data (Data'First)'Address;
      Result  : U32;
      Bytes   : constant Offset_Type := Offset_Type (Data'Length);
   begin
      --  Fixed registers follow the pinned Rust v12e_v1 allocation and are
      --  all caller-saved under AAPCS64.  The fixed-tail geometry makes the entire
      --  operation one region: no accumulator crosses the asm boundary and
      --  arbitrary input alignment remains valid for AArch64 LDP.
      Asm
        (Template =>
           "ldp q18, q17, [%x1]" & ASCII.LF & ASCII.HT &
           "ldp q16, q7, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "ldp q19, q6, [%x1, #64]" & ASCII.LF & ASCII.HT &
           "ldp q5, q3, [%x1, #96]" & ASCII.LF & ASCII.HT &
           "ldp q4, q1, [%x1, #128]" & ASCII.LF & ASCII.HT &
           "ldp q2, q0, [%x1, #160]" & ASCII.LF & ASCII.HT &
           "movi v21.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v21.s[0], %w2" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v18.16b, v21.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x4]" & ASCII.LF & ASCII.HT &
           "dup v21.2d, v20.d[0]" & ASCII.LF & ASCII.HT &
           "dup v20.2d, v20.d[1]" & ASCII.LF & ASCII.HT &
           "add x9, %x1, %x3" & ASCII.LF & ASCII.HT &
           "sub x9, x9, #64" & ASCII.LF & ASCII.HT &
           "add %x1, %x1, #192" & ASCII.LF & ASCII.HT &
           "1:" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1]" & ASCII.LF & ASCII.HT &
           "pmull v25.1q, v17.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q27, q28, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q31, q8, [%x1, #160]" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v23.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v25.16b" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "ldp q25, q27, [%x1, #64]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v6.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v23.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v7.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v24.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v27.1q, v3.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q24, q26, [%x1, #96]" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v28.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v25.16b, v25.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v1.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "eor v26.16b, v26.16b, v27.16b" & ASCII.LF & ASCII.HT &
           "ldp q24, q27, [%x1, #128]" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "add %x1, %x1, #192" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "cmp %x1, x9" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v24.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v27.16b, v27.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v0.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v28.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v25.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v31.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v29.16b, v8.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v23.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v26.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v24.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v27.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v28.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v29.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "b.ne 1b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x5]" & ASCII.LF & ASCII.HT &
           "dup v21.2d, v20.d[0]" & ASCII.LF & ASCII.HT &
           "dup v20.2d, v20.d[1]" & ASCII.LF & ASCII.HT &
           "ldr q25, [%x7]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v18.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v17.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v19.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "ldr q23, [%x6]" & ASCII.LF & ASCII.HT &
           "dup v19.2d, v23.d[0]" & ASCII.LF & ASCII.HT &
           "dup v23.2d, v23.d[1]" & ASCII.LF & ASCII.HT &
           "pmull v24.1q, v17.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v16.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v6.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "pmull v18.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v16.16b, v24.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v7.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull v17.1q, v6.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "dup v18.2d, v25.d[0]" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v7.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "dup v16.2d, v25.d[1]" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v4.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v17.1q, v7.1d, v18.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v16.2d" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v1.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "pmull v21.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v5.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v3.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull v5.1q, v1.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v2.16b, v21.16b" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v3.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v2.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull v4.1q, v3.1d, v18.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v16.2d" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v2.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v1.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v0.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v0.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v0.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v0.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10" & ASCII.LF & ASCII.HT &
           "movi v20.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v20.s[0], %w0" & ASCII.LF & ASCII.HT &
           "ldp q19, q17, [%x1]" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v19.16b, v20.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x5]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "ldp q17, q18, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v19.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v19.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10",
         Outputs =>
           [U32'Asm_Output ("=&r", Result),
            System.Address'Asm_Output ("+&r", Pointer)],
         Inputs   =>
           [U32'Asm_Input ("r", State),
            Offset_Type'Asm_Input ("r", Bytes),
            System.Address'Asm_Input ("r", K_Fold_12'Address),
            System.Address'Asm_Input ("r", K_Pair'Address),
            System.Address'Asm_Input ("r", K_Four'Address),
            System.Address'Asm_Input ("r", K_Final'Address)],
         Clobber  =>
           "cc,memory,x9,x10," &
           "v0,v1,v2,v3,v4,v5,v6,v7,v8,v16,v17,v18,v19,v20,v21,v22,v23," &
           "v24,v25,v26,v27,v28,v29,v30,v31",
         Volatile => True);
      return Result;
   end Update_V12_64_Tail;

   function Update_1024_V12
     (State  : U32;
      Source : System.Address) return U32 is
      Pointer : constant System.Address := Source;
      Result  : U32;
   begin
      --  Fixed registers follow the pinned Rust v12e_v1 allocation and are
      --  all caller-saved under AAPCS64.  The exact 1,024-byte geometry keeps the entire
      --  operation in one unrolled region: no accumulator crosses the asm boundary,
      --  all payload offsets fit LDP immediates, and arbitrary alignment remains valid.
      Asm
        (Template =>
           "ldp q18, q17, [%x1]" & ASCII.LF & ASCII.HT &
           "ldp q16, q7, [%x1, #32]" & ASCII.LF & ASCII.HT &
           "ldp q19, q6, [%x1, #64]" & ASCII.LF & ASCII.HT &
           "ldp q5, q3, [%x1, #96]" & ASCII.LF & ASCII.HT &
           "ldp q4, q1, [%x1, #128]" & ASCII.LF & ASCII.HT &
           "ldp q2, q0, [%x1, #160]" & ASCII.LF & ASCII.HT &
           "movi v21.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v21.s[0], %w2" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v18.16b, v21.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x3]" & ASCII.LF & ASCII.HT &
           "dup v21.2d, v20.d[0]" & ASCII.LF & ASCII.HT &
           "dup v20.2d, v20.d[1]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #192]" & ASCII.LF & ASCII.HT &
           "pmull v25.1q, v17.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q27, q28, [%x1, #224]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q31, q8, [%x1, #352]" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v23.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v25.16b" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "ldp q25, q27, [%x1, #256]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v6.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v23.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v7.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v24.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v27.1q, v3.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q24, q26, [%x1, #288]" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v28.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v25.16b, v25.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v1.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "eor v26.16b, v26.16b, v27.16b" & ASCII.LF & ASCII.HT &
           "ldp q24, q27, [%x1, #320]" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v24.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v27.16b, v27.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v0.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v28.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v25.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v31.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v29.16b, v8.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v23.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v26.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v24.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v27.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v28.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v29.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #384]" & ASCII.LF & ASCII.HT &
           "pmull v25.1q, v17.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q27, q28, [%x1, #416]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q31, q8, [%x1, #544]" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v23.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v25.16b" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "ldp q25, q27, [%x1, #448]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v6.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v23.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v7.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v24.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v27.1q, v3.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q24, q26, [%x1, #480]" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v28.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v25.16b, v25.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v1.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "eor v26.16b, v26.16b, v27.16b" & ASCII.LF & ASCII.HT &
           "ldp q24, q27, [%x1, #512]" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v24.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v27.16b, v27.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v0.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v28.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v25.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v31.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v29.16b, v8.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v23.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v26.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v24.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v27.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v28.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v29.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #576]" & ASCII.LF & ASCII.HT &
           "pmull v25.1q, v17.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q27, q28, [%x1, #608]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q31, q8, [%x1, #736]" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v23.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v25.16b" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "ldp q25, q27, [%x1, #640]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v6.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v23.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v7.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v24.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v27.1q, v3.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q24, q26, [%x1, #672]" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v28.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v25.16b, v25.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v1.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "eor v26.16b, v26.16b, v27.16b" & ASCII.LF & ASCII.HT &
           "ldp q24, q27, [%x1, #704]" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v24.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v27.16b, v27.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v0.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v28.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v25.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v31.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v29.16b, v8.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v23.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v26.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v24.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v27.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v28.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v29.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q23, q24, [%x1, #768]" & ASCII.LF & ASCII.HT &
           "pmull v25.1q, v17.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q27, q28, [%x1, #800]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q31, q8, [%x1, #928]" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v23.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v25.16b" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "ldp q25, q27, [%x1, #832]" & ASCII.LF & ASCII.HT &
           "pmull v26.1q, v6.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v22.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v23.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v7.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v22.16b, v27.16b, v26.16b" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v24.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "pmull v27.1q, v3.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "ldp q24, q26, [%x1, #864]" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v28.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v25.16b, v25.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v1.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v23.16b, v24.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "eor v26.16b, v26.16b, v27.16b" & ASCII.LF & ASCII.HT &
           "ldp q24, q27, [%x1, #896]" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v24.16b, v24.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "eor v27.16b, v27.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull v29.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull v30.1q, v0.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v28.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v25.16b, v19.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v28.16b, v31.16b, v29.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v29.16b, v8.16b, v30.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v22.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v23.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v0.1q, v0.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v26.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v24.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v27.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v28.16b, v2.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v29.16b, v0.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x4]" & ASCII.LF & ASCII.HT &
           "dup v21.2d, v20.d[0]" & ASCII.LF & ASCII.HT &
           "dup v20.2d, v20.d[1]" & ASCII.LF & ASCII.HT &
           "ldr q25, [%x6]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v18.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v18.1q, v18.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull v23.1q, v19.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v18.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v16.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v16.1q, v16.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v17.16b, v17.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "eor v18.16b, v19.16b, v23.16b" & ASCII.LF & ASCII.HT &
           "ldr q23, [%x5]" & ASCII.LF & ASCII.HT &
           "dup v19.2d, v23.d[0]" & ASCII.LF & ASCII.HT &
           "dup v23.2d, v23.d[1]" & ASCII.LF & ASCII.HT &
           "pmull v24.1q, v17.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v16.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v6.16b, v6.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v17.1q, v17.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "pmull v18.1q, v5.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v5.1q, v5.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v16.16b, v16.16b, v24.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v4.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v7.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v4.1q, v4.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "pmull v17.1q, v6.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "dup v18.2d, v25.d[0]" & ASCII.LF & ASCII.HT &
           "eor v7.16b, v7.16b, v16.16b" & ASCII.LF & ASCII.HT &
           "dup v16.2d, v25.d[1]" & ASCII.LF & ASCII.HT &
           "pmull2 v6.1q, v6.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v4.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v17.1q, v7.1d, v18.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v7.1q, v7.2d, v16.2d" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v1.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "pmull v21.1q, v2.1d, v21.1d" & ASCII.LF & ASCII.HT &
           "eor v5.16b, v5.16b, v6.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v2.1q, v2.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v4.16b, v5.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v3.16b, v7.16b" & ASCII.LF & ASCII.HT &
           "pmull v5.1q, v1.1d, v19.1d" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v2.16b, v21.16b" & ASCII.LF & ASCII.HT &
           "eor v3.16b, v3.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "pmull2 v1.1q, v1.2d, v23.2d" & ASCII.LF & ASCII.HT &
           "eor v2.16b, v2.16b, v5.16b" & ASCII.LF & ASCII.HT &
           "pmull v4.1q, v3.1d, v18.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v3.1q, v3.2d, v16.2d" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v2.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "eor v1.16b, v1.16b, v4.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v0.16b, v3.16b" & ASCII.LF & ASCII.HT &
           "eor v0.16b, v0.16b, v1.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v0.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v0.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10" & ASCII.LF & ASCII.HT &
           "movi v20.2d, #0" & ASCII.LF & ASCII.HT &
           "ins v20.s[0], %w0" & ASCII.LF & ASCII.HT &
           "ldp q19, q17, [%x1, #960]" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v19.16b, v20.16b" & ASCII.LF & ASCII.HT &
           "ldr q20, [%x4]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "ldp q17, q18, [%x1, #992]" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v17.16b" & ASCII.LF & ASCII.HT &
           "pmull v22.1q, v19.1d, v20.1d" & ASCII.LF & ASCII.HT &
           "pmull2 v19.1q, v19.2d, v20.2d" & ASCII.LF & ASCII.HT &
           "eor v21.16b, v19.16b, v22.16b" & ASCII.LF & ASCII.HT &
           "eor v19.16b, v21.16b, v18.16b" & ASCII.LF & ASCII.HT &
           "umov x9, v19.d[0]" & ASCII.LF & ASCII.HT &
           "umov x10, v19.d[1]" & ASCII.LF & ASCII.HT &
           "crc32x %w0, wzr, x9" & ASCII.LF & ASCII.HT &
           "crc32x %w0, %w0, x10",
         Outputs => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [System.Address'Asm_Input ("r", Pointer),
            U32'Asm_Input ("r", State),
            System.Address'Asm_Input ("r", K_Fold_12'Address),
            System.Address'Asm_Input ("r", K_Pair'Address),
            System.Address'Asm_Input ("r", K_Four'Address),
            System.Address'Asm_Input ("r", K_Final'Address)],
         Clobber  =>
           "cc,memory,x9,x10," &
           "v0,v1,v2,v3,v4,v5,v6,v7,v8,v16,v17,v18,v19,v20,v21,v22,v23," &
           "v24,v25,v26,v27,v28,v29,v30,v31",
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

   function CLMUL_Low_And_XOR
     (Left, Right, Addend : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template =>
           "pmull %0.1q, %1.1d, %2.1d" & ASCII.LF & ASCII.HT &
           "eor %0.16b, %0.16b, %3.16b",
         Outputs => Vector_128'Asm_Output ("=&w", Result),
         Inputs  =>
           [Vector_128'Asm_Input ("w", Left),
            Vector_128'Asm_Input ("w", Right),
            Vector_128'Asm_Input ("w", Addend)]);
      return Result;
   end CLMUL_Low_And_XOR;
   pragma Inline_Always (CLMUL_Low_And_XOR);

   function CLMUL_High_And_XOR
     (Left, Right, Addend : Vector_128) return Vector_128 is
      Result : Vector_128;
   begin
      Asm
        (Template =>
           "pmull2 %0.1q, %1.2d, %2.2d" & ASCII.LF & ASCII.HT &
           "eor %0.16b, %0.16b, %3.16b",
         Outputs => Vector_128'Asm_Output ("=&w", Result),
         Inputs  =>
           [Vector_128'Asm_Input ("w", Left),
            Vector_128'Asm_Input ("w", Right),
            Vector_128'Asm_Input ("w", Addend)]);
      return Result;
   end CLMUL_High_And_XOR;
   pragma Inline_Always (CLMUL_High_And_XOR);

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

   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
      --  Generated by corsix/fast-crc32 with
      --  `./generate -i neon -p crc32 -a v12e_v1`, then altered and translated
      --  to Ada. The polynomial-folding constants below must stay paired with
      --  CRC32 (not CRC32C) instructions. See THIRD_PARTY_NOTICES.md.
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
            End_Offset : constant Offset_Type := Offset + Remaining;
            Limit      : constant Offset_Type := Offset + Remaining - 192;
            X0         : Vector_128 := Load_16 (Address_At (Base, Offset));
            X1         : Vector_128 := Load_16 (Address_At (Base, Offset + 16));
            X2         : Vector_128 := Load_16 (Address_At (Base, Offset + 32));
            X3         : Vector_128 := Load_16 (Address_At (Base, Offset + 48));
            X4         : Vector_128 := Load_16 (Address_At (Base, Offset + 64));
            X5         : Vector_128 := Load_16 (Address_At (Base, Offset + 80));
            X6         : Vector_128 := Load_16 (Address_At (Base, Offset + 96));
            X7         : Vector_128 := Load_16 (Address_At (Base, Offset + 112));
            X8         : Vector_128 := Load_16 (Address_At (Base, Offset + 128));
            X9         : Vector_128 := Load_16 (Address_At (Base, Offset + 144));
            X10        : Vector_128 := Load_16 (Address_At (Base, Offset + 160));
            X11        : Vector_128 := Load_16 (Address_At (Base, Offset + 176));
            K          : Vector_128 := Load_16 (K_Fold_12'Address);
            Y          : Vector_128;
         begin
            X0 := Xor_128 (X0, (U64 (CRC0), 0));
            Offset := Offset + 192;

            while Offset <= Limit loop
               Y := CLMUL_Low_And_XOR (X0, K, Load_16 (Address_At (Base, Offset)));
               X0 := CLMUL_High_And_XOR (X0, K, Y);
               Y := CLMUL_Low_And_XOR (X1, K, Load_16 (Address_At (Base, Offset + 16)));
               X1 := CLMUL_High_And_XOR (X1, K, Y);
               Y := CLMUL_Low_And_XOR (X2, K, Load_16 (Address_At (Base, Offset + 32)));
               X2 := CLMUL_High_And_XOR (X2, K, Y);
               Y := CLMUL_Low_And_XOR (X3, K, Load_16 (Address_At (Base, Offset + 48)));
               X3 := CLMUL_High_And_XOR (X3, K, Y);
               Y := CLMUL_Low_And_XOR (X4, K, Load_16 (Address_At (Base, Offset + 64)));
               X4 := CLMUL_High_And_XOR (X4, K, Y);
               Y := CLMUL_Low_And_XOR (X5, K, Load_16 (Address_At (Base, Offset + 80)));
               X5 := CLMUL_High_And_XOR (X5, K, Y);
               Y := CLMUL_Low_And_XOR (X6, K, Load_16 (Address_At (Base, Offset + 96)));
               X6 := CLMUL_High_And_XOR (X6, K, Y);
               Y := CLMUL_Low_And_XOR (X7, K, Load_16 (Address_At (Base, Offset + 112)));
               X7 := CLMUL_High_And_XOR (X7, K, Y);
               Y := CLMUL_Low_And_XOR (X8, K, Load_16 (Address_At (Base, Offset + 128)));
               X8 := CLMUL_High_And_XOR (X8, K, Y);
               Y := CLMUL_Low_And_XOR (X9, K, Load_16 (Address_At (Base, Offset + 144)));
               X9 := CLMUL_High_And_XOR (X9, K, Y);
               Y := CLMUL_Low_And_XOR (X10, K, Load_16 (Address_At (Base, Offset + 160)));
               X10 := CLMUL_High_And_XOR (X10, K, Y);
               Y := CLMUL_Low_And_XOR (X11, K, Load_16 (Address_At (Base, Offset + 176)));
               X11 := CLMUL_High_And_XOR (X11, K, Y);
               Offset := Offset + 192;
            end loop;

            K := Load_16 (K_Pair'Address);
            Y := CLMUL_Low_And_XOR (X0, K, X1);
            X0 := CLMUL_High_And_XOR (X0, K, Y);
            Y := CLMUL_Low_And_XOR (X2, K, X3);
            X2 := CLMUL_High_And_XOR (X2, K, Y);
            Y := CLMUL_Low_And_XOR (X4, K, X5);
            X4 := CLMUL_High_And_XOR (X4, K, Y);
            Y := CLMUL_Low_And_XOR (X6, K, X7);
            X6 := CLMUL_High_And_XOR (X6, K, Y);
            Y := CLMUL_Low_And_XOR (X8, K, X9);
            X8 := CLMUL_High_And_XOR (X8, K, Y);
            Y := CLMUL_Low_And_XOR (X10, K, X11);
            X10 := CLMUL_High_And_XOR (X10, K, Y);

            K := Load_16 (K_Four'Address);
            Y := CLMUL_Low_And_XOR (X0, K, X2);
            X0 := CLMUL_High_And_XOR (X0, K, Y);
            Y := CLMUL_Low_And_XOR (X4, K, X6);
            X4 := CLMUL_High_And_XOR (X4, K, Y);
            Y := CLMUL_Low_And_XOR (X8, K, X10);
            X8 := CLMUL_High_And_XOR (X8, K, Y);

            K := Load_16 (K_Final'Address);
            Y := CLMUL_Low_And_XOR (X0, K, X4);
            X0 := CLMUL_High_And_XOR (X0, K, Y);
            Y := CLMUL_Low_And_XOR (X0, K, X8);
            X0 := CLMUL_High_And_XOR (X0, K, Y);

            CRC0 := CRC_64 (0, X0 (0));
            CRC0 := CRC_64 (CRC0, X0 (1));
            Remaining := End_Offset - Offset;
         end;
      end if;

      if Remaining >= 16 then
         declare
            X0 : Vector_128 := Load_16 (Address_At (Base, Offset));
            K  : constant Vector_128 := Load_16 (K_Pair'Address);
            Y  : Vector_128;
         begin
            X0 := Xor_128 (X0, (U64 (CRC0), 0));
            Offset := Offset + 16;
            Remaining := Remaining - 16;

            while Remaining >= 16 loop
               Y := CLMUL_Low_And_XOR (X0, K, Load_16 (Address_At (Base, Offset)));
               X0 := CLMUL_High_And_XOR (X0, K, Y);
               Offset := Offset + 16;
               Remaining := Remaining - 16;
            end loop;

            CRC0 := CRC_64 (0, X0 (0));
            CRC0 := CRC_64 (CRC0, X0 (1));
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
end Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1;
