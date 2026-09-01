with Ada.Streams;
with Ada.Text_IO;
with Flyology_CRC.Width_32;
with Flyology_CRC.X86_Features;

package body Flyology_CRC.CRC32C_X86_SSE_V4S3X3.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   type State_List is array (Positive range <>) of U32;
   States : constant State_List :=
     (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);

   Test_Data : Byte_Array (0 .. 1_048_639);
   for Test_Data'Alignment use 16;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Table_Update
     (State : U32;
      Data  : Byte_Array) return U32 is
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
   end Table_Update;

   procedure Check_Case (Length, Alignment : Natural) is
      --  Every slice has a nonzero lower bound; its address alignment still
      --  spans all sixteen residues required by the SSE path.
      First : constant Offset := 16 + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
   begin
      for State of States loop
         Check
           (Update (State, Data) = Table_Update (State, Data),
            "raw length" & Length'Image & " alignment" & Alignment'Image &
            " state" & U32'Image (State));
      end loop;

      declare
         Raw : constant U32 := Update (16#FFFF_FFFF#, Data);
      begin
         Check
           ((Raw xor 16#FFFF_FFFF#) = Width_32.Compute_ISCSI (Data),
            "public length" & Length'Image & " alignment" & Alignment'Image);
      end;
   end Check_Case;

   procedure Check_Chaining (Length, Alignment, Split : Natural) is
      First      : constant Offset := 16 + Offset (Alignment);
      Last       : constant Offset := First + Offset (Length) - 1;
      Split_Last : constant Offset := First + Offset (Split) - 1;
      Whole      : Byte_Array renames Test_Data (First .. Last);
      Left       : Byte_Array renames Test_Data (First .. Split_Last);
      Right      : Byte_Array renames Test_Data (Split_Last + 1 .. Last);
   begin
      for State of States loop
         Check
           (Update (Update (State, Left), Right) = Update (State, Whole),
            "chain length" & Length'Image & " alignment" & Alignment'Image &
            " split" & Split'Image & " state" & U32'Image (State));
      end loop;
   end Check_Chaining;

   procedure Check_Stub is
      Empty  : Byte_Array renames Test_Data (17 .. 16);
      One    : Byte_Array renames Test_Data (17 .. 17);
      Raised : Boolean := False;
   begin
      Check
        (Update (16#1357_9BDF#, Empty) = 16#1357_9BDF#,
         "non-x86 empty-input identity");
      begin
         declare
            Ignored : constant U32 := Update (16#1357_9BDF#, One);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Program_Error =>
            Raised := True;
      end;
      Check (Raised, "non-x86 nonempty call fails closed");
   end Check_Stub;

   procedure Run is
      type Length_List is array (Positive range <>) of Natural;
      Large_Lengths : constant Length_List :=
        (1_023, 1_024, 1_025, 4_095, 4_096, 4_097,
         1_048_543, 1_048_544, 1_048_545);
      Chained_Lengths : constant Length_List :=
        (256, 257, 279, 280, 281, 415, 416, 417, 551, 552, 553,
         1_024, 4_096, 1_048_544);
   begin
      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte
             ((Natural (Index) * 157 + Natural (Index) / 11 + 16#71#) mod 256);
      end loop;

      if not Compiled then
         Check (not X86_Features.CRC32C_SSE_Available,
                "non-x86 CRC32C SSE feature is false");
         Check_Stub;
      elsif not X86_Features.CRC32C_SSE_Available then
         declare
            Empty : Byte_Array renames Test_Data (17 .. 16);
         begin
            Check
              (Update (16#1357_9BDF#, Empty) = 16#1357_9BDF#,
               "x86 empty-input identity without SSE tier");
         end;
         Ada.Text_IO.Put_Line ("x86 CRC32C SSE fusion tests skipped: tier unavailable");
      else
         --  This exhaustive band covers the 256-byte dispatch boundary and
         --  the 144, 280, 416, and 552-byte v4s3x3 loop transitions.
         for Length in 0 .. 600 loop
            for Alignment in 0 .. 15 loop
               Check_Case (Length, Alignment);
            end loop;
         end loop;

         for Length of Large_Lengths loop
            for Alignment in 0 .. 15 loop
               Check_Case (Length, Alignment);
            end loop;
         end loop;

         for Length of Chained_Lengths loop
            declare
               Alignment : constant Natural := Length mod 16;
               type Split_List is array (Positive range <>) of Natural;
               Splits : constant Split_List :=
                 (0, 1, Length / 3, Length / 2, Length - 1, Length);
            begin
               for Split of Splits loop
                  Check_Chaining (Length, Alignment, Split);
               end loop;
            end;
         end loop;
      end if;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " x86 CRC32C SSE fusion tests failed";
      end if;

      if Compiled and then X86_Features.CRC32C_SSE_Available then
         Ada.Text_IO.Put_Line
           ("x86 CRC32C SSE fusion matches table, public, alignment, and chaining cases");
      elsif not Compiled then
         Ada.Text_IO.Put_Line ("x86 CRC32C SSE fusion non-x86 stubs fail closed as required");
      end if;
   end Run;
end Flyology_CRC.CRC32C_X86_SSE_V4S3X3.Tests;
