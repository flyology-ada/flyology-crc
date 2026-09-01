with Ada.Text_IO;
with Interfaces;
with Flyology_CRC.X86_Feature_Decode;
with Flyology_CRC.X86_Features;

procedure Flyology_CRC.X86_Feature_Decode_Tests is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   package Decode renames Flyology_CRC.X86_Feature_Decode;

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

   type Bit_List is array (Positive range <>) of Interfaces.Unsigned_32;
   XGETBV_Prerequisites : constant Bit_List := [XSAVE, OSXSAVE, AVX];

   --  This complete CRC capability set deliberately omits the unrelated FMA
   --  and F16C leaf-1 bits.
   Complete : constant Decode.Inputs :=
     (Maximum_Basic_Leaf => 7,
      Leaf_1_ECX         =>
        PCLMULQDQ or SSSE3 or SSE4_1 or SSE4_2 or XSAVE or OSXSAVE or AVX,
      Leaf_7_EBX         => AVX512F or AVX512BW or AVX512VL,
      Leaf_7_ECX         => VPCLMULQDQ,
      XCR0               => 16#E6#,
      XCR0_Was_Read      => True);

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Check_No_Generic_SSE
     (Value   : Decode.Inputs;
      Message : String) is
      Result : constant Decode.Capabilities := Decode.Decode (Value);
   begin
      Check (not Result.Generic_SSE, Message & " generic SSE");
      Check (not Result.AVX512_Ternary, Message & " AVX-512 ternary");
      Check (not Result.AVX512_VPCLMUL, Message & " AVX-512 VPCLMUL");
   end Check_No_Generic_SSE;

   procedure Check_No_CRC32C_SSE
     (Value   : Decode.Inputs;
      Message : String) is
      Result : constant Decode.Capabilities := Decode.Decode (Value);
   begin
      Check (not Result.CRC32C_SSE, Message & " CRC32C SSE");
      Check (not Result.CRC32C_VPCLMUL, Message & " CRC32C VPCLMUL");
   end Check_No_CRC32C_SSE;

   procedure Check_No_AVX512
     (Value   : Decode.Inputs;
      Message : String) is
      Result : constant Decode.Capabilities := Decode.Decode (Value);
   begin
      Check (not Result.AVX512_Ternary, Message & " AVX-512 ternary");
      Check (not Result.CRC32C_VPCLMUL, Message & " CRC32C VPCLMUL");
      Check (not Result.AVX512_VPCLMUL, Message & " AVX-512 VPCLMUL");
   end Check_No_AVX512;

   procedure Check_Missing_Leaf_1
     (Bit           : Interfaces.Unsigned_32;
      Check_Generic : Boolean;
      CRC32C        : Boolean;
      AVX512        : Boolean;
      Label         : String) is
      Value : Decode.Inputs := Complete;
   begin
      Value.Leaf_1_ECX := Value.Leaf_1_ECX and not Bit;
      if Check_Generic then
         Check_No_Generic_SSE (Value, "missing " & Label);
      end if;
      if CRC32C then
         Check_No_CRC32C_SSE (Value, "missing " & Label);
      end if;
      if AVX512 then
         Check_No_AVX512 (Value, "missing " & Label);
      end if;
   end Check_Missing_Leaf_1;

   procedure Check_Missing_XCR0
     (Bit   : Interfaces.Unsigned_64;
      Label : String) is
      Value : Decode.Inputs := Complete;
   begin
      Value.XCR0 := Value.XCR0 and not Bit;
      Check_No_AVX512 (Value, "missing XCR0 " & Label);
   end Check_Missing_XCR0;

   Result : Decode.Capabilities;
