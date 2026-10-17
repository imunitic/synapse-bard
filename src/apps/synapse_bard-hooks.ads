with Ada.Strings.Unbounded;

with Synapse.Core.Text_Lists;
with Synapse.Ports.Console;
with Synapse.Ports.Variables;

--  The hooks of the `synapse-bard-hook` executable, run by Claude Code, Codex
--  and OpenCode on the events of a session. Each is a procedure of an
--  Environment: what it reads and writes is passed in, so a hook is tested by
--  running it and looking at what it wrote.
--
--  A hook never fails a turn. Every missing precondition ends it silently and
--  its exit code is 0; a hook that errors interrupts a turn about something
--  the user usually cannot act on.

package Synapse_Bard.Hooks is

   --  0 for success, 2 for a usage error (no hook, or an unknown one).
   subtype Exit_Code is Natural range 0 .. 255;

   subtype Arguments is Synapse.Core.Text_Lists.Vector;

   type Environment
     (Console : not null access Synapse.Ports.Console.Console'Class;
      Vars    : not null access Synapse.Ports.Variables.Variables'Class) is
   limited record
      --  The directory the hook was started in, absolute.
      Start : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Synapse_Bard.Hooks;
