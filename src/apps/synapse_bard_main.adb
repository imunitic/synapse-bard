with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Synapse.Adapters.System_Console;
with Synapse.Adapters.System_Variables;
with Synapse.Core.Text_Lists;

with Synapse_Bard.Commands.Dispatch;

--  The `synapse-bard` executable: the subcommands over the real console.

procedure Synapse_Bard_Main is
   Console : aliased Synapse.Adapters.System_Console.System_Console;
   Vars    : aliased Synapse.Adapters.System_Variables.System_Variables;
   Env     : constant Synapse_Bard.Commands.Environment :=
     (Console => Console'Access, Vars => Vars'Access,
      Start   =>
        Ada.Strings.Unbounded.To_Unbounded_String
          (Ada.Directories.Current_Directory));
   Args    : Synapse_Bard.Commands.Arguments;
begin
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      Args.Append
        (Ada.Strings.Unbounded.To_Unbounded_String
           (Ada.Command_Line.Argument (I)));
   end loop;
   Ada.Command_Line.Set_Exit_Status
     (Ada.Command_Line.Exit_Status
        (Synapse_Bard.Commands.Dispatch.Run (Env, Args)));
end Synapse_Bard_Main;
