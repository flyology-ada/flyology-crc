with Ada.Streams;
with Ada.Text_IO;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Generic_SSE;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Flyology_CRC.X86_Features;

package body Flyology_CRC.Generic_AVX512_VPCLMUL.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   Test_Data : Byte_Array (0 .. 8_319);
   for Test_Data'Alignment use 64;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Check_16
     (State : U16; Reflected : Boolean; Keys : Folding_Keys;
      Length, Alignment : Natural; Label : String) is
      First : constant Offset := 64 + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
   begin
      Check
        (Update_16 (State, Reflected, Keys, Data) =
           Generic_SSE.Update_16 (State, Reflected, Keys, Data),
         Label & " length" & Length'Image & " alignment" & Alignment'Image &
         " state" & U16'Image (State));
   end Check_16;

   procedure Check_32
     (State : U32; Reflected : Boolean; Keys : Folding_Keys;
      Length, Alignment : Natural; Label : String) is
      First : constant Offset := 64 + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
   begin
      Check
        (Update_32 (State, Reflected, Keys, Data) =
           Generic_SSE.Update_32 (State, Reflected, Keys, Data),
         Label & " length" & Length'Image & " alignment" & Alignment'Image &
         " state" & U32'Image (State));
   end Check_32;

   procedure Check_64
     (State : U64; Reflected : Boolean; Keys : Folding_Keys;
      Length, Alignment : Natural; Label : String) is
      First : constant Offset := 64 + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
   begin
      Check
        (Update_64 (State, Reflected, Keys, Data) =
           Generic_SSE.Update_64 (State, Reflected, Keys, Data),
         Label & " length" & Length'Image & " alignment" & Alignment'Image &
         " state" & U64'Image (State));
   end Check_64;

   procedure Check_All_Catalogue is
      type Length_List is array (Positive range <>) of Natural;
      Lengths : constant Length_List := (256, 384, 512, 640, 768, 1_024, 4_096);
   begin
      for Kind in Width_16.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_16 := Generated_Catalogue.Lookup (Kind);
         begin
            for Length of Lengths loop
               for Alignment in 0 .. 63 loop
                  Check_16 (0, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-16/" & Kind'Image);
                  Check_16 (16#A5C3#, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-16/" & Kind'Image);
               end loop;
            end loop;
         end;
      end loop;

      for Kind in Width_32.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_32 := Generated_Catalogue.Lookup (Kind);
         begin
            for Length of Lengths loop
               for Alignment in 0 .. 63 loop
                  Check_32 (0, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-32/" & Kind'Image);
                  Check_32 (16#A5C3_6987#, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-32/" & Kind'Image);
               end loop;
            end loop;
         end;
      end loop;

      for Kind in Width_64.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_64 := Generated_Catalogue.Lookup (Kind);
         begin
            for Length of Lengths loop
               for Alignment in 0 .. 63 loop
                  Check_64 (0, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-64/" & Kind'Image);
                  Check_64 (16#A5C_3698_7F1E_2D4B#, Item.Reflected, Item.Keys, Length, Alignment,
                            "CRC-64/" & Kind'Image);
               end loop;
            end loop;
         end;
      end loop;
   end Check_All_Catalogue;

   procedure Check_Custom_And_Chaining is
      Keys_16_F : constant Folding_Keys := Generate_Folding_Keys (16, 16#8BB7#, False);
      Keys_16_R : constant Folding_Keys := Generate_Folding_Keys (16, 16#1021#, True);
      Keys_32_F : constant Folding_Keys := Generate_Folding_Keys (32, 16#8141_41AB#, False);
      Keys_32_R : constant Folding_Keys := Generate_Folding_Keys (32, 16#04C1_1DB7#, True);
      Keys_64_F : constant Folding_Keys :=
        Generate_Folding_Keys (64, 16#42F0_E1EB_A9EA_3693#, False);
      Keys_64_R : constant Folding_Keys :=
        Generate_Folding_Keys (64, 16#AD93_D235_94C9_3659#, True);
      type Length_List is array (Positive range <>) of Natural;
      Lengths : constant Length_List := (256, 384, 512, 640, 768, 896, 1_024, 4_096, 8_192);
   begin
      for Length of Lengths loop
         for Alignment in 0 .. 63 loop
            Check_16 (16#1357#, False, Keys_16_F, Length, Alignment, "custom CRC-16 forward");
            Check_16 (16#2468#, True, Keys_16_R, Length, Alignment, "custom CRC-16 reflected");
            Check_32 (16#1357_9BDF#, False, Keys_32_F, Length, Alignment, "custom CRC-32 forward");
            Check_32 (16#2468_ACE0#, True, Keys_32_R, Length, Alignment, "custom CRC-32 reflected");
            Check_64
              (16#1357_9BDF_2468_ACE0#, False, Keys_64_F, Length, Alignment,
               "custom CRC-64 forward");
            Check_64
              (16#FEDC_BA98_7654_3210#, True, Keys_64_R, Length, Alignment,
               "custom CRC-64 reflected");
         end loop;
      end loop;

      --  Both halves meet the leaf's 256-byte minimum, so these equations
      --  exercise raw-state continuation without involving public dispatch.
      declare
         First : constant Offset := 77;
         Whole : Byte_Array renames Test_Data (First .. First + 767);
         Left  : Byte_Array renames Test_Data (First .. First + 255);
         Right : Byte_Array renames Test_Data (First + 256 .. First + 767);
      begin
         Check
           (Update_16 (Update_16 (16#1357#, False, Keys_16_F, Left), False, Keys_16_F, Right) =
              Update_16 (16#1357#, False, Keys_16_F, Whole),
            "custom CRC-16 forward chaining");
         Check
           (Update_32 (Update_32 (16#2468_ACE0#, True, Keys_32_R, Left), True, Keys_32_R, Right) =
              Update_32 (16#2468_ACE0#, True, Keys_32_R, Whole),
            "custom CRC-32 reflected chaining");
         Check
           (Update_64
              (Update_64 (16#FEDC_BA98_7654_3210#, True, Keys_64_R, Left),
               True, Keys_64_R, Right) =
              Update_64 (16#FEDC_BA98_7654_3210#, True, Keys_64_R, Whole),
            "custom CRC-64 reflected chaining");
      end;
   end Check_Custom_And_Chaining;

   procedure Check_Stub is
      Data : Byte_Array renames Test_Data (65 .. 320);
      Keys : constant Folding_Keys := Generate_Folding_Keys (32, 16#04C1_1DB7#, True);
      Raised : Boolean := False;
   begin
      begin
         declare
            Ignored : constant U32 := Update_32 (0, True, Keys, Data);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error => Raised := True;
      end;
      Check (Raised, "non-x86 generic VPCLMUL call fails closed");
   end Check_Stub;

   procedure Run is
   begin
      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte ((Natural (Index) * 181 + Natural (Index) / 17 + 16#5B#) mod 256);
      end loop;

      if not Compiled then
         Check (not X86_Features.AVX512_VPCLMUL_Available,
                "non-x86 generic VPCLMUL feature is false");
         Check_Stub;
      elsif not X86_Features.AVX512_VPCLMUL_Available then
         Ada.Text_IO.Put_Line ("generic x86 AVX-512 VPCLMUL direct tests skipped: tier unavailable");
      else
         Check (Generic_SSE.Compiled, "generic SSE oracle leaf is compiled");
         Check_All_Catalogue;
         Check_Custom_And_Chaining;
      end if;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " generic VPCLMUL tests failed";
      end if;
      if Compiled and then X86_Features.AVX512_VPCLMUL_Available then
         Ada.Text_IO.Put_Line
           ("generic x86 AVX-512 VPCLMUL matches SSE for catalogue, custom, alignment, and chaining cases");
      elsif not Compiled then
         Ada.Text_IO.Put_Line ("generic x86 AVX-512 VPCLMUL non-x86 stub fails closed as required");
      end if;
   end Run;
end Flyology_CRC.Generic_AVX512_VPCLMUL.Tests;
