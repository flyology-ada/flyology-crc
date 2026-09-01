with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3;
with Flyology_CRC.Native;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_32;
with Interfaces;

procedure Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3_Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset_Type is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   Maximum_Length : constant Offset_Type := 1_048_577;
   Test_Data      : Byte_Array (0 .. Maximum_Length + 31);
   for Test_Data'Alignment use 16;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Scalar_Update (State : U32; Data : Byte_Array) return U32 is
      --  Reflected form of the catalogue's CRC-32/ISO-HDLC polynomial.
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
      Last     : constant Offset_Type := Start + Offset_Type (Length) - 1;
      Data     : Byte_Array renames Test_Data (Start .. Last);
      Expected : constant U32 := Scalar_Update (State, Data);
      Actual   : constant U32 :=
        CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update (State, Data);
   begin
      Check
        (Actual = Expected,
         "raw length" & Natural'Image (Length) & " start" & Offset_Type'Image (Start));
      if State = 16#FFFF_FFFF# then
         Check
           ((Actual xor 16#FFFF_FFFF#) = Width_32.Compute_ISO_HDLC (Data),
            "public length" & Natural'Image (Length));
         Check
           ((Actual xor 16#FFFF_FFFF#) = CRC_Fast_Oracle.CRC32_ISO_HDLC (Data),
            "Rust length" & Natural'Image (Length));
      end if;
   end Check_Length;

   procedure Check_Chained (Length, Split : Natural; Start : Offset_Type) is
      Last        : constant Offset_Type := Start + Offset_Type (Length) - 1;
      Split_Point : constant Offset_Type := Start + Offset_Type (Split);
      Whole       : Byte_Array renames Test_Data (Start .. Last);
      Left        : Byte_Array renames Test_Data (Start .. Split_Point - 1);
      Right       : Byte_Array renames Test_Data (Split_Point .. Last);
      State       : constant U32 := 16#1357_9BDF#;
      Expected    : constant U32 := Scalar_Update (State, Whole);
      Intermediate : constant U32 :=
        CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update (State, Left);
      Actual : constant U32 :=
        CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update (Intermediate, Right);
   begin
      Check
        (Actual = Expected,
         "chained length" & Natural'Image (Length) & " split" & Natural'Image (Split));
   end Check_Chained;

   procedure Check_Forced_1024 (Alignment : Natural) is
      Block_First : constant Offset_Type := 48 + Offset_Type (Alignment);
      Block_Last  : constant Offset_Type := Block_First + 1_023;
      Whole_First : constant Offset_Type := Block_First - 37;
      Whole_Last  : constant Offset_Type := Block_Last + 29;
      Prefix      : Byte_Array renames Test_Data (Whole_First .. Block_First - 1);
      Block       : Byte_Array renames Test_Data (Block_First .. Block_Last);
      Suffix      : Byte_Array renames Test_Data (Block_Last + 1 .. Whole_Last);
      Whole       : Byte_Array renames Test_Data (Whole_First .. Whole_Last);
      States      : constant array (Positive range 1 .. 4) of U32 :=
        (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);
   begin
      for State of States loop
         Check
           (CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update_1024_V12 (State, Block) =
            Scalar_Update (State, Block),
            "forced 1024 alignment" & Alignment'Image &
            " state" & U32'Image (State));
         Check
           (CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update
              (CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update_1024_V12
                 (CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update (State, Prefix), Block),
               Suffix) = Scalar_Update (State, Whole),
            "forced chained 1024 alignment" & Alignment'Image &
            " state" & U32'Image (State));
      end loop;

      Check
        ((CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update_1024_V12
            (16#FFFF_FFFF#, Block) xor 16#FFFF_FFFF#) =
         Width_32.Compute_ISO_HDLC (Block),
         "forced/public 1024 alignment" & Alignment'Image);
      Check
        ((CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update_1024_V12
            (16#FFFF_FFFF#, Block) xor 16#FFFF_FFFF#) =
         CRC_Fast_Oracle.CRC32_ISO_HDLC (Block),
         "forced/Rust 1024 alignment" & Alignment'Image);
   end Check_Forced_1024;

   procedure Check_Scalar_Stub is
      Empty  : Byte_Array renames Test_Data (1 .. 0);
      One    : Byte_Array renames Test_Data (0 .. 0);
      Raised : Boolean := False;
   begin
      Check
        (CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update
           (16#1357_9BDF#, Empty) = 16#1357_9BDF#,
         "scalar empty-input identity");
      begin
         declare
            Ignored : constant U32 :=
              CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3.Update
                (16#1357_9BDF#, One);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "scalar nonempty call fails closed");
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
     or else not Native_Features.SHA3_Available
   then
      Ada.Text_IO.Put_Line ("ISO-HDLC EOR3 tests skipped: CRC32+PMULL+SHA3 unavailable");
      return;
   else
      for Length in 0 .. 256 loop
         Check_Length (Length, Offset_Type (Length mod 16));
      end loop;

      for Alignment in 0 .. 15 loop
         Check_Length (1_153, Offset_Type (Alignment));
         Check_Forced_1024 (Alignment);
      end loop;

      Check_Length (383, 1);
      Check_Length (384, 3);
      Check_Length (385, 5);
      Check_Length (1_023, 7);
      Check_Length (1_024, 9);
      Check_Length (1_025, 11);
      Check_Length (1_151, 13);
      Check_Length (1_152, 15);
      Check_Length (1_153, 0);
      Check_Length (1_048_575, 1);
      Check_Length (1_048_576, 3);
      Check_Length (1_048_577, 5);

      Check_Length (1_025, 7, 16#1357_9BDF#);
      Check_Length (1_153, 11, 16#2468_ACE0#);
      Check_Length (1_048_577, 13, 16#A5C3_9E71#);

      Check_Chained (2_305, 0, 1);
      Check_Chained (2_305, 31, 3);
      Check_Chained (2_305, 32, 5);
      Check_Chained (2_305, 191, 7);
      Check_Chained (2_305, 192, 9);
      Check_Chained (2_305, 1_024, 11);
      Check_Chained (2_305, 1_025, 13);
      Check_Chained (2_305, 2_305, 15);
   end if;

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " ISO-HDLC EOR3 tests failed";
   end if;

   Ada.Text_IO.Put_Line
     ("ISO-HDLC EOR3 matches scalar, public, Rust, alignment, and chaining cases");
end Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3_Tests;
