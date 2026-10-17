with Synapse.Core.JSON;
with Synapse.Core.Optional_Text;

--  The JSON a hook is given on standard input. Only top-level string members
--  are read.

package Synapse_Bard.Hooks.Payload is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   type Payload is private;

   --  Standard input of the environment's console, as a payload. Empty or
   --  malformed input, and input over 16 MiB, is no payload.
   function Read (Env : Environment) return Payload;

   function Parse (Text : String) return Payload;

   --  A top-level string member; nothing when it is absent, not a string, or
   --  empty.
   function Str (P : Payload; Key : String) return Maybe_Text;

private

   type Payload (Present : Boolean := False) is record
      case Present is
         when True =>
            Item : Synapse.Core.JSON.Value;

         when False =>
            null;
      end case;
   end record;

end Synapse_Bard.Hooks.Payload;
