with Ada.Strings.Unbounded;

with Synapse.Core.Text_Lists;
with Synapse.Ports.Console;
with Synapse.Ports.Variables;

--  The subcommands of the `synapse-bard` executable. Each is a function of an
--  Environment and its arguments: what it may write is passed in, so a command
--  is tested by calling it and looking at what it printed and what it
--  returned.
--
--  The contract is frozen. What a command writes, to which stream, and the
--  code it returns are what the skills, hooks and documented reference of the
--  tool already depend on, and change only with a change about the command
--  line itself.

package Synapse_Bard.Commands is

   --  0 for success, 1 for a failure the command explains, 2 for a usage
   --  error.
   subtype Exit_Code is Natural range 0 .. 255;

   subtype Arguments is Synapse.Core.Text_Lists.Vector;

   type Environment
     (Console : not null access Synapse.Ports.Console.Console'Class;
      Vars    : not null access Synapse.Ports.Variables.Variables'Class) is
   limited record
      --  The directory the command was started in, absolute.
      Start : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Synapse_Bard.Commands;
