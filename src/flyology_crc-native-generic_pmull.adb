with Interfaces;

package body Flyology_CRC.Native.Generic_PMULL is
   package body Engine is
      function Update_Aligned_Blocks
        (State     : Value;
         Reflected : Boolean;
         Keys      : Folding_Keys;
         Data      : Byte_Array) return Value is
      begin
         case Width is
            when 16 =>
               return
                 Value
                   (Update_PMULL_16
                      (Interfaces.Unsigned_16 (State), Reflected, Keys, Data));
            when 32 =>
               return
                 Value
                   (Update_PMULL_32
                      (Interfaces.Unsigned_32 (State), Reflected, Keys, Data));
            when 64 =>
               return
                 Value
                   (Update_PMULL_64
                      (Interfaces.Unsigned_64 (State), Reflected, Keys, Data));
            when others =>
               raise Program_Error with "PMULL supports CRC widths 16, 32, and 64";
         end case;
      end Update_Aligned_Blocks;
   end Engine;
end Flyology_CRC.Native.Generic_PMULL;
