with Ada.Strings.Unbounded;

with Synapse_Bard.Syntax;

package body Synapse_Bard.Lines is

   function Split (Text : String) return Synapse.Core.Text_Lists.Vector is
      use Ada.Strings.Unbounded;
      Result : Synapse.Core.Text_Lists.Vector;
      Start  : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = Syntax.LF then
            declare
               Stop : constant Natural :=
                 (if I > Start and then Text (I - 1) = Syntax.CR then I - 2
                  else I - 1);
            begin
               Result.Append (To_Unbounded_String (Text (Start .. Stop)));
            end;
            Start := I + 1;
         end if;
      end loop;
      if Start <= Text'Last then
         Result.Append (To_Unbounded_String (Text (Start .. Text'Last)));
      end if;
      return Result;
   end Split;

end Synapse_Bard.Lines;
