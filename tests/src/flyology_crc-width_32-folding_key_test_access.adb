package body Flyology_CRC.Width_32.Folding_Key_Test_Access is
   function Key_At (Configuration : Parameters; Index : Natural) return Interfaces.Unsigned_64 is
   begin
      return Configuration.Data.Keys (Folding_Key_Index (Index));
   end Key_At;
end Flyology_CRC.Width_32.Folding_Key_Test_Access;
