--  The starter index `sync` seeds into an empty `_bard/vault/`: the text of
--  `packages/synapse-bard/Index.md.template`, which a test keeps identical.

package Synapse_Bard.Vault_Index_Template is

   LF : constant Character := Character'Val (10);

   Text : constant String :=
     "---" & LF & "title: ""Index""" & LF & "---" & LF & LF & "# Index" &
     LF & "Map of the Writer's notes vault (`_bard/vault/`) fol" &
     "ders and what each is for -- plain markdown" & LF &
     "files, git-tracked in this repo, read and written wi" &
     "th ordinary Read/Write/Edit/Glob/Grep. See the" & LF &
     "`synapse-bard-vault` skill for how to search it and " &
     "edit it safely." & LF & LF &
     "This index is agent-maintained: whenever an agent cr" &
     "eates a new top-level folder, it must add a" & LF &
     "one-line section for it here in the same edit. Treat" &
     " this file as out of date if a folder exists on" & LF &
     "disk with no matching section below -- fix the drift" &
     " rather than working around it." & LF & LF &
     "This is a starter index, not a fixed schema -- an ag" &
     "ent reads this file as the authority on what" & LF &
     "your folders are and mean, not the other way around." &
     " Only the two structurally-fixed folders below" & LF &
     "exist from the start; `projects/`, `research/`, `scr" &
     "atchpad/`, and `inbox/` aren't listed yet because" & LF &
     "nothing has created one on this vault -- `/synapse-b" &
     "ard-design-note`, `/synapse-bard-task-note`, and" & LF &
     "`/synapse-bard-note` each add their own section here" &
     " the first time they actually create that folder." & LF & LF &
     "## designs/" & LF &
     "Free-form design discussions about the story -- tone" &
     " choices, plot mechanics, character motivation" & LF &
     "problems, worldbuilding decisions. Created and maint" &
     "ained by `/synapse-bard-design-note`." & LF & LF & "## tasks/" & LF &
     "Tracked work: a checklist compiled from a `Ready` de" &
     "sign note (`/synapse-bard-task-note`), or created" & LF &
     "directly (`/synapse-bard-note --task`). Status trans" &
     "itions (`TODO` " & Character'Val (16#E2#) & Character'Val (16#86#) &
     Character'Val (16#92#) & " `IN-PROGRESS` " & Character'Val (16#E2#) &
     Character'Val (16#86#) & Character'Val (16#92#) & " `REVIEW`, never" &
     LF & "`DONE`) are handled by the `synapse-bard-task` skill" &
     ", not by hand." & LF;

end Synapse_Bard.Vault_Index_Template;
