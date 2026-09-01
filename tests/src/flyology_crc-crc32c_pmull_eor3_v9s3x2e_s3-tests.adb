with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.Native;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_32;

package body Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   type State_List is array (Positive range <>) of U32;
   States : constant State_List :=
     (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);

   type Length_List is array (Positive range <>) of Natural;
   Boundary_Lengths : constant Length_List :=
     (383, 384, 385, 1_023, 1_024, 1_025, 1_151, 1_152, 1_153);
   Large_Length : constant := 1_048_576;
   Test_Data : Byte_Array (1 .. Large_Length + 64);
   for Test_Data'Alignment use 16;
   Failures  : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Table_Result (State : U32; Data : Byte_Array) return U32 is
      --  CRC-32/ISCSI polynomial from the maintained catalogue contract.
      Configuration : constant Width_32.Parameters :=
        Width_32.Create
          (Polynomial    => 16#1EDC_6F41#,
           Initial_Value => State,
           Reflected     => True,
           Final_XOR     => 0);
      Context : Width_32.Context := Width_32.Start (Configuration);
   begin
      Width_32.Update (Context, Data);
      return Width_32.Result (Context);
   end Table_Result;

   procedure Check_Case (Length, Alignment : Natural) is
      First : constant Offset := Test_Data'First + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
      Public_Result : constant U32 :=
        Update (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#;
   begin
      for State of States loop
         Check
           (Update (State, Data) = Table_Result (State, Data),
            "raw/table length" & Length'Image & " alignment" & Alignment'Image &
            " state" & U32'Image (State));
      end loop;
      Check
        (Public_Result = Width_32.Compute_ISCSI (Data),
         "public length" & Length'Image & " alignment" & Alignment'Image);
      Check
        (Public_Result = CRC_Fast_Oracle.CRC32_ISCSI (Data),
         "Rust length" & Length'Image & " alignment" & Alignment'Image);
   end Check_Case;

   procedure Check_Split
     (Length, Alignment, Split : Natural;
      State                    : U32) is
      First      : constant Offset := Test_Data'First + Offset (Alignment);
      Last       : constant Offset := First + Offset (Length) - 1;
      Split_Last : constant Offset := First + Offset (Split) - 1;
      Data       : Byte_Array renames Test_Data (First .. Last);
      Left       : Byte_Array renames Test_Data (First .. Split_Last);
      Right      : Byte_Array renames Test_Data (Split_Last + 1 .. Last);
      Whole      : constant U32 := Update (State, Data);
      Chained    : constant U32 := Update (Update (State, Left), Right);
   begin
      Check
        (Chained = Whole,
         "chain length" & Length'Image & " split" & Split'Image &
         " alignment" & Alignment'Image & " state" & U32'Image (State));
   end Check_Split;

   procedure Check_Chaining (Length : Natural) is
      Alignment : constant Natural := Length mod 16;
      type Split_List is array (Positive range <>) of Natural;
      Splits : constant Split_List :=
        (0, Length / 3, Length / 2,
         (if Length = 0 then 0 else Length - 1), Length);
   begin
      for State of States loop
         for Split of Splits loop
            Check_Split (Length, Alignment, Split, State);
         end loop;
      end loop;
   end Check_Chaining;

   procedure Check_Forced_1024 (Alignment : Natural) is
      Block_First : constant Offset := Test_Data'First + 48 + Offset (Alignment);
      Block_Last  : constant Offset := Block_First + 1_023;
      Whole_First : constant Offset := Block_First - 37;
      Whole_Last  : constant Offset := Block_Last + 29;
      Prefix      : Byte_Array renames Test_Data (Whole_First .. Block_First - 1);
      Block       : Byte_Array renames Test_Data (Block_First .. Block_Last);
      Suffix      : Byte_Array renames Test_Data (Block_Last + 1 .. Whole_Last);
      Whole       : Byte_Array renames Test_Data (Whole_First .. Whole_Last);
   begin
      for State of States loop
         Check
           (Update_1024_V12 (State, Block) = Table_Result (State, Block),
            "forced 1024 alignment" & Alignment'Image &
            " state" & U32'Image (State));
         Check
           (Update
              (Update_1024_V12 (Update (State, Prefix), Block), Suffix) =
              Table_Result (State, Whole),
            "forced chained 1024 alignment" & Alignment'Image &
            " state" & U32'Image (State));
      end loop;

      Check
        ((Update_1024_V12 (16#FFFF_FFFF#, Block) xor 16#FFFF_FFFF#) =
         Width_32.Compute_ISCSI (Block),
         "forced/public 1024 alignment" & Alignment'Image);
      Check
        ((Update_1024_V12 (16#FFFF_FFFF#, Block) xor 16#FFFF_FFFF#) =
         CRC_Fast_Oracle.CRC32_ISCSI (Block),
         "forced/Rust 1024 alignment" & Alignment'Image);
   end Check_Forced_1024;

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
            raise Program_Error with Failures'Image & " CRC32C EOR3 scalar-stub tests failed";
         end if;
         Ada.Text_IO.Put_Line
           ("CRC32C PMULL/EOR3 v9s3x2e_s3 scalar stub fails closed as required");
         return;
      elsif not Native_Features.PMULL_Available
        or else not Native_Features.CRC32_Available
        or else not Native_Features.SHA3_Available
      then
         Ada.Text_IO.Put_Line
           ("CRC32C PMULL/EOR3 tests skipped: CRC32+PMULL+SHA3 unavailable");
         return;
      end if;

      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte
             ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
      end loop;

      for Length in 0 .. 256 loop
         for Alignment in 0 .. 15 loop
            Check_Case (Length, Alignment);
         end loop;
      end loop;
      for Length of Boundary_Lengths loop
         for Alignment in 0 .. 15 loop
            Check_Case (Length, Alignment);
         end loop;
      end loop;
      for Alignment in 0 .. 15 loop
         Check_Forced_1024 (Alignment);
      end loop;
      for Length in Large_Length - 1 .. Large_Length + 1 loop
         for Alignment in 0 .. 15 loop
            Check_Case (Length, Alignment);
         end loop;
      end loop;

      for Length of
        Length_List'(0, 1, 31, 32, 191, 192, 383, 384, 385, 1_025, 1_152, Large_Length + 1)
      loop
         Check_Chaining (Length);
      end loop;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " CRC32C PMULL/EOR3 tests failed";
      end if;
      Ada.Text_IO.Put_Line
        ("CRC32C PMULL/EOR3 v9s3x2e_s3 matches table, public, Rust, and chaining results");
   end Run;
end Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3.Tests;
