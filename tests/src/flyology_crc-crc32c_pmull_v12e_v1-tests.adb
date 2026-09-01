with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.Native;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_32;

package body Flyology_CRC.CRC32C_PMULL_V12E_V1.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   Large_Length : constant := 1_048_576;
   Test_Data : Byte_Array (1 .. Large_Length + 64);
   Failures  : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Check_Length (Length : Natural) is
      First : constant Offset := Test_Data'First + Offset (Length mod 16);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
      State : constant U32 :=
        16#1357_9BDF# xor U32 (Length) * 16#9E37_79B9#;
      Configuration : constant Width_32.Parameters :=
        --  CRC-32/ISCSI polynomial from the maintained catalogue contract.
        Width_32.Create
          (Polynomial    => 16#1EDC_6F41#,
           Initial_Value => State,
           Reflected     => True,
           Final_XOR     => 0);
      Context : Width_32.Context := Width_32.Start (Configuration);
      Actual  : U32;
   begin
      Width_32.Update (Context, Data);
      Actual := Update (State, Data);
      Check
        (Actual = Width_32.Result (Context),
         "raw/table length" & Length'Image);

      Actual := Update (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#;
      Check
        (Actual = Width_32.Compute_ISCSI (Data),
         "public length" & Length'Image);
      Check
        (Actual = CRC_Fast_Oracle.CRC32_ISCSI (Data),
         "Rust oracle length" & Length'Image);
   end Check_Length;

   procedure Check_Forced (Length, Alignment : Natural) is
      First : constant Offset := Test_Data'First + Offset (Alignment) + 16;
      Last  : constant Offset := First + Offset (Length) - 1;
      Whole_First : constant Offset := First - 13;
      Whole_Last  : constant Offset := Last + 7;
      Prefix : Byte_Array renames Test_Data (Whole_First .. First - 1);
      Data  : Byte_Array renames Test_Data (First .. Last);
      Suffix : Byte_Array renames Test_Data (Last + 1 .. Whole_Last);
      Whole : Byte_Array renames Test_Data (Whole_First .. Whole_Last);
      States : constant array (Positive range 1 .. 4) of U32 :=
        (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);
   begin
      for State of States loop
         Check
           (Update_V12_64_Tail (State, Data) = Update (State, Data),
            "forced length" & Length'Image & " alignment" & Alignment'Image &
            " state" & U32'Image (State));
         Check
           (Update
              (Update_V12_64_Tail (Update (State, Prefix), Data), Suffix) =
            Update (State, Whole),
            "forced chain length" & Length'Image &
            " alignment" & Alignment'Image & " state" & U32'Image (State));
         if Length = 1_024 then
            Check
              (Update_1024_V12 (State, Data (Data'First)'Address) =
               Update (State, Data),
               "exact 1024 alignment" & Alignment'Image &
               " state" & U32'Image (State));
            Check
              (Update
                 (Update_1024_V12
                    (Update (State, Prefix), Data (Data'First)'Address),
                  Suffix) = Update (State, Whole),
               "exact 1024 chain alignment" & Alignment'Image &
               " state" & U32'Image (State));
         end if;
      end loop;
      Check
        ((Update_V12_64_Tail (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#) =
         Width_32.Compute_ISCSI (Data),
         "forced/public length" & Length'Image & " alignment" & Alignment'Image);
      Check
        ((Update_V12_64_Tail (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#) =
         CRC_Fast_Oracle.CRC32_ISCSI (Data),
         "forced/Rust length" & Length'Image & " alignment" & Alignment'Image);
      if Length = 1_024 then
         Check
           ((Update_1024_V12
               (16#FFFF_FFFF#, Data (Data'First)'Address) xor 16#FFFF_FFFF#) =
            CRC_Fast_Oracle.CRC32_ISCSI (Data),
            "exact 1024/Rust alignment" & Alignment'Image);
      end if;
   end Check_Forced;

   procedure Run is
   begin
      if not Native.Compiled then
         declare
            Empty : Byte_Array renames Test_Data (Test_Data'First .. Test_Data'First - 1);
            One   : Byte_Array renames Test_Data (Test_Data'First .. Test_Data'First);
         begin
            Check
              (Update (16#1357_9BDF#, Empty) = 16#1357_9BDF#,
               "scalar empty-input identity");
            begin
               declare
                  Unexpected : constant U32 := Update (16#1357_9BDF#, One);
               begin
                  Check
                    (Unexpected = 16#1357_9BDF# and then False,
                     "scalar nonempty call must fail closed");
               end;
            exception
               when Program_Error =>
                  null;
            end;
         end;
         if Failures /= 0 then
            raise Program_Error with Failures'Image & " CRC32C scalar-stub tests failed";
         end if;
         Ada.Text_IO.Put_Line
           ("CRC32C PMULL v12e_v1 scalar stub fails closed as required");
         return;
      elsif not Native_Features.PMULL_Available
        or else not Native_Features.CRC32_Available
      then
         Ada.Text_IO.Put_Line
           ("CRC32C PMULL v12e_v1 tests skipped: CRC32+PMULL unavailable");
         return;
      end if;

      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte
             ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
      end loop;

      for Length in 0 .. 256 loop
         Check_Length (Length);
      end loop;
      Check_Length (1_023);
      Check_Length (1_024);
      Check_Length (1_025);
      Check_Length (Large_Length - 1);
      Check_Length (Large_Length);
      Check_Length (Large_Length + 1);

      for Alignment in 0 .. 15 loop
         Check_Forced (448, Alignment);
         Check_Forced (640, Alignment);
         Check_Forced (832, Alignment);
         Check_Forced (1_024, Alignment);
         Check_Forced (Large_Length, Alignment);
      end loop;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " CRC32C PMULL v12e_v1 tests failed";
      end if;
      Ada.Text_IO.Put_Line
        ("CRC32C PMULL v12e_v1 matches table, public, and Rust results");
   end Run;
end Flyology_CRC.CRC32C_PMULL_V12E_V1.Tests;
