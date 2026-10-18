with Synapse_Bard.Syntax;

--  The usage text of the hook binary, as it prints it.

package Synapse_Bard.Hooks.Usage is

   LF : constant Character := Synapse_Bard.Syntax.LF;

   Main_Usage : constant String :=
     "usage: synapse-bard-hook <hook>" & LF & "" & LF &
     "  session-start    SessionStart: inject _bard/vault/" & "Index.md" &
     LF & "  stop-nudge       Stop: periodic ""worth writing to " &
     "the vault"" check-in" & LF;

end Synapse_Bard.Hooks.Usage;
