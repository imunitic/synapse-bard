with Ada.Strings.Unbounded;

package body Synapse_Bard.Hooks.Output is

   use Ada.Strings.Unbounded;

   Hex : constant String := "0123456789abcdef";

   function Json_String (Text : String) return String is
      Result : Unbounded_String;
   begin
      Append (Result, '"');
      for C of Text loop
         case C is
            when '"' =>
               Append (Result, "\""");

            when '\' =>
               Append (Result, "\\");

            when Character'Val (10) =>
               Append (Result, "\n");

            when Character'Val (13) =>
               Append (Result, "\r");

            when Character'Val (9) =>
               Append (Result, "\t");

            when others =>
               if Character'Pos (C) < 16#20# then
                  Append
                    (Result,
                     "\u00" & Hex (Character'Pos (C) / 16 + 1)
                     & Hex (Character'Pos (C) mod 16 + 1));
               else
                  Append (Result, C);
               end if;
         end case;
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Json_String;

   procedure Emit_Context (Env : Environment; Event, Text : String) is
   begin
      if Text'Length = 0 then
         return;
      end if;
      Env.Console.Write_Out
        ("{""hookSpecificOutput"":{""hookEventName"":" & Json_String (Event)
         & ",""additionalContext"":" & Json_String (Text) & "}}"
         & Character'Val (10));
   end Emit_Context;

end Synapse_Bard.Hooks.Output;
