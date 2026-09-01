with Ada.Text_IO;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_16.Folding_Key_Test_Access;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_32.Folding_Key_Test_Access;
with Flyology_CRC.Width_64;
with Flyology_CRC.Width_64.Folding_Key_Test_Access;
with Interfaces.C;
with System;

package body Flyology_CRC.Folding_Key_Tests is
   package C renames Interfaces.C;
   use type C.unsigned;
   use type Interfaces.Unsigned_64;

   pragma Compile_Time_Error (C.unsigned'Size /= 32, "Rust u32 requires a 32-bit C unsigned");
   pragma Compile_Time_Error
     (C.unsigned_long_long'Size /= 64, "Rust u64 requires a 64-bit C unsigned long long");
   pragma Compile_Time_Error
     (C.size_t'Size /= System.Address'Size, "Rust usize and Ada address sizes must match");

   function Imported_Folding_Keys
     (Width         : C.unsigned;
      Polynomial    : C.unsigned_long_long;
      Reflected     : C.unsigned;
      Output        : System.Address;
      Output_Length : C.size_t) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_folding_keys";

   type Oracle_Keys is array (Folding_Key_Index) of aliased C.unsigned_long_long;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Check_One
     (Width      : Positive;
      Polynomial : Interfaces.Unsigned_64;
      Reflected  : Boolean;
      Expected   : Folding_Keys;
      Label      : String) is
      Oracle : aliased Oracle_Keys := (others => 0);
      Status : C.unsigned;
   begin
      Status :=
        Imported_Folding_Keys
          (C.unsigned (Width),
           C.unsigned_long_long (Polynomial),
           C.unsigned (Boolean'Pos (Reflected)),
           Oracle'Address,
           C.size_t (Oracle'Length));
      Check (Status = 0, Label & " Rust oracle status" & C.unsigned'Image (Status));
      if Status = 0 then
         for Index in Folding_Key_Index loop
            Check
              (Interfaces.Unsigned_64 (Oracle (Index)) = Expected (Index),
               Label & " key" & Folding_Key_Index'Image (Index));
         end loop;
      end if;
   end Check_One;

   procedure Check_Stored_16
     (Configuration : Width_16.Parameters;
      Expected      : Folding_Keys;
      Label         : String) is
   begin
      for Index in Folding_Key_Index loop
         Check
           (Width_16.Folding_Key_Test_Access.Key_At (Configuration, Index) = Expected (Index),
            Label & " stored key" & Folding_Key_Index'Image (Index));
      end loop;
   end Check_Stored_16;

   procedure Check_Stored_32
     (Configuration : Width_32.Parameters;
      Expected      : Folding_Keys;
      Label         : String) is
   begin
      for Index in Folding_Key_Index loop
         Check
           (Width_32.Folding_Key_Test_Access.Key_At (Configuration, Index) = Expected (Index),
            Label & " stored key" & Folding_Key_Index'Image (Index));
      end loop;
   end Check_Stored_32;

   procedure Check_Stored_64
     (Configuration : Width_64.Parameters;
      Expected      : Folding_Keys;
      Label         : String) is
   begin
      for Index in Folding_Key_Index loop
         Check
           (Width_64.Folding_Key_Test_Access.Key_At (Configuration, Index) = Expected (Index),
            Label & " stored key" & Folding_Key_Index'Image (Index));
      end loop;
   end Check_Stored_64;

   procedure Check_Catalogue is
   begin
      for Kind in Width_16.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_16 := Generated_Catalogue.Lookup (Kind);
            Dynamic : constant Folding_Keys :=
              Generate_Folding_Keys (16, Interfaces.Unsigned_64 (Item.Polynomial), Item.Reflected);
         begin
            Check (Item.Keys = Dynamic, "CRC-16/" & Kind'Image & " generated catalogue drift");
            Check_Stored_16
              (Width_16.Parameters_For (Kind), Item.Keys,
               "CRC-16/" & Kind'Image & " predefined parameters");
            Check_One
              (16, Interfaces.Unsigned_64 (Item.Polynomial), Item.Reflected, Item.Keys,
               "CRC-16/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_32.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_32 := Generated_Catalogue.Lookup (Kind);
            Dynamic : constant Folding_Keys :=
              Generate_Folding_Keys (32, Interfaces.Unsigned_64 (Item.Polynomial), Item.Reflected);
         begin
            Check (Item.Keys = Dynamic, "CRC-32/" & Kind'Image & " generated catalogue drift");
            Check_Stored_32
              (Width_32.Parameters_For (Kind), Item.Keys,
               "CRC-32/" & Kind'Image & " predefined parameters");
            Check_One
              (32, Interfaces.Unsigned_64 (Item.Polynomial), Item.Reflected, Item.Keys,
               "CRC-32/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_64.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_64 := Generated_Catalogue.Lookup (Kind);
            Dynamic : constant Folding_Keys :=
              Generate_Folding_Keys (64, Item.Polynomial, Item.Reflected);
         begin
            Check (Item.Keys = Dynamic, "CRC-64/" & Kind'Image & " generated catalogue drift");
            Check_Stored_64
              (Width_64.Parameters_For (Kind), Item.Keys,
               "CRC-64/" & Kind'Image & " predefined parameters");
            Check_One (64, Item.Polynomial, Item.Reflected, Item.Keys, "CRC-64/" & Kind'Image);
         end;
      end loop;
   end Check_Catalogue;

   procedure Check_Custom is
      procedure Check_Dynamic
        (Width      : Positive;
         Polynomial : Interfaces.Unsigned_64;
         Reflected  : Boolean;
         Label      : String) is
         Keys : constant Folding_Keys := Generate_Folding_Keys (Width, Polynomial, Reflected);
      begin
         Check_One (Width, Polynomial, Reflected, Keys, Label);
      end Check_Dynamic;
   begin
      Check_Dynamic (16, 16#8BB7#, False, "custom forward CRC-16");
      Check_Stored_16
        (Width_16.Create (16#8BB7#, 0, False, 0),
         Generate_Folding_Keys (16, 16#8BB7#, False),
         "custom forward CRC-16 Create");
      Check_Dynamic (16, 16#1021#, True, "custom reflected CRC-16");
      Check_Stored_16
        (Width_16.Create (16#1021#, 0, True, 0),
         Generate_Folding_Keys (16, 16#1021#, True),
         "custom reflected CRC-16 Create");
      Check_Dynamic (32, 16#814141AB#, False, "custom forward CRC-32");
      Check_Stored_32
        (Width_32.Create (16#814141AB#, 0, False, 0),
         Generate_Folding_Keys (32, 16#814141AB#, False),
         "custom forward CRC-32 Create");
      Check_Dynamic (32, 16#04C11DB7#, True, "custom reflected CRC-32");
      Check_Stored_32
        (Width_32.Create (16#04C11DB7#, 0, True, 0),
         Generate_Folding_Keys (32, 16#04C11DB7#, True),
         "custom reflected CRC-32 Create");
      Check_Dynamic (64, 16#42F0E1EBA9EA3693#, False, "custom forward CRC-64");
      Check_Stored_64
        (Width_64.Create (16#42F0E1EBA9EA3693#, 0, False, 0),
         Generate_Folding_Keys (64, 16#42F0E1EBA9EA3693#, False),
         "custom forward CRC-64 Create");
      Check_Dynamic (64, 16#AD93D23594C93659#, True, "custom reflected CRC-64");
      Check_Stored_64
        (Width_64.Create (16#AD93D23594C93659#, 0, True, 0),
         Generate_Folding_Keys (64, 16#AD93D23594C93659#, True),
         "custom reflected CRC-64 Create");
   end Check_Custom;

   procedure Run is
   begin
      Check_Catalogue;
      Check_Custom;
      if Failures /= 0 then
         raise Program_Error with Failures'Image & " folding-key differential tests failed";
      end if;
      Ada.Text_IO.Put_Line ("All Flyology CRC folding keys match crc-fast");
   end Run;
end Flyology_CRC.Folding_Key_Tests;
