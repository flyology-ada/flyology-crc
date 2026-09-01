with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1;
with Flyology_CRC.Native;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_32;
with Interfaces;

procedure Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1_Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset_Type is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   --  The extra prefix gives each checked length a different address
   --  alignment without allocating a second large fixture.
   Maximum_Length : constant Offset_Type := 1_048_576;
   Test_Data      : Byte_Array (0 .. Maximum_Length + 64);
   Failures       : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Scalar_Update (State : U32; Data : Byte_Array) return U32 is
      Polynomial : constant U32 := 16#EDB8_8320#;
      Result     : U32 := State;
   begin
      for Element of Data loop
         Result := Result xor U32 (Element);
         for Bit in 1 .. 8 loop
            if (Result and 1) /= 0 then
               Result := Interfaces.Shift_Right (Result, 1) xor Polynomial;
            else
               Result := Interfaces.Shift_Right (Result, 1);
            end if;
         end loop;
      end loop;
      return Result;
   end Scalar_Update;

   procedure Check_Length
     (Length : Natural;
      Start  : Offset_Type;
      State  : U32 := 16#FFFF_FFFF#) is
      Last : constant Offset_Type := Start + Offset_Type (Length) - 1;
      Data : Byte_Array renames Test_Data (Start .. Last);
      Expected : constant U32 := Scalar_Update (State, Data);
      Actual   : constant U32 :=
        CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Data);
   begin
      Check
        (Actual = Expected,
         "length" & Natural'Image (Length) & " start" & Offset_Type'Image (Start));
      if State = 16#FFFF_FFFF# then
         Check
           ((Actual xor 16#FFFF_FFFF#) = Width_32.Compute_ISO_HDLC (Data),
            "public ISO-HDLC length" & Natural'Image (Length));
      end if;
   end Check_Length;

   procedure Check_Forced (Length, Alignment : Natural) is
      Start : constant Offset_Type := Offset_Type (Alignment) + 16;
      Last  : constant Offset_Type := Start + Offset_Type (Length) - 1;
      Whole_First : constant Offset_Type := Start - 13;
      Whole_Last  : constant Offset_Type := Last + 7;
      Prefix : Byte_Array renames Test_Data (Whole_First .. Start - 1);
      Data  : Byte_Array renames Test_Data (Start .. Last);
      Suffix : Byte_Array renames Test_Data (Last + 1 .. Whole_Last);
      Whole : Byte_Array renames Test_Data (Whole_First .. Whole_Last);
      States : constant array (Positive range 1 .. 4) of U32 :=
        (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);
   begin
      for State of States loop
         Check
           (CRC32_ISO_HDLC_PMULL_V12E_V1.Update_V12_64_Tail (State, Data) =
            CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Data),
            "forced length" & Length'Image & " alignment" & Alignment'Image &
            " state" & U32'Image (State));
         Check
           (CRC32_ISO_HDLC_PMULL_V12E_V1.Update
              (CRC32_ISO_HDLC_PMULL_V12E_V1.Update_V12_64_Tail
                 (CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Prefix), Data),
               Suffix) = CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Whole),
            "forced chain length" & Length'Image &
            " alignment" & Alignment'Image & " state" & U32'Image (State));
         if Length = 1_024 then
            Check
              (CRC32_ISO_HDLC_PMULL_V12E_V1.Update_1024_V12
                 (State, Data (Data'First)'Address) =
               CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Data),
               "exact 1024 alignment" & Alignment'Image &
               " state" & U32'Image (State));
            Check
              (CRC32_ISO_HDLC_PMULL_V12E_V1.Update
                 (CRC32_ISO_HDLC_PMULL_V12E_V1.Update_1024_V12
                    (CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Prefix),
                     Data (Data'First)'Address),
                  Suffix) = CRC32_ISO_HDLC_PMULL_V12E_V1.Update (State, Whole),
               "exact 1024 chain alignment" & Alignment'Image &
               " state" & U32'Image (State));
         end if;
      end loop;
      Check
        ((CRC32_ISO_HDLC_PMULL_V12E_V1.Update_V12_64_Tail
            (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#) =
         Width_32.Compute_ISO_HDLC (Data),
         "forced/public length" & Length'Image & " alignment" & Alignment'Image);
      Check
        ((CRC32_ISO_HDLC_PMULL_V12E_V1.Update_V12_64_Tail
            (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#) =
         CRC_Fast_Oracle.CRC32_ISO_HDLC (Data),
         "forced/Rust length" & Length'Image & " alignment" & Alignment'Image);
      if Length = 1_024 then
         Check
           ((CRC32_ISO_HDLC_PMULL_V12E_V1.Update_1024_V12
               (16#FFFF_FFFF#, Data (Data'First)'Address) xor 16#FFFF_FFFF#) =
            CRC_Fast_Oracle.CRC32_ISO_HDLC (Data),
            "exact 1024/Rust alignment" & Alignment'Image);
      end if;
   end Check_Forced;

   procedure Check_Scalar_Stub is
      Empty : Byte_Array renames Test_Data (1 .. 0);
      One   : Byte_Array renames Test_Data (0 .. 0);
      Raised : Boolean := False;
   begin
      Check
        (CRC32_ISO_HDLC_PMULL_V12E_V1.Update (16#1357_9BDF#, Empty) = 16#1357_9BDF#,
         "scalar stub preserves the empty-input state");
      begin
         declare
            Ignored : constant U32 :=
              CRC32_ISO_HDLC_PMULL_V12E_V1.Update (16#1357_9BDF#, One);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "scalar stub rejects nonempty input");
   end Check_Scalar_Stub;
begin
   for Index in Test_Data'Range loop
      Test_Data (Index) :=
        Byte ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
   end loop;

   if not Native.Compiled then
      Check (not Native_Features.PMULL_Available, "scalar PMULL feature is false");
      Check (not Native_Features.CRC32_Available, "scalar CRC32 feature is false");
      Check (not Native_Features.SHA3_Available, "scalar SHA3 feature is false");
      Check_Scalar_Stub;
   elsif not Native_Features.PMULL_Available
     or else not Native_Features.CRC32_Available
   then
      Ada.Text_IO.Put_Line ("ISO-HDLC v12e tests skipped: CRC32+PMULL is unavailable");
      return;
   else
      for Length in 0 .. 256 loop
         Check_Length (Length, Offset_Type (Length mod 16));
      end loop;

      Check_Length (1_023, 3);
      Check_Length (1_024, 5);
      Check_Length (1_025, 7);
      Check_Length (1_048_576, 11);
      Check_Length (1_025, 13, 16#1357_9BDF#);

      for Alignment in 0 .. 15 loop
         Check_Forced (1_024, Alignment);
         Check_Forced (1_048_576, Alignment);
      end loop;
   end if;

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " ISO-HDLC v12e tests failed";
   end if;

   Ada.Text_IO.Put_Line
     ("ISO-HDLC v12e matches the scalar reflected CRC for all required lengths");
end Flyology_CRC.CRC32_ISO_HDLC_PMULL_V12E_V1_Tests;
