with Ada.Streams;
with Ada.Text_IO;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Flyology_CRC.X86_Features;

package body Flyology_CRC.Generic_SSE.Tests is
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
   type Split_List is array (Positive range <>) of Natural;

   Maximum_Length  : constant Natural := 1_025;
   Alignment_Count : constant Natural := 16;
   First_Index     : constant Offset := 37;
   Storage : Byte_Array
     (First_Index .. First_Index + Offset (Maximum_Length + Alignment_Count - 1));
   Chain_Splits : constant Split_List := (0, 1, 127, 128, 129, 256, 384, 385);

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Forced_16
     (Configuration : Core_16.Parameters;
      Data          : Byte_Array) return Interfaces.Unsigned_16 is
      State : Interfaces.Unsigned_16 := Configuration.Working_Initial;
   begin
      if Data'Length >= 128 then
         declare
            Prefix_Length : constant Offset := Offset (Data'Length - Data'Length mod 128);
            Prefix_Last   : constant Offset := Data'First + Prefix_Length - 1;
         begin
            State :=
              Update_16
                (State, Configuration.Reflected, Configuration.Keys,
                 Data (Data'First .. Prefix_Last));
            if Prefix_Last < Data'Last then
               Core_16.Update_State
                 (State, Configuration, Data (Prefix_Last + 1 .. Data'Last));
            end if;
         end;
      else
         Core_16.Update_State (State, Configuration, Data);
      end if;
      return State xor Configuration.Final_XOR;
   end Forced_16;

   function Forced_32
     (Configuration : Core_32.Parameters;
      Data          : Byte_Array) return Interfaces.Unsigned_32 is
      State : Interfaces.Unsigned_32 := Configuration.Working_Initial;
   begin
      if Data'Length >= 128 then
         declare
            Prefix_Length : constant Offset := Offset (Data'Length - Data'Length mod 128);
            Prefix_Last   : constant Offset := Data'First + Prefix_Length - 1;
         begin
            State :=
              Update_32
                (State, Configuration.Reflected, Configuration.Keys,
                 Data (Data'First .. Prefix_Last));
            if Prefix_Last < Data'Last then
               Core_32.Update_State
                 (State, Configuration, Data (Prefix_Last + 1 .. Data'Last));
            end if;
         end;
      else
         Core_32.Update_State (State, Configuration, Data);
      end if;
      return State xor Configuration.Final_XOR;
   end Forced_32;

   function Forced_64
     (Configuration : Core_64.Parameters;
      Data          : Byte_Array) return Interfaces.Unsigned_64 is
      State : Interfaces.Unsigned_64 := Configuration.Working_Initial;
   begin
      if Data'Length >= 128 then
         declare
            Prefix_Length : constant Offset := Offset (Data'Length - Data'Length mod 128);
            Prefix_Last   : constant Offset := Data'First + Prefix_Length - 1;
         begin
            State :=
              Update_64
                (State, Configuration.Reflected, Configuration.Keys,
                 Data (Data'First .. Prefix_Last));
            if Prefix_Last < Data'Last then
               Core_64.Update_State
                 (State, Configuration, Data (Prefix_Last + 1 .. Data'Last));
            end if;
         end;
      else
         Core_64.Update_State (State, Configuration, Data);
      end if;
      return State xor Configuration.Final_XOR;
   end Forced_64;

   procedure Check_16
     (Reference     : Core_16.Parameters;
      Public_Config : Width_16.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length in 0 .. 260 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_16 :=
                 Core_16.Compute (Reference, Data);
            begin
               Check
                 (Forced_16 (Reference, Data) = Expected,
                  Label & " forced length" & Length'Image &
                    " offset" & Alignment'Image);
               Check
                 (Width_16.Compute (Public_Config, Data) = Expected,
                  Label & " public length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;

         for Length in 1_023 .. 1_025 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_16 :=
                 Core_16.Compute (Reference, Data);
            begin
               Check
                 (Forced_16 (Reference, Data) = Expected,
                  Label & " forced large length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;

      declare
         First    : constant Offset := First_Index + 5;
         Last     : constant Offset := First + 384;
         Data     : Byte_Array renames Storage (First .. Last);
         Expected : constant Interfaces.Unsigned_16 := Core_16.Compute (Reference, Data);
      begin
         for Split of Chain_Splits loop
            declare
               Object : Width_16.Context := Width_16.Start (Public_Config);
               Cut    : constant Offset := First + Offset (Split);
            begin
               Width_16.Update (Object, Data (First .. Cut - 1));
               Width_16.Update (Object, Data (Cut .. Last));
               Check
                 (Width_16.Result (Object) = Expected,
                  Label & " chaining split" & Split'Image);
            end;
         end loop;
      end;
   end Check_16;

   procedure Check_32
     (Reference     : Core_32.Parameters;
      Public_Config : Width_32.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length in 0 .. 260 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_32 :=
                 Core_32.Compute (Reference, Data);
            begin
               Check
                 (Forced_32 (Reference, Data) = Expected,
                  Label & " forced length" & Length'Image &
                    " offset" & Alignment'Image);
               Check
                 (Width_32.Compute (Public_Config, Data) = Expected,
                  Label & " public length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;

         for Length in 1_023 .. 1_025 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_32 :=
                 Core_32.Compute (Reference, Data);
            begin
               Check
                 (Forced_32 (Reference, Data) = Expected,
                  Label & " forced large length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;

      declare
         First    : constant Offset := First_Index + 5;
         Last     : constant Offset := First + 384;
         Data     : Byte_Array renames Storage (First .. Last);
         Expected : constant Interfaces.Unsigned_32 := Core_32.Compute (Reference, Data);
      begin
         for Split of Chain_Splits loop
            declare
               Object : Width_32.Context := Width_32.Start (Public_Config);
               Cut    : constant Offset := First + Offset (Split);
            begin
               Width_32.Update (Object, Data (First .. Cut - 1));
               Width_32.Update (Object, Data (Cut .. Last));
               Check
                 (Width_32.Result (Object) = Expected,
                  Label & " chaining split" & Split'Image);
            end;
         end loop;
      end;
   end Check_32;

   procedure Check_64
     (Reference     : Core_64.Parameters;
      Public_Config : Width_64.Parameters;
      Label         : String) is
   begin
      for Alignment in 0 .. Alignment_Count - 1 loop
         for Length in 0 .. 260 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_64 :=
                 Core_64.Compute (Reference, Data);
            begin
               Check
                 (Forced_64 (Reference, Data) = Expected,
                  Label & " forced length" & Length'Image &
                    " offset" & Alignment'Image);
               Check
                 (Width_64.Compute (Public_Config, Data) = Expected,
                  Label & " public length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;

         for Length in 1_023 .. 1_025 loop
            declare
               First : constant Offset := First_Index + Offset (Alignment);
               Last  : constant Offset := First + Offset (Length) - 1;
               Data  : Byte_Array renames Storage (First .. Last);
               Expected : constant Interfaces.Unsigned_64 :=
                 Core_64.Compute (Reference, Data);
            begin
               Check
                 (Forced_64 (Reference, Data) = Expected,
                  Label & " forced large length" & Length'Image &
                    " offset" & Alignment'Image);
            end;
         end loop;
      end loop;

      declare
         First    : constant Offset := First_Index + 5;
         Last     : constant Offset := First + 384;
         Data     : Byte_Array renames Storage (First .. Last);
         Expected : constant Interfaces.Unsigned_64 := Core_64.Compute (Reference, Data);
      begin
         for Split of Chain_Splits loop
            declare
               Object : Width_64.Context := Width_64.Start (Public_Config);
               Cut    : constant Offset := First + Offset (Split);
            begin
               Width_64.Update (Object, Data (First .. Cut - 1));
               Width_64.Update (Object, Data (Cut .. Last));
               Check
                 (Width_64.Result (Object) = Expected,
                  Label & " chaining split" & Split'Image);
            end;
         end loop;
      end;
   end Check_64;

   procedure Check_Catalogue is
   begin
      for Kind in Width_16.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_16 :=
              Generated_Catalogue.Lookup (Kind);
            Reference : constant Core_16.Parameters :=
              Core_16.Create
                (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                 Item.Final_XOR, Item.Keys);
         begin
            Check_16
              (Reference, Width_16.Parameters_For (Kind),
               "CRC-16/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_32.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_32 :=
              Generated_Catalogue.Lookup (Kind);
            Reference : constant Core_32.Parameters :=
              Core_32.Create
                (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                 Item.Final_XOR, Item.Keys);
         begin
            Check_32
              (Reference, Width_32.Parameters_For (Kind),
               "CRC-32/" & Kind'Image);
         end;
      end loop;

      for Kind in Width_64.Algorithm loop
         declare
            Item : constant Generated_Catalogue.Parameters_64 :=
              Generated_Catalogue.Lookup (Kind);
            Reference : constant Core_64.Parameters :=
              Core_64.Create
                (Item.Polynomial, Item.Initial_Value, Item.Reflected,
                 Item.Final_XOR, Item.Keys);
         begin
            Check_64
              (Reference, Width_64.Parameters_For (Kind),
               "CRC-64/" & Kind'Image);
         end;
      end loop;
   end Check_Catalogue;

   procedure Check_Custom is
      procedure Custom_16
        (Polynomial, Initial_Value, Final_XOR : Interfaces.Unsigned_16;
         Reflected                           : Boolean;
         Label                               : String) is
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (16, Interfaces.Unsigned_64 (Polynomial), Reflected);
      begin
         Check_16
           (Core_16.Create
              (Polynomial, Initial_Value, Reflected, Final_XOR, Keys),
            Width_16.Create (Polynomial, Initial_Value, Reflected, Final_XOR),
            Label);
      end Custom_16;

      procedure Custom_32
        (Polynomial, Initial_Value, Final_XOR : Interfaces.Unsigned_32;
         Reflected                           : Boolean;
         Label                               : String) is
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (32, Interfaces.Unsigned_64 (Polynomial), Reflected);
      begin
         Check_32
           (Core_32.Create
              (Polynomial, Initial_Value, Reflected, Final_XOR, Keys),
            Width_32.Create (Polynomial, Initial_Value, Reflected, Final_XOR),
            Label);
      end Custom_32;

      procedure Custom_64
        (Polynomial, Initial_Value, Final_XOR : Interfaces.Unsigned_64;
         Reflected                           : Boolean;
         Label                               : String) is
         Keys : constant Folding_Keys :=
           Generate_Folding_Keys (64, Polynomial, Reflected);
      begin
         Check_64
           (Core_64.Create
              (Polynomial, Initial_Value, Reflected, Final_XOR, Keys),
            Width_64.Create (Polynomial, Initial_Value, Reflected, Final_XOR),
            Label);
      end Custom_64;
   begin
      Custom_16 (16#1021#, 16#1234#, 16#BEEF#, False, "custom forward CRC-16");
      Custom_16 (16#8005#, 16#1357#, 16#A6C3#, True, "custom reflected CRC-16");
      Custom_32
        (16#04C1_1DB7#, 16#1234_5678#, 16#A5C3_9E71#, False,
         "custom forward CRC-32");
      Custom_32
        (16#1EDC_6F41#, 16#1357_9BDF#, 16#C3A5_9687#, True,
         "custom reflected CRC-32");
      Custom_64
        (16#42F0_E1EB_A9EA_3693#, 16#0123_4567_89AB_CDEF#,
         16#FEDC_BA98_7654_3210#, False, "custom forward CRC-64");
      Custom_64
        (16#AD93_D235_94C9_3659#, 16#1357_9BDF_2468_ACE0#,
         16#C3A5_9687_7869_5A3C#, True, "custom reflected CRC-64");
   end Check_Custom;

   procedure Check_Stubs is
      Dummy : Byte_Array (1 .. 128) := (others => 0);
      Raised : Boolean := False;
      Result_16 : Interfaces.Unsigned_16 := 0;
      Result_32 : Interfaces.Unsigned_32 := 0;
      Result_64 : Interfaces.Unsigned_64 := 0;
      pragma Unreferenced (Result_16, Result_32, Result_64);
      Keys_16 : constant Folding_Keys := Generate_Folding_Keys (16, 16#1021#, False);
      Keys_32 : constant Folding_Keys := Generate_Folding_Keys (32, 16#04C1_1DB7#, False);
      Keys_64 : constant Folding_Keys :=
        Generate_Folding_Keys (64, 16#42F0_E1EB_A9EA_3693#, False);
   begin
      begin
         Result_16 := Update_16 (0, False, Keys_16, Dummy);
      exception
         when Program_Error => Raised := True;
      end;
      Check (Raised, "CRC-16 scalar/AArch64 SSE stub fails closed");

      Raised := False;
      begin
         Result_32 := Update_32 (0, False, Keys_32, Dummy);
      exception
         when Program_Error => Raised := True;
      end;
      Check (Raised, "CRC-32 scalar/AArch64 SSE stub fails closed");

      Raised := False;
      begin
         Result_64 := Update_64 (0, False, Keys_64, Dummy);
      exception
         when Program_Error => Raised := True;
      end;
      Check (Raised, "CRC-64 scalar/AArch64 SSE stub fails closed");

   end Check_Stubs;

   procedure Run is
   begin
      for Index in Storage'Range loop
         Storage (Index) :=
           Byte
             ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
      end loop;

      if not Compiled then
         Check
           (not X86_Features.Generic_SSE_Available,
            "uncompiled generic SSE leaf must not be runtime available");
         Check_Stubs;
      elsif not X86_Features.Generic_SSE_Available then
         Ada.Text_IO.Put_Line
           ("Generic x86 SSE tests skipped: SSSE3/SSE4.1/PCLMUL unavailable");
         return;
      else
         Check_Catalogue;
         Check_Custom;
      end if;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " generic x86 SSE tests failed";
      end if;

      if Compiled then
         Ada.Text_IO.Put_Line
           ("Generic x86 SSE matches scalar for all catalogue and custom cases");
      else
         Ada.Text_IO.Put_Line ("Generic x86 SSE stubs fail closed");
      end if;
   end Run;
end Flyology_CRC.Generic_SSE.Tests;
