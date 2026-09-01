with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.Native;
with Flyology_CRC.Native_Features;
with Flyology_CRC.Width_32;

package body Flyology_CRC.CRC32_AArch64_Small.Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;

   subtype Offset is Ada.Streams.Stream_Element_Offset;
   subtype U32 is Interfaces.Unsigned_32;

   type Algorithm_Kind is (ISCSI, ISO_HDLC);
   type State_List is array (Positive range <>) of U32;
   States : constant State_List :=
     (0, 16#FFFF_FFFF#, 16#1357_9BDF#, 16#A5C3_6987#);

   Test_Data : Byte_Array (0 .. 511);
   for Test_Data'Alignment use 16;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   function Native_Update
     (Kind  : Algorithm_Kind;
      State : U32;
      Data  : Byte_Array) return U32 is
     (case Kind is
         when ISCSI   => Update_ISCSI (State, Data),
         when ISO_HDLC => Update_ISO_HDLC (State, Data));

   function Table_Update
     (Kind  : Algorithm_Kind;
      State : U32;
      Data  : Byte_Array) return U32 is
      --  These are the maintained catalogue parameters for the two reflected
      --  CRC-32 algorithms exercised by the native instruction families.
      Configuration : constant Width_32.Parameters :=
        (case Kind is
            when ISCSI =>
              Width_32.Create
                (Polynomial    => 16#1EDC_6F41#,
                 Initial_Value => State,
                 Reflected     => True,
                 Final_XOR     => 0),
            when ISO_HDLC =>
              Width_32.Create
                (Polynomial    => 16#04C1_1DB7#,
                 Initial_Value => State,
                 Reflected     => True,
                 Final_XOR     => 0));
      Context : Width_32.Context := Width_32.Start (Configuration);
   begin
      Width_32.Update (Context, Data);
      return Width_32.Result (Context);
   end Table_Update;

   function Name (Kind : Algorithm_Kind) return String is
     (case Kind is
         when ISCSI    => "ISCSI",
         when ISO_HDLC => "ISO-HDLC");

   procedure Check_Case (Length, Alignment : Natural) is
      First : constant Offset := Test_Data'First + Offset (Alignment);
      Last  : constant Offset := First + Offset (Length) - 1;
      Data  : Byte_Array renames Test_Data (First .. Last);
   begin
      for Kind in Algorithm_Kind loop
         for State of States loop
            Check
              (Native_Update (Kind, State, Data) = Table_Update (Kind, State, Data),
               Name (Kind) & " raw length" & Length'Image &
               " alignment" & Alignment'Image & " state" & U32'Image (State));
         end loop;

         declare
            Raw : constant U32 := Native_Update (Kind, 16#FFFF_FFFF#, Data);
         begin
            case Kind is
               when ISCSI =>
                  Check
                    ((Raw xor 16#FFFF_FFFF#) = Width_32.Compute_ISCSI (Data),
                     "ISCSI public length" & Length'Image &
                     " alignment" & Alignment'Image);
                  Check
                    ((Raw xor 16#FFFF_FFFF#) = CRC_Fast_Oracle.CRC32_ISCSI (Data),
                     "ISCSI Rust length" & Length'Image &
                     " alignment" & Alignment'Image);
               when ISO_HDLC =>
                  Check
                    ((Raw xor 16#FFFF_FFFF#) = Width_32.Compute_ISO_HDLC (Data),
                     "ISO-HDLC public length" & Length'Image &
                     " alignment" & Alignment'Image);
                  Check
                    ((Raw xor 16#FFFF_FFFF#) = CRC_Fast_Oracle.CRC32_ISO_HDLC (Data),
                     "ISO-HDLC Rust length" & Length'Image &
                     " alignment" & Alignment'Image);
            end case;
         end;
      end loop;
   end Check_Case;

   procedure Check_Chaining (Length, Alignment, Split : Natural) is
      First      : constant Offset := Test_Data'First + Offset (Alignment);
      Last       : constant Offset := First + Offset (Length) - 1;
      Split_Last : constant Offset := First + Offset (Split) - 1;
      Whole      : Byte_Array renames Test_Data (First .. Last);
      Left       : Byte_Array renames Test_Data (First .. Split_Last);
      Right      : Byte_Array renames Test_Data (Split_Last + 1 .. Last);
   begin
      for Kind in Algorithm_Kind loop
         for State of States loop
            Check
              (Native_Update
                 (Kind, Native_Update (Kind, State, Left), Right) =
                 Native_Update (Kind, State, Whole),
               Name (Kind) & " chain length" & Length'Image &
               " split" & Split'Image & " state" & U32'Image (State));
         end loop;
      end loop;
   end Check_Chaining;

   procedure Check_Scalar_Stub is
      Empty : Byte_Array renames Test_Data (1 .. 0);
      One   : Byte_Array renames Test_Data (0 .. 0);

      procedure Check_One (Kind : Algorithm_Kind) is
         Raised : Boolean := False;
      begin
         Check
           (Native_Update (Kind, 16#1357_9BDF#, Empty) = 16#1357_9BDF#,
            Name (Kind) & " scalar empty-input identity");
         begin
            declare
               Ignored : constant U32 := Native_Update (Kind, 16#1357_9BDF#, One);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when Program_Error =>
               Raised := True;
         end;
         Check (Raised, Name (Kind) & " scalar nonempty call fails closed");
      end Check_One;
   begin
      for Kind in Algorithm_Kind loop
         Check_One (Kind);
      end loop;
   end Check_Scalar_Stub;

   procedure Run is
      type Length_List is array (Positive range <>) of Natural;
      Chained_Lengths : constant Length_List := (0, 1, 7, 8, 63, 64, 127, 128, 129);
   begin
      for Index in Test_Data'Range loop
         Test_Data (Index) :=
           Byte
             ((Natural (Index) * 131 + Natural (Index) / 7 + 16#5A#) mod 256);
      end loop;

      if not Native.Compiled then
         Check (not Native_Features.CRC32_Available, "scalar CRC32 feature is false");
         Check_Scalar_Stub;
         if Failures /= 0 then
            raise Program_Error with Failures'Image & " AArch64 CRC32 small tests failed";
         end if;
         Ada.Text_IO.Put_Line
           ("AArch64 CRC32 small scalar stubs fail closed as required");
         return;
      elsif not Native_Features.CRC32_Available then
         Ada.Text_IO.Put_Line ("AArch64 CRC32 small tests skipped: CRC32 unavailable");
         return;
      else
         for Length in 0 .. 129 loop
            for Alignment in 0 .. 15 loop
               Check_Case (Length, Alignment);
            end loop;
         end loop;

         for Length of Chained_Lengths loop
            declare
               Alignment : constant Natural := Length mod 16;
               type Split_List is array (Positive range <>) of Natural;
               Splits : constant Split_List :=
                 (0, (if Length = 0 then 0 else 1), Length / 2,
                  (if Length = 0 then 0 else Length - 1), Length);
            begin
               for Split of Splits loop
                  Check_Chaining (Length, Alignment, Split);
               end loop;
            end;
         end loop;
      end if;

      if Failures /= 0 then
         raise Program_Error with Failures'Image & " AArch64 CRC32 small tests failed";
      end if;
      Ada.Text_IO.Put_Line
        ("AArch64 CRC32 small kernels match table, public, Rust, and chaining results");
   end Run;
end Flyology_CRC.CRC32_AArch64_Small.Tests;
