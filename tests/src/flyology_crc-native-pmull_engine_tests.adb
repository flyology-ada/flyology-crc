with Ada.Streams;
with Ada.Text_IO;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Native.Generic_PMULL;
with Flyology_CRC.Native_EOR3;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Interfaces;

package body Flyology_CRC.Native.PMULL_Engine_Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   package PMULL_16 is new
     Generic_PMULL.Engine (Value => Interfaces.Unsigned_16, Width => 16);
   package PMULL_32 is new
     Generic_PMULL.Engine (Value => Interfaces.Unsigned_32, Width => 32);
   package PMULL_64 is new
     Generic_PMULL.Engine (Value => Interfaces.Unsigned_64, Width => 64);

   type Length_List is array (Positive range <>) of Positive;

   --  These are reference-test sizes required for the fold-by-eight engine:
   --  one stripe, two stripes, eight stripes, and a representative large
   --  buffer.  They are fixtures, not production dispatch thresholds.
   Lengths : constant Length_List := (128, 256, 1_024, 1_048_576);
   Test_Data : Byte_Array (1 .. Ada.Streams.Stream_Element_Offset (Lengths (Lengths'Last)));

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Reverse_16 (Item : Interfaces.Unsigned_16) return Interfaces.Unsigned_16 is
      Source : Interfaces.Unsigned_16 := Item;
      Result : Interfaces.Unsigned_16 := 0;
   begin
      for Bit in 1 .. 16 loop
         Result := Interfaces.Shift_Left (Result, 1) or (Source and 1);
         Source := Interfaces.Shift_Right (Source, 1);
      end loop;
      return Result;
   end Reverse_16;

   function Raw_Initial
     (Item : Generated_Catalogue.Parameters_16) return Interfaces.Unsigned_16 is
   begin
      return
        (if Item.Reflected then Reverse_16 (Item.Initial_Value)
         else Item.Initial_Value);
   end Raw_Initial;

   procedure Check_16
     (Configuration : Width_16.Parameters;
      Initial       : Interfaces.Unsigned_16;
      Reflected     : Boolean;
      Final_XOR     : Interfaces.Unsigned_16;
      Keys          : Folding_Keys;
      Label         : String) is
   begin
      for Length of Lengths loop
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Test_Data'First + Ada.Streams.Stream_Element_Offset (Length) - 1;
            Data : Byte_Array renames Test_Data (Test_Data'First .. Last);
            Actual : constant Interfaces.Unsigned_16 :=
              PMULL_16.Update_Aligned_Blocks
                (Initial, Reflected, Keys, Data) xor Final_XOR;
         begin
            Check
              (Actual = Width_16.Compute (Configuration, Data),
               Label & " length" & Positive'Image (Length));
            if Native_Features.SHA3_Available then
               Check
                 ((Native_EOR3.Update_PMULL_16
                      (Initial, Reflected, Keys, Data)
                    xor Final_XOR) = Actual,
                  Label & " EOR3 length" & Positive'Image (Length));
            end if;
         end;
      end loop;
   end Check_16;

   procedure Check_32
     (Configuration : Width_32.Parameters;
      Initial       : Interfaces.Unsigned_32;
      Reflected     : Boolean;
      Final_XOR     : Interfaces.Unsigned_32;
      Keys          : Folding_Keys;
      Label         : String) is
   begin
      for Length of Lengths loop
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Test_Data'First + Ada.Streams.Stream_Element_Offset (Length) - 1;
            Data : Byte_Array renames Test_Data (Test_Data'First .. Last);
            Actual : constant Interfaces.Unsigned_32 :=
              PMULL_32.Update_Aligned_Blocks
                (Initial, Reflected, Keys, Data) xor Final_XOR;
         begin
            Check
              (Actual = Width_32.Compute (Configuration, Data),
               Label & " length" & Positive'Image (Length));
            if Native_Features.SHA3_Available then
               Check
                 ((Native_EOR3.Update_PMULL_32
                      (Initial, Reflected, Keys, Data)
                    xor Final_XOR) = Actual,
                  Label & " EOR3 length" & Positive'Image (Length));
            end if;
         end;
      end loop;
   end Check_32;

   procedure Check_64
     (Configuration : Width_64.Parameters;
      Initial       : Interfaces.Unsigned_64;
      Reflected     : Boolean;
      Final_XOR     : Interfaces.Unsigned_64;
      Keys          : Folding_Keys;
      Label         : String) is
   begin
      for Length of Lengths loop
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Test_Data'First + Ada.Streams.Stream_Element_Offset (Length) - 1;
            Data : Byte_Array renames Test_Data (Test_Data'First .. Last);
            Actual : constant Interfaces.Unsigned_64 :=
              PMULL_64.Update_Aligned_Blocks
                (Initial, Reflected, Keys, Data) xor Final_XOR;
         begin
            Check
              (Actual = Width_64.Compute (Configuration, Data),
               Label & " length" & Positive'Image (Length));
            if Reflected and then Length = 1_024 then
               declare
                  Exact : constant Interfaces.Unsigned_64 :=
                    Update_PMULL_64_1024_Reflected
                      (Initial, Keys, Data (Data'First)'Address) xor Final_XOR;
                  Unaligned_First : constant Ada.Streams.Stream_Element_Offset :=
                    Data'First + 1;
                  Unaligned_Last : constant Ada.Streams.Stream_Element_Offset :=
                    Unaligned_First + 1_023;
                  Unaligned_Exact : constant Interfaces.Unsigned_64 :=
                    Update_PMULL_64_1024_Reflected
                      (Initial, Keys, Test_Data (Unaligned_First)'Address)
                    xor Final_XOR;
                  Second_First : constant Ada.Streams.Stream_Element_Offset :=
                    Data'Last + 1;
                  Second_Last : constant Ada.Streams.Stream_Element_Offset :=
                    Second_First + 1_023;
                  Chained_State : Interfaces.Unsigned_64 :=
                    Update_PMULL_64_1024_Reflected
                      (Initial, Keys, Data (Data'First)'Address);
               begin
                  Check
                    (Exact = Actual,
                     Label & " exact reflected CRC-64 length 1024");
                  Check
                    (Unaligned_Exact =
                       Width_64.Compute
                         (Configuration,
                          Test_Data (Unaligned_First .. Unaligned_Last)),
                     Label & " exact reflected CRC-64 unaligned length 1024");
                  Chained_State :=
                    Update_PMULL_64_1024_Reflected
                      (Chained_State, Keys, Test_Data (Second_First)'Address);
                  Check
                    ((Chained_State xor Final_XOR) =
                       Width_64.Compute
                         (Configuration,
                          Test_Data (Data'First .. Second_Last)),
                     Label & " exact reflected CRC-64 chained length 2048");
               end;
            end if;
            if Native_Features.SHA3_Available then
               Check
                 ((Native_EOR3.Update_PMULL_64
                      (Initial, Reflected, Keys, Data)
                    xor Final_XOR) = Actual,
                  Label & " EOR3 length" & Positive'Image (Length));
            end if;
         end;
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
              (Width_16.Parameters_For (Kind), Raw_Initial (Item),
               Item.Reflected, Item.Final_XOR, Item.Keys,
               "CRC-16/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_32.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_32 :=
              Generated_Catalogue.Lookup (Kind);
         begin
            Check_32
              (Width_32.Parameters_For (Kind), Item.Initial_Value,
               Item.Reflected, Item.Final_XOR, Item.Keys,
               "CRC-32/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_64.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_64 :=
              Generated_Catalogue.Lookup (Kind);
         begin
            Check_64
              (Width_64.Parameters_For (Kind), Item.Initial_Value,
               Item.Reflected, Item.Final_XOR, Item.Keys,
               "CRC-64/" & Kind'Image);
         end;
      end loop;
   end Check_Catalogue;

   procedure Check_Custom is
      procedure Custom_16
        (Polynomial, Initial, Final_XOR : Interfaces.Unsigned_16;
         Reflected                     : Boolean;
         Label                         : String) is
         Configuration : constant Width_16.Parameters :=
           Width_16.Create (Polynomial, Initial, Reflected, Final_XOR);
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (16, Interfaces.Unsigned_64 (Polynomial), Reflected);
         Working : constant Interfaces.Unsigned_16 :=
           (if Reflected then Reverse_16 (Initial) else Initial);
      begin
         Check_16
           (Configuration, Working, Reflected, Final_XOR, Keys, Label);
      end Custom_16;

      procedure Custom_32
        (Polynomial, Initial, Final_XOR : Interfaces.Unsigned_32;
         Reflected                     : Boolean;
         Label                         : String) is
         Configuration : constant Width_32.Parameters :=
           Width_32.Create (Polynomial, Initial, Reflected, Final_XOR);
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (32, Interfaces.Unsigned_64 (Polynomial), Reflected);
      begin
         Check_32
           (Configuration, Initial, Reflected, Final_XOR, Keys, Label);
      end Custom_32;

      procedure Custom_64
        (Polynomial, Initial, Final_XOR : Interfaces.Unsigned_64;
         Reflected                     : Boolean;
         Label                         : String) is
         Configuration : constant Width_64.Parameters :=
           Width_64.Create (Polynomial, Initial, Reflected, Final_XOR);
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (64, Polynomial, Reflected);
      begin
         Check_64
           (Configuration, Initial, Reflected, Final_XOR, Keys, Label);
      end Custom_64;
   begin
      Custom_16 (16#1021#, 16#1234#, 16#BEEF#, False, "custom forward CRC-16");
      Custom_16 (16#8005#, 16#1357#, 16#A6C3#, True, "custom reflected CRC-16");
      Custom_32
        (16#04C11DB7#, 16#12345678#, 16#A5C39E71#, False,
         "custom forward CRC-32");
      Custom_32
        (16#1EDC6F41#, 16#13579BDF#, 16#C3A59687#, True,
         "custom reflected CRC-32");
      Custom_64
        (16#42F0E1EBA9EA3693#, 16#0123456789ABCDEF#,
         16#FEDCBA9876543210#, False, "custom forward CRC-64");
      Custom_64
        (16#AD93D23594C93659#, 16#13579BDF2468ACE0#,
         16#C3A5968778695A3C#, True, "custom reflected CRC-64");
   end Check_Custom;

   procedure Run is
   begin
      if not Compiled or else not Native_Features.PMULL_Available then
         Ada.Text_IO.Put_Line ("PMULL engine tests skipped: PMULL is unavailable");
         return;
      end if;

      Check
        (not Native_Features.SHA3_Available or else Native_EOR3.Compiled,
         "SHA3 availability requires the EOR3 leaf to be compiled");

      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte
             ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
      end loop;

      Check_Catalogue;
      Check_Custom;
      if Failures /= 0 then
         raise Program_Error with Failures'Image & " PMULL engine tests failed";
      end if;
      if Native_Features.SHA3_Available then
         Ada.Text_IO.Put_Line
           ("PMULL and EOR3 engines match for all catalogue and custom cases");
      else
         Ada.Text_IO.Put_Line
           ("PMULL engine matches the scalar core for all catalogue and custom cases");
      end if;
   end Run;
end Flyology_CRC.Native.PMULL_Engine_Tests;
