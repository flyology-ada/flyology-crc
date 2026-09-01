package body Flyology_CRC.X86_Feature_Decode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   --  Intel and AMD assign these architectural capability bits in CPUID.
   --  Keep them private because they are mechanism, not API.
   PCLMULQDQ : constant Interfaces.Unsigned_32 := 2 ** 1;
   SSSE3      : constant Interfaces.Unsigned_32 := 2 ** 9;
   SSE4_1     : constant Interfaces.Unsigned_32 := 2 ** 19;
   SSE4_2     : constant Interfaces.Unsigned_32 := 2 ** 20;
   XSAVE      : constant Interfaces.Unsigned_32 := 2 ** 26;
   OSXSAVE    : constant Interfaces.Unsigned_32 := 2 ** 27;
   AVX        : constant Interfaces.Unsigned_32 := 2 ** 28;

   AVX512F  : constant Interfaces.Unsigned_32 := 2 ** 16;
   AVX512BW : constant Interfaces.Unsigned_32 := 2 ** 30;
   AVX512VL : constant Interfaces.Unsigned_32 := 2 ** 31;

   VPCLMULQDQ : constant Interfaces.Unsigned_32 := 2 ** 10;

   --  XCR0 bits 1, 2, 5, 6, and 7 enable XMM, YMM, opmask, upper-ZMM,
   --  and high-16-ZMM state respectively.
   AVX512_XCR0_State : constant Interfaces.Unsigned_64 := 16#E6#;

   function Has_All
     (Value, Required : Interfaces.Unsigned_32) return Boolean is
     ((Value and Required) = Required);

   function XCR0_May_Be_Read
     (Maximum_Basic_Leaf : Interfaces.Unsigned_32;
      Leaf_1_ECX         : Interfaces.Unsigned_32) return Boolean is
     (Maximum_Basic_Leaf >= 7
      and then Has_All (Leaf_1_ECX, XSAVE or OSXSAVE or AVX));

   function Decode (Value : Inputs) return Capabilities is
      Has_Leaf_1 : constant Boolean := Value.Maximum_Basic_Leaf >= 1;
      Has_Leaf_7 : constant Boolean := Value.Maximum_Basic_Leaf >= 7;

      Generic_SSE : constant Boolean :=
        Has_Leaf_1
        and then Has_All (Value.Leaf_1_ECX, SSSE3 or SSE4_1 or PCLMULQDQ);
      CRC32C_SSE : constant Boolean :=
        Has_Leaf_1
        and then Has_All (Value.Leaf_1_ECX, SSE4_1 or SSE4_2 or PCLMULQDQ);

      AVX512_State : constant Boolean :=
        Value.XCR0_Was_Read
        and then XCR0_May_Be_Read
                   (Value.Maximum_Basic_Leaf, Value.Leaf_1_ECX)
        and then
          (Value.XCR0 and AVX512_XCR0_State) = AVX512_XCR0_State;
      AVX512_Ternary : constant Boolean :=
        Generic_SSE
        and then Has_Leaf_7
        --  FMA and F16C are unrelated to the generic CRC leaves. Gate AVX-512
        --  on its actual ISA bits plus operating-system vector-state support.
        and then AVX512_State
        and then Has_All (Value.Leaf_7_EBX, AVX512F or AVX512VL);
      CRC32C_VPCLMUL : constant Boolean :=
        CRC32C_SSE
        and then Has_Leaf_7
        and then AVX512_State
        and then Has_All (Value.Leaf_7_EBX, AVX512F or AVX512VL)
        and then Has_All (Value.Leaf_7_ECX, VPCLMULQDQ);
      AVX512_VPCLMUL : constant Boolean :=
        AVX512_Ternary
        and then Has_All (Value.Leaf_7_EBX, AVX512BW)
        and then Has_All (Value.Leaf_7_ECX, VPCLMULQDQ);
   begin
      return
        (Generic_SSE    => Generic_SSE,
         CRC32C_SSE     => CRC32C_SSE,
         AVX512_Ternary => AVX512_Ternary,
         CRC32C_VPCLMUL => CRC32C_VPCLMUL,
         AVX512_VPCLMUL => AVX512_VPCLMUL);
   end Decode;
end Flyology_CRC.X86_Feature_Decode;
