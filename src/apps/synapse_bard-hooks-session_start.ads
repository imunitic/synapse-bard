with Synapse.Core.Optional_Text;
with Synapse.Ports.Variables;

--  The `session-start` hook: SessionStart.
--
--  Silent unless `_bard/` exists at the repository root. Nothing here creates
--  it (only a real `sync` or an explicit vault seed does), so its absence
--  means bard was never deliberately used in this repository, and the hook
--  must not offer a fiction-bible vault in every repository the plugin is
--  merely installed in. Once `_bard/` exists, up to two pieces are injected:
--  the plugin's standing instructions and the vault's index, or an offer to
--  seed the index when the vault side has not been set up yet. The hook only
--  reads.

package Synapse_Bard.Hooks.Session_Start is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   procedure Run (Env : Environment);

   --  Whether `_bard` is a directory under Repo_Root: the one thing that tells
   --  a repository where bard was used from one where the plugin is merely
   --  installed. Shared with the stop nudge.
   function Bard_Enabled (Repo_Root : String) return Boolean;

   --  `<root>/Index.md.template`, where the root is
   --  `SYNAPSE_BARD_CONTENT_ROOT`, the folder the npm package is installed
   --  in. Nothing when it is unset; a variable set to the empty string
   --  counts.
   function Template_Path
     (Vars : Synapse.Ports.Variables.Variables'Class) return Maybe_Text;

   --  `<root>/synapse-bard-claude.md`, from the same root.
   function Claude_Md_Path
     (Vars : Synapse.Ports.Variables.Variables'Class) return Maybe_Text;

   --  The directory a session started in, as an absolute path: Cwd as given
   --  when it is absolute, else under Start.
   function Absolute (Start, Cwd : String) return String;

end Synapse_Bard.Hooks.Session_Start;
