with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Text_IO;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Generic_SSE;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Flyology_CRC.X86_Features;

package body Flyology_CRC.Generic_AVX512_Ternary.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   package Core_16 is new
     Generic_Core (Value => Interfaces.Unsigned_16, Width => 16);
   package Core_32 is new
     Generic_Core (Value => Interfaces.Unsigned_32, Width => 32);
   package Core_64 is new
     Generic_Core (Value => Interfaces.Unsigned_64, Width => 64);

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   type Length_List is array (Positive range <>) of Positive;

   --  Reference-test fixtures cover one, two, three, and eight complete
   --  crc-fast stripes.  They do not select production dispatch policy.
   Lengths         : constant Length_List := (128, 256, 384, 1_024);
   Alignment_Count : constant Natural := 16;
   First_Index     : constant Offset := 37;
   Storage : Byte_Array
     (First_Index ..
        First_Index + Offset (Lengths (Lengths'Last) + Alignment_Count - 1));

   --  Test-only authority for a hardware runner whose CPUID/XCR0 exposure is
   --  deliberately suppressed.  Production dispatch never reads this value.
   Force_Direct : constant Boolean :=
     Ada.Environment_Variables.Exists
       ("FLYOLOGY_CRC_FORCE_GENERIC_AVX512_TERNARY_TEST")
     and then
       Ada.Environment_Variables.Value
         ("FLYOLOGY_CRC_FORCE_GENERIC_AVX512_TERNARY_TEST") = "1";

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Check_16
     (Configuration : Core_16.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length of Lengths loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
            begin
               Check
                 (Update_16
                    (Configuration.Working_Initial,
                     Configuration.Reflected,
                     Configuration.Keys,
                     Data) =
                    Generic_SSE.Update_16
                      (Configuration.Working_Initial,
                       Configuration.Reflected,
                       Configuration.Keys,
                       Data),
                  Label & " length" & Positive'Image (Length) &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;
   end Check_16;

   procedure Check_32
     (Configuration : Core_32.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length of Lengths loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
            begin
               Check
                 (Update_32
                    (Configuration.Working_Initial,
                     Configuration.Reflected,
                     Configuration.Keys,
                     Data) =
                    Generic_SSE.Update_32
                      (Configuration.Working_Initial,
                       Configuration.Reflected,
                       Configuration.Keys,
                       Data),
                  Label & " length" & Positive'Image (Length) &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;
   end Check_32;

   procedure Check_64
     (Configuration : Core_64.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length of Lengths loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
            begin
               Check
                 (Update_64
                    (Configuration.Working_Initial,
                     Configuration.Reflected,
                     Configuration.Keys,
                     Data) =
                    Generic_SSE.Update_64
                      (Configuration.Working_Initial,
                       Configuration.Reflected,
                       Configuration.Keys,
                       Data),
                  Label & " length" & Positive'Image (Length) &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;
   end Check_64;

   procedure Check_Catalogue is
   begin
      for Kind in Width_16.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_16 :=
              Generated_Catalogue.Lookup (Kind);
         begin
            Check_16
              (Core_16.Create
                 (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                  Item.Final_XOR, Item.Keys),
               "CRC-16/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_32.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_32 :=
              Generated_Catalogue.Lookup (Kind);
         begin
            Check_32
              (Core_32.Create
                 (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                  Item.Final_XOR, Item.Keys),
               "CRC-32/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_64.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_64 :=
              Generated_Catalogue.Lookup (Kind);
         begin
            Check_64
              (Core_64.Create
                 (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                  Item.Final_XOR, Item.Keys),
               "CRC-64/" & Kind'Image);
         end;
      end loop;
   end Check_Catalogue;

   procedure Check_Custom is
   begin
      Check_16
        (Core_16.Create
           (16#1021#, 16#1234#, False, 16#BEEF#,
            Generate_Folding_Keys (16, 16#1021#, False)),
         "custom forward CRC-16");
      Check_16
        (Core_16.Create
           (16#8005#, 16#1357#, True, 16#A6C3#,
            Generate_Folding_Keys (16, 16#8005#, True)),
         "custom reflected CRC-16");
      Check_32
        (Core_32.Create
           (16#04C1_1DB7#, 16#1234_5678#, False, 16#A5C3_9E71#,
            Generate_Folding_Keys (32, 16#04C1_1DB7#, False)),
         "custom forward CRC-32");
      Check_32
        (Core_32.Create
           (16#1EDC_6F41#, 16#1357_9BDF#, True, 16#C3A5_9687#,
            Generate_Folding_Keys (32, 16#1EDC_6F41#, True)),
         "custom reflected CRC-32");
      Check_64
        (Core_64.Create
           (16#42F0_E1EB_A9EA_3693#, 16#0123_4567_89AB_CDEF#, False,
            16#FEDC_BA98_7654_3210#,
            Generate_Folding_Keys
              (64, 16#42F0_E1EB_A9EA_3693#, False)),
         "custom forward CRC-64");
      Check_64
        (Core_64.Create
           (16#AD93_D235_94C9_3659#, 16#1357_9BDF_2468_ACE0#, True,
            16#C3A5_9687_7869_5A3C#,
            Generate_Folding_Keys
              (64, 16#AD93_D235_94C9_3659#, True)),
         "custom reflected CRC-64");
   end Check_Custom;

   procedure Check_Stubs is
      Dummy     : Byte_Array (1 .. 128) := (others => 0);
      Raised    : Boolean := False;
      Keys_16   : constant Folding_Keys :=
        Generate_Folding_Keys (16, 16#1021#, False);
      Keys_32   : constant Folding_Keys :=
        Generate_Folding_Keys (32, 16#04C1_1DB7#, False);
      Keys_64   : constant Folding_Keys :=
        Generate_Folding_Keys (64, 16#42F0_E1EB_A9EA_3693#, False);
   begin
      begin
         declare
            Ignored : constant Interfaces.Unsigned_16 :=
              Update_16 (0, False, Keys_16, Dummy);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "CRC-16 scalar/AArch64 AVX-512 stub fails closed");

      Raised := False;
      begin
         declare
            Ignored : constant Interfaces.Unsigned_32 :=
              Update_32 (0, False, Keys_32, Dummy);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "CRC-32 scalar/AArch64 AVX-512 stub fails closed");

      Raised := False;
      begin
         declare
            Ignored : constant Interfaces.Unsigned_64 :=
              Update_64 (0, False, Keys_64, Dummy);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "CRC-64 scalar/AArch64 AVX-512 stub fails closed");
   end Check_Stubs;

   procedure Run is
      Tier_Available : constant Boolean :=
        X86_Features.Generic_SSE_Available
        and then X86_Features.AVX512_Ternary_Available;
   begin
      for Index in Storage'Range loop
         Storage (Index) :=
           Byte
             ((Natural (Index) * 157 + Natural (Index) / 11 + 16#71#) mod 256);
      end loop;

      if not Compiled then
         Check
           (not X86_Features.AVX512_Ternary_Available,
            "uncompiled generic AVX-512 leaf must not be runtime available");
         Check_Stubs;
      elsif not Tier_Available and then not Force_Direct then
         Ada.Text_IO.Put_Line
           ("Generic x86 AVX-512 ternary direct tests skipped: tier unavailable");
         return;
      else
         Check (Generic_SSE.Compiled,
                "generic AVX-512 reference SSE leaf must be compiled");
         Check_Catalogue;
         Check_Custom;
      end if;

      if Failures /= 0 then
         raise Program_Error with
           Failures'Image & " generic x86 AVX-512 ternary tests failed";
      end if;

      if Compiled and then (Tier_Available or else Force_Direct) then
         Ada.Text_IO.Put_Line
           ("Generic x86 AVX-512 ternary matches SSE for all catalogue and custom cases");
      else
         Ada.Text_IO.Put_Line ("Generic x86 AVX-512 ternary stubs fail closed");
      end if;
   end Run;
end Flyology_CRC.Generic_AVX512_Ternary.Tests;