begin
   Result := Decode.Decode (Complete);
   Check (Result.Generic_SSE, "complete generic SSE capability set");
   Check (Result.CRC32C_SSE, "complete CRC32C SSE capability set");
   Check
     (Result.AVX512_Ternary,
      "AVX-512 ternary capability does not require FMA or F16C");
   Check
     (Result.CRC32C_VPCLMUL,
      "CRC32C VPCLMUL capability does not require FMA or F16C");
   Check
     (Result.AVX512_VPCLMUL,
      "AVX-512 VPCLMUL capability does not require FMA or F16C");

   declare
      Value : Decode.Inputs := Complete;
   begin
      Value.Maximum_Basic_Leaf := 0;
      Result := Decode.Decode (Value);
      Check
        (not Result.Generic_SSE
         and then not Result.CRC32C_SSE
         and then not Result.AVX512_Ternary
         and then not Result.CRC32C_VPCLMUL
         and then not Result.AVX512_VPCLMUL,
         "leaf 1 must be validated");
      Check
        (not Decode.XCR0_May_Be_Read
               (Value.Maximum_Basic_Leaf, Value.Leaf_1_ECX),
         "XGETBV forbidden without leaf 7");
   end;

   declare
      Value : Decode.Inputs := Complete;
   begin
      Value.Maximum_Basic_Leaf := 1;
      Result := Decode.Decode (Value);
      Check (Result.Generic_SSE, "leaf 1 retains generic SSE");
      Check (Result.CRC32C_SSE, "leaf 1 retains CRC32C SSE");
      Check (not Result.AVX512_Ternary, "leaf 7 required for AVX-512");
      Check (not Result.CRC32C_VPCLMUL, "leaf 7 required for CRC32C VPCLMUL");
      Check (not Result.AVX512_VPCLMUL, "leaf 7 required for VPCLMUL");
   end;

   Check_Missing_Leaf_1 (SSSE3, True, False, False, "SSSE3");
   Check_Missing_Leaf_1 (SSE4_1, True, True, True, "SSE4.1");
   Check_Missing_Leaf_1 (SSE4_2, False, True, False, "SSE4.2");
   Check_Missing_Leaf_1 (PCLMULQDQ, True, True, True, "PCLMULQDQ");
   Check_Missing_Leaf_1 (XSAVE, False, False, True, "XSAVE");
   Check_Missing_Leaf_1 (OSXSAVE, False, False, True, "OSXSAVE");
   Check_Missing_Leaf_1 (AVX, False, False, True, "AVX");

   for Item in 0 .. 4 loop
      case Item is
         when 0 => Check_Missing_XCR0 (2 ** 1, "XMM");
         when 1 => Check_Missing_XCR0 (2 ** 2, "YMM");
         when 2 => Check_Missing_XCR0 (2 ** 5, "opmask");
         when 3 => Check_Missing_XCR0 (2 ** 6, "upper ZMM");
         when 4 => Check_Missing_XCR0 (2 ** 7, "high ZMM");
      end case;
   end loop;

   declare
      Value : Decode.Inputs := Complete;
   begin
      Value.XCR0_Was_Read := False;
      Check_No_AVX512 (Value, "XCR0 not read");
   end;

   declare
      Value : Decode.Inputs := Complete;
   begin
      Value.Leaf_7_EBX := Value.Leaf_7_EBX and not AVX512F;
      Check_No_AVX512 (Value, "missing AVX512F");
      Value := Complete;
      Value.Leaf_7_EBX := Value.Leaf_7_EBX and not AVX512VL;
      Check_No_AVX512 (Value, "missing AVX512VL");
      Value := Complete;
      Value.Leaf_7_EBX := Value.Leaf_7_EBX and not AVX512BW;
      Result := Decode.Decode (Value);
      Check (Result.AVX512_Ternary, "AVX512BW is not required for ternary tier");
      Check (Result.CRC32C_VPCLMUL, "AVX512BW is not required for CRC32C VPCLMUL");
      Check (not Result.AVX512_VPCLMUL, "AVX512BW required for VPCLMUL tier");
      Value := Complete;
      Value.Leaf_7_ECX := Value.Leaf_7_ECX and not VPCLMULQDQ;
      Result := Decode.Decode (Value);
      Check (Result.AVX512_Ternary, "VPCLMULQDQ is not required for ternary tier");
      Check (not Result.CRC32C_VPCLMUL, "VPCLMULQDQ required for CRC32C VP tier");
      Check (not Result.AVX512_VPCLMUL, "VPCLMULQDQ required for VP tier");
   end;

   for Bit of XGETBV_Prerequisites loop
      Check
        (not Decode.XCR0_May_Be_Read
               (7, Complete.Leaf_1_ECX and not Bit),
         "XGETBV forbidden when a prerequisite is absent");
   end loop;

   Check
     (not X86_Features.CRC32C_VPCLMUL_Available
      or else X86_Features.CRC32C_SSE_Available,
      "live CRC32C VPCLMUL capability implies live CRC32C SSE capability");
   Check
     (not X86_Features.AVX512_VPCLMUL_Available
      or else X86_Features.AVX512_Ternary_Available,
      "live VPCLMUL capability implies live ternary capability");
   Check
     (not X86_Features.AVX512_Ternary_Available
      or else X86_Features.Generic_SSE_Available,
      "live AVX-512 ternary capability implies live generic SSE capability");

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " x86 feature decode tests failed";
   end if;
   Ada.Text_IO.Put_Line ("All x86 feature decode tests passed");
end Flyology_CRC.X86_Feature_Decode_Tests;
