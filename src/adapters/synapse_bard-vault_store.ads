with Ada.Strings.Unbounded;

with Synapse.Adapters.Disk_Store;
with Synapse.Core.Options;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

--  The Writer's notes vault: design notes, task notes and decisions as plain
--  files under one directory (`_bard/vault/`), in subdirectories. A node is
--  the vault-relative path including `.md`. Reading, writing and listing are
--  a `Disk_Store`'s, so a write replaces the file in one step and creates the
--  directories the node implies. Backlinks are the library's
--  `Disk_Link_Graph`: a wikilink resolves by the title of the note it names,
--  with case folded, wherever in the vault that note is.

package Synapse_Bard.Vault_Store is

   package Port renames Synapse.Ports.Store;

   type Vault_Store is limited new Port.Store with private;

   --  Root is the directory the notes live in; it need not exist yet.
   function Create (Root : String) return Vault_Store;

   overriding
   function Read
     (S : in out Vault_Store; Node : String) return Port.Maybe_Text;

   overriding
   function Write
     (S : in out Vault_Store; Node, Content : String) return Port.Write_Result;

   --  Every `.md` file under the root, recursively, without `Index.md`: the
   --  vault's own bootstrap file is not a note.
   overriding
   function List
     (S : in out Vault_Store) return Synapse.Core.Text_Lists.Vector;

   --  The notes whose text, frontmatter included, contains Query without
   --  regard to case, ranked by how many other notes link to them, most
   --  linked first and then by name. A note's link to itself does not count.
   --  A hit's context is the first line that contains Query.
   overriding
   function Search
     (S : in out Vault_Store; Query : String) return Port.Hit_Vectors.Vector;

   package Note_List_Options is new Synapse.Core.Options
     (Synapse.Core.Text_Lists.Vector);

   --  Every note that links to Target, in name order: Target is the title of
   --  a note (the `.md` suffix and any leading path are optional, so
   --  `target`, `target.md` and `designs/target.md` find the same note). A
   --  note that links to itself is left out. Nothing when Target names no
   --  note, which differs from an empty list for a note that nothing links
   --  to. Not part of the port.
   function Linking_Notes
     (S : in out Vault_Store; Target : String) return Note_List_Options.Option;

private

   type Vault_Store is limited new Port.Store with record
      Root : Ada.Strings.Unbounded.Unbounded_String;
      Disk : Synapse.Adapters.Disk_Store.Disk_Store;
   end record;

end Synapse_Bard.Vault_Store;
