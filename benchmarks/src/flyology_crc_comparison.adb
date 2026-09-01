with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Streams;
with Ada.Text_IO;
with CRC_Fast_Oracle;
with Flyology_Bench;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Interfaces;
with System;
with System.Storage_Elements;

procedure Flyology_CRC_Comparison is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;
   use type System.Storage_Elements.Integer_Address;

   --  These offsets are fixed by oracle/rust/src/lib.rs and the approved
   --  concatenation of the CRC-16, CRC-32, and CRC-64 enumerations.
   CRC16_ID_Offset : constant := 0;
   CRC32_ID_Offset : constant := 31;
   CRC64_ID_Offset : constant := 43;

   --  The shared alignment covers the widest native load used by either
   --  implementation. Both sides receive the same slice address and length.
   Maximum_Length : constant := 1_048_576;
   Buffer         : Flyology_CRC.Byte_Array (0 .. Maximum_Length - 1)
   with Alignment => 64;
   Current_16     : Flyology_CRC.Width_16.Algorithm := Flyology_CRC.Width_16.Algorithm'First;
   Current_32     : Flyology_CRC.Width_32.Algorithm := Flyology_CRC.Width_32.Algorithm'First;
   Current_64     : Flyology_CRC.Width_64.Algorithm := Flyology_CRC.Width_64.Algorithm'First;
   Current_Handle : CRC_Fast_Oracle.Benchmark_Handle := System.Null_Address;
   Current_Length : Positive := 1_024;
   Lengths        : constant array (Positive range <>) of Positive := (1_024, 1_048_576);

   procedure Consume is new Flyology_Bench.Do_Not_Optimize (Interfaces.Unsigned_64);

   function Rust_Checksum return Interfaces.Unsigned_64 is
      Last : constant Ada.Streams.Stream_Element_Offset :=
        Buffer'First + Ada.Streams.Stream_Element_Offset (Current_Length) - 1;
      Data : Flyology_CRC.Byte_Array renames Buffer (Buffer'First .. Last);
   begin
      return CRC_Fast_Oracle.Benchmark_Checksum (Current_Handle, Data);
   end Rust_Checksum;

   function Ada_Checksum_16 return Interfaces.Unsigned_64 is
      Last : constant Ada.Streams.Stream_Element_Offset :=
        Buffer'First + Ada.Streams.Stream_Element_Offset (Current_Length) - 1;
      Data : Flyology_CRC.Byte_Array renames Buffer (Buffer'First .. Last);
   begin
      return Interfaces.Unsigned_64 (Flyology_CRC.Width_16.Compute (Current_16, Data));
   end Ada_Checksum_16;

   function Ada_Checksum_32 return Interfaces.Unsigned_64 is
      Last : constant Ada.Streams.Stream_Element_Offset :=
        Buffer'First + Ada.Streams.Stream_Element_Offset (Current_Length) - 1;
      Data : Flyology_CRC.Byte_Array renames Buffer (Buffer'First .. Last);
   begin
      return Interfaces.Unsigned_64 (Flyology_CRC.Width_32.Compute (Current_32, Data));
   end Ada_Checksum_32;

   function Ada_Checksum_64 return Interfaces.Unsigned_64 is
      Last : constant Ada.Streams.Stream_Element_Offset :=
        Buffer'First + Ada.Streams.Stream_Element_Offset (Current_Length) - 1;
      Data : Flyology_CRC.Byte_Array renames Buffer (Buffer'First .. Last);
   begin
      return Flyology_CRC.Width_64.Compute (Current_64, Data);
   end Ada_Checksum_64;

   procedure Reference_Batch (Iterations : Flyology_Bench.Iteration_Count) is
      Accumulator : Interfaces.Unsigned_64 := 0;
   begin
      for Iteration in 1 .. Iterations loop
         Accumulator := Accumulator xor Rust_Checksum;
      end loop;
      Consume (Accumulator);
   end Reference_Batch;

   procedure Contender_Batch_16 (Iterations : Flyology_Bench.Iteration_Count) is
      Accumulator : Interfaces.Unsigned_64 := 0;
   begin
      for Iteration in 1 .. Iterations loop
         Accumulator := Accumulator xor Ada_Checksum_16;
      end loop;
      Consume (Accumulator);
   end Contender_Batch_16;

   procedure Contender_Batch_32 (Iterations : Flyology_Bench.Iteration_Count) is
      Accumulator : Interfaces.Unsigned_64 := 0;
   begin
      for Iteration in 1 .. Iterations loop
         Accumulator := Accumulator xor Ada_Checksum_32;
      end loop;
      Consume (Accumulator);
   end Contender_Batch_32;

   procedure Contender_Batch_64 (Iterations : Flyology_Bench.Iteration_Count) is
      Accumulator : Interfaces.Unsigned_64 := 0;
   begin
      for Iteration in 1 .. Iterations loop
         Accumulator := Accumulator xor Ada_Checksum_64;
      end loop;
      Consume (Accumulator);
   end Contender_Batch_64;

   procedure Compare_16 is new Flyology_Bench.Compare_Batched (Reference_Batch, Contender_Batch_16);
   procedure Compare_32 is new Flyology_Bench.Compare_Batched (Reference_Batch, Contender_Batch_32);
   procedure Compare_64 is new Flyology_Bench.Compare_Batched (Reference_Batch, Contender_Batch_64);

   Configuration : Flyology_Bench.Configuration := Flyology_Bench.Default_Configuration;
   CSV           : Ada.Text_IO.File_Type;

   function Selected (Name : String) return Boolean is
     (Ada.Command_Line.Argument_Count < 2
      or else Ada.Strings.Fixed.Index
        (Name, Ada.Command_Line.Argument (2)) /= 0);

   function Selected (Length : Positive) return Boolean is
     (Ada.Command_Line.Argument_Count < 3
      or else Positive'Value (Ada.Command_Line.Argument (3)) = Length);

   procedure Report (Name : String; Result : Flyology_Bench.Comparison) is
      Reference : constant Flyology_Bench.Measurement :=
        Flyology_Bench.Reference_Measurement (Result);
      Contender : constant Flyology_Bench.Measurement :=
        Flyology_Bench.Contender_Measurement (Result);
   begin
      Ada.Text_IO.Put_Line
        (Name & " bytes=" & Current_Length'Image &
         " Ada speedup=" & Long_Float'Image (Flyology_Bench.Geometric_Mean_Speedup (Result)) &
         " CI=[" & Long_Float'Image (Flyology_Bench.Speedup_Confidence_Low (Result)) &
         "," & Long_Float'Image (Flyology_Bench.Speedup_Confidence_High (Result)) & "]" &
         " verdict=" & Flyology_Bench.Comparison_Verdict'Image (Flyology_Bench.Verdict (Result)));

      for Sample in 1 .. Flyology_Bench.Samples (Reference) loop
         Ada.Text_IO.Put_Line
           (CSV,
            Name & "," &
            Current_Length'Image & "," &
            Sample'Image & "," &
            Long_Float'Image (Flyology_Bench.Sample_Nanoseconds (Reference, Sample)) & "," &
            Long_Float'Image (Flyology_Bench.Sample_Nanoseconds (Contender, Sample)) & "," &
            Long_Float'Image (Flyology_Bench.Sample_Speedup (Result, Sample)));
      end loop;
      Ada.Text_IO.Flush (CSV);
   end Report;

   procedure Run (Kind : Flyology_CRC.Width_16.Algorithm) is
      ID : constant CRC_Fast_Oracle.Algorithm_ID :=
        CRC_Fast_Oracle.Algorithm_ID (CRC16_ID_Offset + Flyology_CRC.Width_16.Algorithm'Pos (Kind));
      Name   : constant String := "CRC-16/" & Kind'Image;
      Result : Flyology_Bench.Comparison;
   begin
      if not Selected (Name) then
         return;
      end if;
      Current_16 := Kind;
      Current_Handle := CRC_Fast_Oracle.Prepare_Benchmark (ID);
      if Rust_Checksum /= Ada_Checksum_16 then
         raise Program_Error with Name & " correctness mismatch before timing";
      end if;
      Compare_16 (Configuration, Result);
      Report (Name, Result);
   end Run;

   procedure Run (Kind : Flyology_CRC.Width_32.Algorithm) is
      ID : constant CRC_Fast_Oracle.Algorithm_ID :=
        CRC_Fast_Oracle.Algorithm_ID (CRC32_ID_Offset + Flyology_CRC.Width_32.Algorithm'Pos (Kind));
      Name   : constant String := "CRC-32/" & Kind'Image;
      Result : Flyology_Bench.Comparison;
   begin
      if not Selected (Name) then
         return;
      end if;
      Current_32 := Kind;
      Current_Handle := CRC_Fast_Oracle.Prepare_Benchmark (ID);
      if Rust_Checksum /= Ada_Checksum_32 then
         raise Program_Error with Name & " correctness mismatch before timing";
      end if;
      Compare_32 (Configuration, Result);
      Report (Name, Result);
   end Run;

   procedure Run (Kind : Flyology_CRC.Width_64.Algorithm) is
      ID : constant CRC_Fast_Oracle.Algorithm_ID :=
        CRC_Fast_Oracle.Algorithm_ID (CRC64_ID_Offset + Flyology_CRC.Width_64.Algorithm'Pos (Kind));
      Name   : constant String := "CRC-64/" & Kind'Image;
      Result : Flyology_Bench.Comparison;
   begin
      if not Selected (Name) then
         return;
      end if;
      Current_64 := Kind;
      Current_Handle := CRC_Fast_Oracle.Prepare_Benchmark (ID);
      if Rust_Checksum /= Ada_Checksum_64 then
         raise Program_Error with Name & " correctness mismatch before timing";
      end if;
      Compare_64 (Configuration, Result);
      Report (Name, Result);
   end Run;
begin
   if Ada.Command_Line.Argument_Count not in 1 .. 3 then
      raise Program_Error with
        "usage: flyology_crc_comparison RAW_SAMPLES.csv [NAME_FILTER [BYTES]]";
   end if;

   if System.Storage_Elements.To_Integer (Buffer'Address) mod 64 /= 0 then
      raise Program_Error with "benchmark buffer is not 64-byte aligned";
   end if;
   Ada.Text_IO.Put_Line
     ("buffer_address=" &
      System.Storage_Elements.Integer_Address'Image
        (System.Storage_Elements.To_Integer (Buffer'Address)) &
      " alignment=64");

   for Index in Buffer'Range loop
      Buffer (Index) := Flyology_CRC.Byte ((Natural (Index) * 131 + 17) mod 256);
   end loop;

   Configuration.Warmup_Time := 0.100;
   Configuration.Measurement_Time := 0.500;
   Configuration.Maximum_Sampling_Time := 30.0;
   Configuration.Samples := 1_000;
   Configuration.Minimum_Sample_Time := 0.000_100;
   Configuration.Comparison_Batching := Flyology_Bench.Equal_Time;
   --  The user-approved gate is exact parity: intervals below 1.0 fail.
   Configuration.Practical_Threshold_Percent := 0.0;
   Configuration.Confidence_Level_Percent := 95.0;
   Configuration.Bootstrap_Resamples := 2_000;

   Ada.Text_IO.Create (CSV, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (1));
   Ada.Text_IO.Put_Line
     (CSV, "algorithm,bytes,sample,reference_crc_fast_ns,contender_flyology_crc_ns,speedup");

   for Length of Lengths loop
      if Selected (Length) then
         Current_Length := Length;
         for Kind in Flyology_CRC.Width_16.Algorithm loop
            Run (Kind);
         end loop;
         for Kind in Flyology_CRC.Width_32.Algorithm loop
            Run (Kind);
         end loop;
         for Kind in Flyology_CRC.Width_64.Algorithm loop
            Run (Kind);
         end loop;
      end if;
   end loop;

   Ada.Text_IO.Close (CSV);
end Flyology_CRC_Comparison;
