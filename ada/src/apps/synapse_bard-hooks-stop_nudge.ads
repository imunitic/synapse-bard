with Synapse.Core.Optional_Text;

--  The `stop-nudge` hook: Stop. Every 25 turns it asks for a check-in on
--  whether something worth keeping in the Writer's notes vault came up. The
--  session-start hook raises that only once, at the start of a session; nothing
--  else would raise it again for the rest of a long one. The nudge is
--  `additionalContext`, not a blocking decision, since the command line labels
--  the former as feedback and not as an error.
--
--  Silent in a repository without `_bard/`, like `session-start`.

package Synapse_Bard.Hooks.Stop_Nudge is

   --  Turns between check-ins.
   Interval : constant := 25;

   --  The heading of `synapse-bard-claude.md` the nudge points to, named once
   --  so a test can check that it still exists.
   Vault_Note_Heading : constant String :=
     "The Writer's notes vault as permanent memory";

   procedure Run (Env : Environment);

   type Tick is record
      --  The nudge, when this call just re-armed.
      Text  : Synapse.Core.Optional_Text.Option;
      --  The turns counted for this session, across every call.
      Total : Natural;
   end record;

   --  Advances the turn counters of Session, which live under
   --  `Home/.claude/state`, and says whether a check-in is due. A counter that
   --  is missing is 0; an unreadable or corrupt one restarts from 0, and one
   --  that cannot be written is reported, with a message on standard error
   --  and no failure.
   function Advance
     (Env : Environment; Home, Session : String) return Tick;

end Synapse_Bard.Hooks.Stop_Nudge;
