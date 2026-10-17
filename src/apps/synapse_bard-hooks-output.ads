--  The one output shape the harnesses read.

package Synapse_Bard.Hooks.Output is

   --  A JSON string literal: `"` and `\` escaped, newline, carriage return and
   --  tab in their short forms, any other byte below 0x20 as `\u` and four
   --  lowercase hex digits, every other byte, UTF-8 included, as it is.
   function Json_String (Text : String) return String;

   --  `{"hookSpecificOutput":{"hookEventName":<event>,"additionalContext":
   --  <text>}}` and a line feed on standard output; nothing for an empty text.
   procedure Emit_Context (Env : Environment; Event, Text : String);

end Synapse_Bard.Hooks.Output;
