with Ada.Text_IO;
with Ada.Streams;
with Flyology_CRC.Width_16;
with Flyology_CRC.Width_32;
with Flyology_CRC.Width_64;
with Generated_CRC_Checks;

procedure Flyology_CRC_Tests is
   use type Ada.Streams.Stream_Element_Offset;
   use type Flyology_CRC.Width_16.Value;
   use type Flyology_CRC.Width_32.Value;
   use type Flyology_CRC.Width_64.Value;

   Data : constant Flyology_CRC.Byte_Array :=
     (1 => Character'Pos ('1'),
      2 => Character'Pos ('2'),
      3 => Character'Pos ('3'),
      4 => Character'Pos ('4'),
      5 => Character'Pos ('5'),
      6 => Character'Pos ('6'),
      7 => Character'Pos ('7'),
      8 => Character'Pos ('8'),
      9 => Character'Pos ('9'));

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAIL: " & Message);
      end if;
   end Check;

   procedure Test_16 is
      use Flyology_CRC.Width_16;
   begin
      for Kind in Algorithm loop
         declare
            Expected : constant Value := Generated_CRC_Checks.Check_16 (Kind);
         begin
            Check (Compute (Kind, Data) = Expected, "CRC-16/" & Kind'Image & " check vector");

            for Split in Data'First - 1 .. Data'Last loop
               declare
                  Object : Context := Start (Kind);
                  Left   : constant Value := Compute (Kind, Data (Data'First .. Split));
                  Right  : constant Value := Compute (Kind, Data (Split + 1 .. Data'Last));
               begin
                  Update (Object, Data (Data'First .. Split));
                  Check (Result (Object) = Result (Object), "CRC-16/" & Kind'Image & " stable result");
                  Update (Object, Data (Split + 1 .. Data'Last));
                  Check (Result (Object) = Expected, "CRC-16/" & Kind'Image & " streaming");
                  Check
                    (Combine
                       (Kind,
                        Left,
                        Right,
                        Flyology_CRC.Byte_Count (Data'Last - Split)) = Expected,
                     "CRC-16/" & Kind'Image & " combine");
                  Reset (Object);
                  Update (Object, Data);
                  Check (Result (Object) = Expected, "CRC-16/" & Kind'Image & " reset");
               end;
            end loop;
         end;
      end loop;

      Check
        (Compute
           (Create
              (Polynomial    => 16#1021#,
               Initial_Value => 16#FFFF#,
               Reflected     => False,
               Final_XOR     => 16#0000#),
            Data) = 16#29B1#,
         "custom CRC-16 parameters");

      declare
         Configuration : constant Parameters := Create (16#1021#, 16#FFFF#, False, 0);
         Original      : Context := Start (Configuration);
         Left          : constant Value := Compute (Configuration, Data (1 .. 4));
         Right         : constant Value := Compute (Configuration, Data (5 .. 9));
      begin
         Update (Original, Data (1 .. 4));
         declare
            Copy            : Context := Original;
            Original_Result : constant Value := Result (Original);
         begin
            Update (Copy, Data (5 .. 9));
            Check (Result (Copy) = 16#29B1#, "copied custom CRC-16 context");
            Check
              (Result (Original) = Original_Result,
               "copied custom CRC-16 context is independent");
            Check
              (Combine (Configuration, Left, Right, 5) = 16#29B1#,
               "custom CRC-16 combine");
         end;
      end;
   end Test_16;

   procedure Test_32 is
      use Flyology_CRC.Width_32;
   begin
      for Kind in Algorithm loop
         declare
            Expected : constant Value := Generated_CRC_Checks.Check_32 (Kind);
         begin
            Check (Compute (Kind, Data) = Expected, "CRC-32/" & Kind'Image & " check vector");

            for Split in Data'First - 1 .. Data'Last loop
               declare
                  Object : Context := Start (Kind);
                  Left   : constant Value := Compute (Kind, Data (Data'First .. Split));
                  Right  : constant Value := Compute (Kind, Data (Split + 1 .. Data'Last));
               begin
                  Update (Object, Data (Data'First .. Split));
                  Check (Result (Object) = Result (Object), "CRC-32/" & Kind'Image & " stable result");
                  Update (Object, Data (Split + 1 .. Data'Last));
                  Check (Result (Object) = Expected, "CRC-32/" & Kind'Image & " streaming");
                  Check
                    (Combine
                       (Kind,
                        Left,
                        Right,
                        Flyology_CRC.Byte_Count (Data'Last - Split)) = Expected,
                     "CRC-32/" & Kind'Image & " combine");
                  Reset (Object);
                  Update (Object, Data);
                  Check (Result (Object) = Expected, "CRC-32/" & Kind'Image & " reset");
               end;
            end loop;
         end;
      end loop;

      Check
        (Compute
           (Create
              (Polynomial    => 16#04C11DB7#,
               Initial_Value => 16#FFFFFFFF#,
               Reflected     => True,
               Final_XOR     => 16#FFFFFFFF#),
            Data) = 16#CBF43926#,
         "custom CRC-32 parameters");
      Check (Compute_ISCSI (Data) = Compute (ISCSI, Data), "CRC-32/ISCSI specialized helper");
      Check
        (Compute_ISO_HDLC (Data) = Compute (ISO_HDLC, Data),
         "CRC-32/ISO-HDLC specialized helper");

      declare
         Configuration : constant Parameters := Create (16#04C11DB7#, 16#FFFFFFFF#, True, 16#FFFFFFFF#);
         Original      : Context := Start (Configuration);
      begin
         Update (Original, Data (1 .. 4));
         declare
            Copy  : Context := Original;
            Left  : constant Value := Result (Original);
            Right : constant Value := Compute (Configuration, Data (5 .. 9));
         begin
            Update (Copy, Data (5 .. 9));
            Check (Result (Copy) = 16#CBF43926#, "copied custom CRC-32 context");
            Check
              (Result (Original) = Left,
               "copied custom CRC-32 context is independent");
            Check (Combine (Configuration, Left, Right, 5) = 16#CBF43926#, "custom CRC-32 combine");
         end;
      end;
   end Test_32;

   procedure Test_64 is
      use Flyology_CRC.Width_64;
   begin
      for Kind in Algorithm loop
         declare
            Expected : constant Value := Generated_CRC_Checks.Check_64 (Kind);
         begin
            Check (Compute (Kind, Data) = Expected, "CRC-64/" & Kind'Image & " check vector");

            for Split in Data'First - 1 .. Data'Last loop
               declare
                  Object : Context := Start (Kind);
                  Left   : constant Value := Compute (Kind, Data (Data'First .. Split));
                  Right  : constant Value := Compute (Kind, Data (Split + 1 .. Data'Last));
               begin
                  Update (Object, Data (Data'First .. Split));
                  Check (Result (Object) = Result (Object), "CRC-64/" & Kind'Image & " stable result");
                  Update (Object, Data (Split + 1 .. Data'Last));
                  Check (Result (Object) = Expected, "CRC-64/" & Kind'Image & " streaming");
                  Check
                    (Combine
                       (Kind,
                        Left,
                        Right,
                        Flyology_CRC.Byte_Count (Data'Last - Split)) = Expected,
                     "CRC-64/" & Kind'Image & " combine");
                  Reset (Object);
                  Update (Object, Data);
                  Check (Result (Object) = Expected, "CRC-64/" & Kind'Image & " reset");
               end;
            end loop;
         end;
      end loop;

      Check
        (Compute
           (Create
              (Polynomial    => 16#42F0E1EBA9EA3693#,
               Initial_Value => 16#0000000000000000#,
               Reflected     => False,
               Final_XOR     => 16#0000000000000000#),
            Data) = 16#6C40DF5F0B497347#,
         "custom CRC-64 parameters");
      Check (Compute_NVME (Data) = Compute (NVME, Data), "CRC-64/NVME specialized helper");

      declare
         Configuration : constant Parameters := Create (16#42F0E1EBA9EA3693#, 0, False, 0);
         Original      : Context := Start (Configuration);
         Left          : constant Value := Compute (Configuration, Data (1 .. 4));
         Right         : constant Value := Compute (Configuration, Data (5 .. 9));
      begin
         Update (Original, Data (1 .. 4));
         declare
            Copy            : Context := Original;
            Original_Result : constant Value := Result (Original);
         begin
            Update (Copy, Data (5 .. 9));
            Check
              (Result (Copy) = 16#6C40DF5F0B497347#,
               "copied custom CRC-64 context");
            Check
              (Result (Original) = Original_Result,
               "copied custom CRC-64 context is independent");
            Check
              (Combine (Configuration, Left, Right, 5) = 16#6C40DF5F0B497347#,
               "custom CRC-64 combine");
         end;
      end;
   end Test_64;
begin
   Test_16;
   Test_32;
   Test_64;

   if Failures /= 0 then
      raise Program_Error with Failures'Image & " CRC tests failed";
   end if;

   Ada.Text_IO.Put_Line ("All Flyology CRC tests passed");
end Flyology_CRC_Tests;
