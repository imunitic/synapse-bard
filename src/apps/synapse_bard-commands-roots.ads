with Ada.Strings.Unbounded;

with Synapse.Core.Options;

--  Where a command's data lives, found from the directory it was started in.

package Synapse_Bard.Commands.Roots is

   --  The repository root, which resolves a cluster's `sources:` paths;
   --  `_bard/graph` under it, with the clusters; `_bard/vault` under it, with
   --  the writer's notes.
   type Roots is record
      Repo  : Ada.Strings.Unbounded.Unbounded_String;
      Graph : Ada.Strings.Unbounded.Unbounded_String;
      Vault : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Roots_Options is new Synapse.Core.Options (Roots);

   --  The nearest directory at or above Start that holds `.git` (a directory,
   --  or a file in a worktree). Nothing outside a repository.
   function Resolve (Start : String) return Roots_Options.Option;

   --  Resolve from the environment's start directory, saying so on standard
   --  error when there is no repository.
   function Resolve_Or_Report
     (Env : Environment) return Roots_Options.Option;

end Synapse_Bard.Commands.Roots;
