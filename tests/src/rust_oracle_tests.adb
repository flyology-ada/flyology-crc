with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_CRC.Folding_Key_Tests;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Interfaces;
with System;

procedure Rust_Oracle_Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;
   use type System.Address;

   Maximum_Length : constant := 4_096;
   type Length_List is array (Positive range <>) of Natural;
   Lengths : constant Length_List :=
     (0,
      1,
      2,
      3,
      7,
      8,
      15,
      16,
      17,
      31,
      32,
      63,
      64,
      127,
      128,
      129,
      255,
      256,
      257,
      383,
      384,
      385,
      1_023,
      1_024,
      1_025,
      Maximum_Length);
   Split_Lengths : constant Length_List :=
     (0,
      1,
      15,
      16,
      17,
      31,
      32,
      63,
      64,
      127,
      128,
      129,
      255,
      256,
      257,
      383,
      384,
      385,
      1_023,
      1_024,
      1_025,
      Maximum_Length);

   Zero_Payload : Flyology_CRC.Byte_Array (0 .. Maximum_Length - 1);
   Positive_Payload : Flyology_CRC.Byte_Array (37 .. Maximum_Length + 36);
   Negative_Payload : Flyology_CRC.Byte_Array (-37 .. Maximum_Length - 38);

   --  These offsets are fixed by oracle/rust/src/lib.rs and the approved
   --  concatenation of the CRC-16, CRC-32, and CRC-64 enumerations.
   CRC16_ID_Offset : constant := 0;
   CRC32_ID_Offset : constant := 31;
   CRC64_ID_Offset : constant := 43;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   generic
      type Seed_Type is private;
      type Value_Type is mod <>;
      type Context_Type is private;
      with function Start (Seed : Seed_Type) return Context_Type;
      with procedure Reset (Object : in out Context_Type);
      with procedure Update
        (Object : in out Context_Type;
         Data   : Flyology_CRC.Byte_Array);
      with function Result (Object : Context_Type) return Value_Type;
   procedure Check_Streaming
     (Seed     : Seed_Type;
      Sample   : Flyology_CRC.Byte_Array;
      Expected : Value_Type;
      Name     : String);

   procedure Check_Streaming
     (Seed     : Seed_Type;
      Sample   : Flyology_CRC.Byte_Array;
      Expected : Value_Type;
      Name     : String) is
      Empty : Flyology_CRC.Byte_Array renames
        Sample (Sample'First .. Sample'First - 1);
   begin
      for Split_Length of Split_Lengths loop
         if Split_Length <= Sample'Length then
            declare
               Split_Last : constant Ada.Streams.Stream_Element_Offset :=
                 Sample'First + Ada.Streams.Stream_Element_Offset (Split_Length) - 1;
               Left : Flyology_CRC.Byte_Array renames
                 Sample (Sample'First .. Split_Last);
               Right : Flyology_CRC.Byte_Array renames
                 Sample (Split_Last + 1 .. Sample'Last);
               Object : Context_Type := Start (Seed);
            begin
               Update (Object, Left);
               Update (Object, Empty);
               Update (Object, Right);
               Check
                 (CRC_Fast_Oracle.Value_64 (Result (Object)) =
                    CRC_Fast_Oracle.Value_64 (Expected),
                  Name & " split" & Split_Length'Image & " length" & Sample'Length'Image &
                    " first" & Sample'First'Image);
            end;
         end if;
      end loop;

      if Sample'Length = 256 then
         declare
            First_Last : constant Ada.Streams.Stream_Element_Offset := Sample'First + 126;
            Second_Last : constant Ada.Streams.Stream_Element_Offset := First_Last + 128;
            First : Flyology_CRC.Byte_Array renames
              Sample (Sample'First .. First_Last);
            Second : Flyology_CRC.Byte_Array renames
              Sample (First_Last + 1 .. Second_Last);
            Third : Flyology_CRC.Byte_Array renames
              Sample (Second_Last + 1 .. Sample'Last);
            Object : Context_Type := Start (Seed);
         begin
            Update (Object, First);
            Update (Object, Second);
            Update (Object, Third);
            Check
              (CRC_Fast_Oracle.Value_64 (Result (Object)) =
                 CRC_Fast_Oracle.Value_64 (Expected),
               Name & " chunks 127/128/1 first" & Sample'First'Image);
         end;
      end if;

      declare
         Object       : Context_Type := Start (Seed);
         First_Result : Value_Type;
      begin
         Update (Object, Empty);
         Update (Object, Sample);
         First_Result := Result (Object);
         Check
           (CRC_Fast_Oracle.Value_64 (First_Result) = CRC_Fast_Oracle.Value_64 (Expected),
            Name & " whole update length" & Sample'Length'Image &
              " first" & Sample'First'Image);
         Check
           (CRC_Fast_Oracle.Value_64 (Result (Object)) =
              CRC_Fast_Oracle.Value_64 (First_Result),
            Name & " repeated result length" & Sample'Length'Image &
              " first" & Sample'First'Image);
         Reset (Object);
         Update (Object, Sample);
         Check
           (CRC_Fast_Oracle.Value_64 (Result (Object)) = CRC_Fast_Oracle.Value_64 (Expected),
            Name & " reset length" & Sample'Length'Image & " first" & Sample'First'Image);
      end;
   end Check_Streaming;

   procedure Check_Streaming_16 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_16.Algorithm,
        Value_Type   => Flyology_CRC.Width_16.Value,
        Context_Type => Flyology_CRC.Width_16.Context,
        Start        => Flyology_CRC.Width_16.Start,
        Reset        => Flyology_CRC.Width_16.Reset,
        Update       => Flyology_CRC.Width_16.Update,
        Result       => Flyology_CRC.Width_16.Result);
   procedure Check_Custom_Streaming_16 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_16.Parameters,
        Value_Type   => Flyology_CRC.Width_16.Value,
        Context_Type => Flyology_CRC.Width_16.Context,
        Start        => Flyology_CRC.Width_16.Start,
        Reset        => Flyology_CRC.Width_16.Reset,
        Update       => Flyology_CRC.Width_16.Update,
        Result       => Flyology_CRC.Width_16.Result);
   procedure Check_Streaming_32 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_32.Algorithm,
        Value_Type   => Flyology_CRC.Width_32.Value,
        Context_Type => Flyology_CRC.Width_32.Context,
        Start        => Flyology_CRC.Width_32.Start,
        Reset        => Flyology_CRC.Width_32.Reset,
        Update       => Flyology_CRC.Width_32.Update,
        Result       => Flyology_CRC.Width_32.Result);
   procedure Check_Custom_Streaming_32 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_32.Parameters,
        Value_Type   => Flyology_CRC.Width_32.Value,
        Context_Type => Flyology_CRC.Width_32.Context,
        Start        => Flyology_CRC.Width_32.Start,
        Reset        => Flyology_CRC.Width_32.Reset,
        Update       => Flyology_CRC.Width_32.Update,
        Result       => Flyology_CRC.Width_32.Result);
   procedure Check_Streaming_64 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_64.Algorithm,
        Value_Type   => Flyology_CRC.Width_64.Value,
        Context_Type => Flyology_CRC.Width_64.Context,
        Start        => Flyology_CRC.Width_64.Start,
        Reset        => Flyology_CRC.Width_64.Reset,
        Update       => Flyology_CRC.Width_64.Update,
        Result       => Flyology_CRC.Width_64.Result);
   procedure Check_Custom_Streaming_64 is new
     Check_Streaming
       (Seed_Type    => Flyology_CRC.Width_64.Parameters,
        Value_Type   => Flyology_CRC.Width_64.Value,
        Context_Type => Flyology_CRC.Width_64.Context,
        Start        => Flyology_CRC.Width_64.Start,
        Reset        => Flyology_CRC.Width_64.Reset,
        Update       => Flyology_CRC.Width_64.Update,
        Result       => Flyology_CRC.Width_64.Result);

   procedure Test_16 (Sample : Flyology_CRC.Byte_Array) is
   begin
      for Kind in Flyology_CRC.Width_16.Algorithm loop
         declare
            ID : constant CRC_Fast_Oracle.Algorithm_ID :=
              CRC_Fast_Oracle.Algorithm_ID
                (CRC16_ID_Offset + Flyology_CRC.Width_16.Algorithm'Pos (Kind));
            Split : constant Ada.Streams.Stream_Element_Offset :=
              Sample'First + Ada.Streams.Stream_Element_Offset (Sample'Length / 2) - 1;
            Left_Data  : Flyology_CRC.Byte_Array renames Sample (Sample'First .. Split);
            Right_Data : Flyology_CRC.Byte_Array renames Sample (Split + 1 .. Sample'Last);
            Left : constant Flyology_CRC.Width_16.Value :=
              Flyology_CRC.Width_16.Compute (Kind, Left_Data);
            Right : constant Flyology_CRC.Width_16.Value :=
              Flyology_CRC.Width_16.Compute (Kind, Right_Data);
            Ada_Result : constant Flyology_CRC.Width_16.Value :=
              Flyology_CRC.Width_16.Compute (Kind, Sample);
            Rust_Result : constant CRC_Fast_Oracle.Value_64 :=
              CRC_Fast_Oracle.Checksum (ID, Sample);
         begin
            Check
              (CRC_Fast_Oracle.Value_64 (Ada_Result) = Rust_Result,
               "CRC-16/" & Kind'Image & " length" & Sample'Length'Image);
            Check_Streaming_16
              (Kind,
               Sample,
               Flyology_CRC.Width_16.Value (Rust_Result),
               "CRC-16/" & Kind'Image);
            Check
              (CRC_Fast_Oracle.Value_64
                 (Flyology_CRC.Width_16.Combine
                    (Kind, Left, Right, Flyology_CRC.Byte_Count (Right_Data'Length))) =
                 CRC_Fast_Oracle.Combine
                   (ID,
                    CRC_Fast_Oracle.Value_64 (Left),
                    CRC_Fast_Oracle.Value_64 (Right),
                    Flyology_CRC.Byte_Count (Right_Data'Length)),
               "combine CRC-16/" & Kind'Image & " length" & Sample'Length'Image);
         end;
      end loop;
   end Test_16;

   procedure Test_32 (Sample : Flyology_CRC.Byte_Array) is
      use type Flyology_CRC.Width_32.Value;
   begin
      for Kind in Flyology_CRC.Width_32.Algorithm loop
         declare
            ID : constant CRC_Fast_Oracle.Algorithm_ID :=
              CRC_Fast_Oracle.Algorithm_ID
                (CRC32_ID_Offset + Flyology_CRC.Width_32.Algorithm'Pos (Kind));
            Split : constant Ada.Streams.Stream_Element_Offset :=
              Sample'First + Ada.Streams.Stream_Element_Offset (Sample'Length / 2) - 1;
            Left_Data  : Flyology_CRC.Byte_Array renames Sample (Sample'First .. Split);
            Right_Data : Flyology_CRC.Byte_Array renames Sample (Split + 1 .. Sample'Last);
            Left : constant Flyology_CRC.Width_32.Value :=
              Flyology_CRC.Width_32.Compute (Kind, Left_Data);
            Right : constant Flyology_CRC.Width_32.Value :=
              Flyology_CRC.Width_32.Compute (Kind, Right_Data);
            Ada_Result : constant Flyology_CRC.Width_32.Value :=
              Flyology_CRC.Width_32.Compute (Kind, Sample);
            Rust_Result : constant CRC_Fast_Oracle.Value_64 :=
              CRC_Fast_Oracle.Checksum (ID, Sample);
         begin
            Check
              (CRC_Fast_Oracle.Value_64 (Ada_Result) = Rust_Result,
               "CRC-32/" & Kind'Image & " length" & Sample'Length'Image);
            Check_Streaming_32
              (Kind,
               Sample,
               Flyology_CRC.Width_32.Value (Rust_Result),
               "CRC-32/" & Kind'Image);
            Check
              (CRC_Fast_Oracle.Value_64
                 (Flyology_CRC.Width_32.Combine
                    (Kind, Left, Right, Flyology_CRC.Byte_Count (Right_Data'Length))) =
                 CRC_Fast_Oracle.Combine
                   (ID,
                    CRC_Fast_Oracle.Value_64 (Left),
                    CRC_Fast_Oracle.Value_64 (Right),
                    Flyology_CRC.Byte_Count (Right_Data'Length)),
               "combine CRC-32/" & Kind'Image & " length" & Sample'Length'Image);
         end;
      end loop;

      Check
        (Flyology_CRC.Width_32.Compute_ISCSI (Sample) = CRC_Fast_Oracle.CRC32_ISCSI (Sample),
         "specialized CRC-32/ISCSI length" & Sample'Length'Image);
      Check
        (Flyology_CRC.Width_32.Compute_ISO_HDLC (Sample) =
           CRC_Fast_Oracle.CRC32_ISO_HDLC (Sample),
         "specialized CRC-32/ISO-HDLC length" & Sample'Length'Image);
   end Test_32;

   procedure Test_64 (Sample : Flyology_CRC.Byte_Array) is
   begin
      for Kind in Flyology_CRC.Width_64.Algorithm loop
         declare
            ID : constant CRC_Fast_Oracle.Algorithm_ID :=
              CRC_Fast_Oracle.Algorithm_ID
                (CRC64_ID_Offset + Flyology_CRC.Width_64.Algorithm'Pos (Kind));
            Split : constant Ada.Streams.Stream_Element_Offset :=
              Sample'First + Ada.Streams.Stream_Element_Offset (Sample'Length / 2) - 1;
            Left_Data  : Flyology_CRC.Byte_Array renames Sample (Sample'First .. Split);
            Right_Data : Flyology_CRC.Byte_Array renames Sample (Split + 1 .. Sample'Last);
            Left : constant Flyology_CRC.Width_64.Value :=
              Flyology_CRC.Width_64.Compute (Kind, Left_Data);
            Right : constant Flyology_CRC.Width_64.Value :=
              Flyology_CRC.Width_64.Compute (Kind, Right_Data);
            Ada_Result : constant Flyology_CRC.Width_64.Value :=
              Flyology_CRC.Width_64.Compute (Kind, Sample);
            Rust_Result : constant CRC_Fast_Oracle.Value_64 :=
              CRC_Fast_Oracle.Checksum (ID, Sample);
         begin
            Check
              (Ada_Result = Rust_Result,
               "CRC-64/" & Kind'Image & " length" & Sample'Length'Image);
            Check_Streaming_64
              (Kind,
               Sample,
               Flyology_CRC.Width_64.Value (Rust_Result),
               "CRC-64/" & Kind'Image);
            Check
              (Flyology_CRC.Width_64.Combine
                 (Kind, Left, Right, Flyology_CRC.Byte_Count (Right_Data'Length)) =
                 CRC_Fast_Oracle.Combine
                   (ID,
                    CRC_Fast_Oracle.Value_64 (Left),
                    CRC_Fast_Oracle.Value_64 (Right),
                    Flyology_CRC.Byte_Count (Right_Data'Length)),
               "combine CRC-64/" & Kind'Image & " length" & Sample'Length'Image);
         end;
      end loop;

      Check
        (Flyology_CRC.Width_64.Compute_NVME (Sample) = CRC_Fast_Oracle.CRC64_NVME (Sample),
         "specialized CRC-64/NVME length" & Sample'Length'Image);
   end Test_64;

   procedure Test_Custom_16
     (Sample        : Flyology_CRC.Byte_Array;
      Polynomial    : Flyology_CRC.Width_16.Value;
      Initial_Value : Flyology_CRC.Width_16.Value;
      Reflected     : Boolean;
      Final_XOR     : Flyology_CRC.Width_16.Value;
      Name          : String) is
      Configuration : constant Flyology_CRC.Width_16.Parameters :=
        Flyology_CRC.Width_16.Create
          (Polynomial, Initial_Value, Reflected, Final_XOR);
      Expected : constant CRC_Fast_Oracle.Value_64 :=
        CRC_Fast_Oracle.Checksum_Custom
          (16,
           CRC_Fast_Oracle.Value_64 (Polynomial),
           CRC_Fast_Oracle.Value_64 (Initial_Value),
           Reflected,
           CRC_Fast_Oracle.Value_64 (Final_XOR),
           Sample);
   begin
      Check
        (CRC_Fast_Oracle.Value_64
           (Flyology_CRC.Width_16.Compute (Configuration, Sample)) = Expected,
         Name & " one-shot length" & Sample'Length'Image & " first" & Sample'First'Image);
      Check_Custom_Streaming_16
        (Configuration, Sample, Flyology_CRC.Width_16.Value (Expected), Name);
   end Test_Custom_16;

   procedure Test_Custom_32
     (Sample        : Flyology_CRC.Byte_Array;
      Polynomial    : Flyology_CRC.Width_32.Value;
      Initial_Value : Flyology_CRC.Width_32.Value;
      Reflected     : Boolean;
      Final_XOR     : Flyology_CRC.Width_32.Value;
      Name          : String) is
      Configuration : constant Flyology_CRC.Width_32.Parameters :=
        Flyology_CRC.Width_32.Create
          (Polynomial, Initial_Value, Reflected, Final_XOR);
      Expected : constant CRC_Fast_Oracle.Value_64 :=
        CRC_Fast_Oracle.Checksum_Custom
          (32,
           CRC_Fast_Oracle.Value_64 (Polynomial),
           CRC_Fast_Oracle.Value_64 (Initial_Value),
           Reflected,
           CRC_Fast_Oracle.Value_64 (Final_XOR),
           Sample);
   begin
      Check
        (CRC_Fast_Oracle.Value_64
           (Flyology_CRC.Width_32.Compute (Configuration, Sample)) = Expected,
         Name & " one-shot length" & Sample'Length'Image & " first" & Sample'First'Image);
      Check_Custom_Streaming_32
        (Configuration, Sample, Flyology_CRC.Width_32.Value (Expected), Name);
   end Test_Custom_32;

   procedure Test_Custom_64
     (Sample        : Flyology_CRC.Byte_Array;
      Polynomial    : Flyology_CRC.Width_64.Value;
      Initial_Value : Flyology_CRC.Width_64.Value;
      Reflected     : Boolean;
      Final_XOR     : Flyology_CRC.Width_64.Value;
      Name          : String) is
      Configuration : constant Flyology_CRC.Width_64.Parameters :=
        Flyology_CRC.Width_64.Create
          (Polynomial, Initial_Value, Reflected, Final_XOR);
      Expected : constant CRC_Fast_Oracle.Value_64 :=
        CRC_Fast_Oracle.Checksum_Custom
          (64, Polynomial, Initial_Value, Reflected, Final_XOR, Sample);
   begin
      Check
        (Flyology_CRC.Width_64.Compute (Configuration, Sample) = Expected,
         Name & " one-shot length" & Sample'Length'Image & " first" & Sample'First'Image);
      Check_Custom_Streaming_64
        (Configuration, Sample, Flyology_CRC.Width_64.Value (Expected), Name);
   end Test_Custom_64;

   procedure Test_All (Payload : Flyology_CRC.Byte_Array) is
   begin
      for Length of Lengths loop
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Payload'First + Ada.Streams.Stream_Element_Offset (Length) - 1;
            Sample : Flyology_CRC.Byte_Array renames Payload (Payload'First .. Last);
         begin
            Test_16 (Sample);
            Test_32 (Sample);
            Test_64 (Sample);
            Test_Custom_16
              (Sample, 16#1021#, 16#C6C6#, True, 0, "custom reflected CRC-16");
            Test_Custom_16
              (Sample, 16#1021#, 16#1D0F#, False, 16#FFFF#, "custom forward CRC-16");
            Test_Custom_32
              (Sample,
               16#04C11DB7#,
               16#12345678#,
               True,
               16#89ABCDEF#,
               "custom reflected CRC-32");
            Test_Custom_32
              (Sample,
               16#1EDC6F41#,
               16#A5A5A5A5#,
               False,
               16#5A5A5A5A#,
               "custom forward CRC-32");
            Test_Custom_64
              (Sample,
               16#42F0E1EBA9EA3693#,
               0,
               False,
               0,
               "custom forward CRC-64");
            Test_Custom_64
              (Sample,
               16#42F0E1EBA9EA3693#,
               16#0123456789ABCDEF#,
               True,
               16#FEDCBA9876543210#,
               "custom reflected CRC-64");
         end;
      end loop;
   end Test_All;

   procedure Initialize (Payload : in out Flyology_CRC.Byte_Array) is
   begin
      for Index in Payload'Range loop
         Payload (Index) :=
           Flyology_CRC.Byte
             ((Natural (Index - Payload'First) * 131 + 17) mod 256);
      end loop;
   end Initialize;

   procedure Test_Benchmark_Bridge is
      Empty : Flyology_CRC.Byte_Array renames
        Zero_Payload (Zero_Payload'First .. Zero_Payload'First - 1);
      Check_Data : constant Flyology_CRC.Byte_Array (1 .. 9) :=
        [16#31#, 16#32#, 16#33#, 16#34#, 16#35#,
         16#36#, 16#37#, 16#38#, 16#39#];
   begin
      for Raw_ID in 0 .. 49 loop
         declare
            ID : constant CRC_Fast_Oracle.Algorithm_ID :=
              CRC_Fast_Oracle.Algorithm_ID (Raw_ID);
            First_Handle : constant CRC_Fast_Oracle.Benchmark_Handle :=
              CRC_Fast_Oracle.Prepare_Benchmark (ID);
            Second_Handle : constant CRC_Fast_Oracle.Benchmark_Handle :=
              CRC_Fast_Oracle.Prepare_Benchmark (ID);
         begin
            Check
              (First_Handle /= System.Null_Address,
               "benchmark handle non-null ID" & Raw_ID'Image);
            Check
              (First_Handle = Second_Handle,
               "benchmark handle stable ID" & Raw_ID'Image);
            Check
              (CRC_Fast_Oracle.Benchmark_Checksum (First_Handle, Empty) =
                 CRC_Fast_Oracle.Checksum (ID, Empty),
               "benchmark empty checksum ID" & Raw_ID'Image);
            Check
              (CRC_Fast_Oracle.Benchmark_Checksum (First_Handle, Check_Data) =
                 CRC_Fast_Oracle.Checksum (ID, Check_Data),
               "benchmark 123456789 checksum ID" & Raw_ID'Image);
         end;
      end loop;

      declare
         Raised : Boolean := False;
      begin
         begin
            declare
               Unexpected : constant CRC_Fast_Oracle.Benchmark_Handle :=
                 CRC_Fast_Oracle.Prepare_Benchmark (50);
               pragma Unreferenced (Unexpected);
            begin
               null;
            end;
         exception
            when Program_Error =>
               Raised := True;
         end;
         Check (Raised, "benchmark bridge rejects invalid algorithm ID");
      end;
   end Test_Benchmark_Bridge;
begin
   Flyology_CRC.Folding_Key_Tests.Run;

   Initialize (Zero_Payload);
   Initialize (Positive_Payload);
   Initialize (Negative_Payload);
   Test_Benchmark_Bridge;
   Test_All (Zero_Payload);
   Test_All (Positive_Payload);
   Test_All (Negative_Payload);

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " Rust oracle tests failed";
   end if;

   Ada.Text_IO.Put_Line ("All Flyology CRC Rust-oracle tests passed");
end Rust_Oracle_Tests;
