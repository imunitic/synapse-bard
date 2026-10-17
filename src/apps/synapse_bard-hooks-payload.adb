with Ada.Strings.Unbounded;

package body Synapse_Bard.Hooks.Payload is

   package JSON renames Synapse.Core.JSON;

   use type JSON.Kind;

   Largest_Payload : constant := 16 * 2**20;

   function Parse (Text : String) return Payload is
   begin
      if Text'Length = 0 or else Text'Length > Largest_Payload then
         return (Present => False);
      end if;
      declare
         Parsed : constant JSON.Parse_Result := JSON.Parse (Text);
      begin
         if Parsed.Ok then
            return (Present => True, Item => Parsed.Item);
         end if;
         return (Present => False);
      end;
   end Parse;

   function Read (Env : Environment) return Payload is
     (Parse (Env.Console.Read_Stdin));

   function Str (P : Payload; Key : String) return Maybe_Text is
   begin
      if not P.Present or else JSON.Kind_Of (P.Item) /= JSON.JSON_Object
        or else not JSON.Has_Member (P.Item, Key)
      then
         return Synapse.Core.Optional_Text.None;
      end if;
      declare
         Member : constant JSON.Value := JSON.Member_Value (P.Item, Key);
      begin
         if JSON.Kind_Of (Member) /= JSON.JSON_String
           or else JSON.As_String (Member)'Length = 0
         then
            return Synapse.Core.Optional_Text.None;
         end if;
         return Synapse.Core.Optional_Text.Of_Value
           (Ada.Strings.Unbounded.To_Unbounded_String
              (JSON.As_String (Member)));
      end;
   end Str;

end Synapse_Bard.Hooks.Payload;
