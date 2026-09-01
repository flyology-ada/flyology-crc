with Interfaces;
with System.Machine_Code;
with Flyology_CRC.X86_Feature_Decode;

package body Flyology_CRC.X86_Features is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use System.Machine_Code;

   type CPUID_Result is record
      EAX, EBX, ECX, EDX : Interfaces.Unsigned_32;
   end record;

   function CPUID
     (Leaf, Subleaf : Interfaces.Unsigned_32) return CPUID_Result
   with Global => null;

   function CPUID
     (Leaf, Subleaf : Interfaces.Unsigned_32) return CPUID_Result is
      Result : CPUID_Result;
   begin
      --  CPUID is the native mechanism: there is no stable fixed-signature
      --  operating-system ABI that supplies these architecture facts on all
      --  supported x86-64 hosts.
      Asm
        ("cpuid",
         Outputs  =>
           [Interfaces.Unsigned_32'Asm_Output ("=a", Result.EAX),
            Interfaces.Unsigned_32'Asm_Output ("=b", Result.EBX),
            Interfaces.Unsigned_32'Asm_Output ("=c", Result.ECX),
            Interfaces.Unsigned_32'Asm_Output ("=d", Result.EDX)],
         Inputs   =>
           [Interfaces.Unsigned_32'Asm_Input ("0", Leaf),
            Interfaces.Unsigned_32'Asm_Input ("2", Subleaf)],
         Volatile => True);
      return Result;
   end CPUID;

   function Read_XCR0 return Interfaces.Unsigned_64
   with Global => null;

   function Read_XCR0 return Interfaces.Unsigned_64 is
      Low, High : Interfaces.Unsigned_32;
   begin
      --  The detector calls this leaf only after CPUID establishes XSAVE,
      --  OSXSAVE, and AVX.  Executing XGETBV before that gate may raise #UD.
      Asm
        ("xgetbv",
         Outputs  =>
           [Interfaces.Unsigned_32'Asm_Output ("=a", Low),
            Interfaces.Unsigned_32'Asm_Output ("=d", High)],
         Inputs   => Interfaces.Unsigned_32'Asm_Input ("c", 0),
         Volatile => True);
      return
        Interfaces.Shift_Left (Interfaces.Unsigned_64 (High), 32)
        or Interfaces.Unsigned_64 (Low);
   end Read_XCR0;

   function Detect return X86_Feature_Decode.Capabilities is
      Maximum : constant CPUID_Result := CPUID (0, 0);
      Leaf_1  : CPUID_Result := (others => 0);
      Leaf_7  : CPUID_Result := (others => 0);
      XCR0    : Interfaces.Unsigned_64 := 0;
      Read    : Boolean := False;
   begin
      if Maximum.EAX >= 1 then
         Leaf_1 := CPUID (1, 0);
      end if;

      if Maximum.EAX >= 7 then
         Leaf_7 := CPUID (7, 0);
      end if;

      if X86_Feature_Decode.XCR0_May_Be_Read
           (Maximum.EAX, Leaf_1.ECX)
      then
         XCR0 := Read_XCR0;
         Read := True;
      end if;

      return
        X86_Feature_Decode.Decode
          ((Maximum_Basic_Leaf => Maximum.EAX,
            Leaf_1_ECX         => Leaf_1.ECX,
            Leaf_7_EBX         => Leaf_7.EBX,
            Leaf_7_ECX         => Leaf_7.ECX,
            XCR0               => XCR0,
            XCR0_Was_Read      => Read));
   end Detect;

   Detected : constant X86_Feature_Decode.Capabilities := Detect;

   function Generic_SSE_Available return Boolean is
     (Detected.Generic_SSE);

   function CRC32C_SSE_Available return Boolean is
     (Detected.CRC32C_SSE);

   function AVX512_Ternary_Available return Boolean is
     (Detected.AVX512_Ternary);

   function CRC32C_VPCLMUL_Available return Boolean is
     (Detected.CRC32C_VPCLMUL);

   function AVX512_VPCLMUL_Available return Boolean is
     (Detected.AVX512_VPCLMUL);
end Flyology_CRC.X86_Features;
