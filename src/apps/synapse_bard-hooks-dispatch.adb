with Ada.Strings.Unbounded;

with Synapse_Bard.Hooks.Session_Start;
with Synapse_Bard.Hooks.Stop_Nudge;
with Synapse_Bard.Hooks.Usage;

package body Synapse_Bard.Hooks.Dispatch is

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Env.Console.Write_Err (Usage.Main_Usage);
         return 2;
      end if;
      declare
         Which : constant String :=
           Ada.Strings.Unbounded.To_String (Args.First_Element);
      begin
         if Which in "-h" | "--help" then
            Env.Console.Write_Err (Usage.Main_Usage);
            return 0;
         elsif Which = "session-start" then
            Session_Start.Run (Env);
         elsif Which = "stop-nudge" then
            Stop_Nudge.Run (Env);
         else
            Env.Console.Write_Err
              ("synapse-bard-hook: unknown hook '" & Which & "'"
               & Character'Val (10) & Usage.Main_Usage);
            return 2;
         end if;
         return 0;
      exception
         --  A hook that errors interrupts a turn about something the user
         --  usually cannot act on: whatever goes wrong, exit 0.
         when others =>
            return 0;
      end;
   end Run;

end Synapse_Bard.Hooks.Dispatch;
