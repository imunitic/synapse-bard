with Ada.Strings.Unbounded;

with Synapse.Adapters.Disk_Store;
with Synapse.Core.Optional_Text;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

--  The Bible-graph's own storage: plain files under one flat directory
--  (`_bard/graph/`), no daemon and no index. A node is the bare file name
--  including `.md`, like every other store's. Reading, writing and listing
--  are a `Disk_Store`'s, so a write replaces the file in one step.

package Synapse_Bard.Graph_Store is

   package Port renames Synapse.Ports.Store;

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   type Graph_Store is limited new Port.Store with private;

   --  Root is the directory the nodes live in; it need not exist yet.
   function Create (Root : String) return Graph_Store;

   overriding
   function Read
     (S : in out Graph_Store; Node : String) return Port.Maybe_Text;

   overriding
   function Write
     (S : in out Graph_Store; Node, Content : String) return Port.Write_Result;

   --  Every `.md` file of the directory; empty when it does not exist yet.
   overriding
   function List
     (S : in out Graph_Store) return Synapse.Core.Text_Lists.Vector;

   --  `key:value` (exactly one colon, a non-empty key and value) matches the
   --  nodes whose frontmatter has a root `key: value` line, key compared
   --  exactly and value without regard to case. Any other query is a
   --  full-text scan without regard to case, scored by the number of
   --  occurrences, with the first matching line as context.
   overriding
   function Search
     (S : in out Graph_Store; Query : String) return Port.Hit_Vectors.Vector;

   --  Removes a node; one that is already gone is not an error. Not part of
   --  the port: `sync` is the one caller, and a renamed or deleted source
   --  must not leave a stale node behind.
   procedure Delete (S : in out Graph_Store; Node : String);

   --  The root-level `Key: value` line of Body_Text's frontmatter when the
   --  key matches exactly and the value, unquoted, matches without regard to
   --  case; otherwise nothing. Public because the `search` command applies
   --  it to real entity files, not only to stored nodes.
   function Field_Line (Body_Text, Key, Value : String) return Maybe_Text;

private

   type Graph_Store is limited new Port.Store with record
      Root : Ada.Strings.Unbounded.Unbounded_String;
      Disk : Synapse.Adapters.Disk_Store.Disk_Store;
   end record;

end Synapse_Bard.Graph_Store;
