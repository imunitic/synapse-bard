with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Optional_Text;
with Synapse.Core.Options;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

--  The cluster nodes of `_bard/graph/`. `sync` writes one node per source
--  folder, carrying a `sources:` manifest of each member's slug and
--  repo-relative path instead of a copy of the member's own frontmatter;
--  queries resolve a slug through `sources:` to the real file.
--
--  `sources:` has a fixed shape and this unit is its only writer, so the
--  reader matches that shape and is not a general YAML reader.

package Synapse_Bard.Cluster is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   --  One member of a cluster's `sources:` list, read back from a node.
   type Source_Entry is record
      Slug : Ada.Strings.Unbounded.Unbounded_String;
      Path : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Source_Entry_Vectors is new Ada.Containers.Vectors
     (Positive, Source_Entry);

   package Source_Entry_Options is new Synapse.Core.Options (Source_Entry);

   --  A member as `sync` is about to write it. The name is only the display
   --  text of the member's bullet; `sources:` needs just slug and path.
   type Write_Entry is record
      Slug : Ada.Strings.Unbounded.Unbounded_String;
      Path : Ada.Strings.Unbounded.Unbounded_String;
      Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Write_Entry_Vectors is new Ada.Containers.Vectors
     (Positive, Write_Entry);

   --  The line that closes the generated region of a node.
   End_Marker : constant String :=
     "<!-- synapse:generated:end -->" & Character'Val (10);

   --  Everything after the generated region's end marker: what a person
   --  added by hand, and what a re-run of `sync` leaves alone. Empty without
   --  a marker.
   function Preserved_Tail (Existing_Body : String) return String;

   --  Everything up to and including the end marker: the node's own output.
   --  The whole body without a marker.
   function Generated_Region (Body_Text : String) return String;

   --  Whether Computed, the body a real `sync` would write for a cluster,
   --  differs from Existing, what is on disk (nothing when there is no file).
   --  Only the generated regions are compared, so a person's tail never counts
   --  as drift and a missing file always does.
   function Is_Dirty (Existing : Maybe_Text; Computed : String) return Boolean;

   --  The names in Existing (a listing of the graph directory) that Planned
   --  does not produce: what a real `sync` would delete.
   function Would_Remove
     (Existing, Planned : Synapse.Core.Text_Lists.Vector)
      return Synapse.Core.Text_Lists.Vector;

   --  A cluster node's whole text: frontmatter (`title` and `sources:`), the
   --  fenced `## Entities` region with one wikilinked bullet per member, then
   --  Tail. Entries are written in the order given.
   function Render_Cluster_Body
     (Title : String; Entries : Write_Entry_Vectors.Vector; Tail : String)
      return String;

   --  The display title of a cluster's boundary path: its segments joined by
   --  ` - `, each keeping its own casing except that a lowercase first letter
   --  is capitalised, and a character that cannot be in a file name replaced
   --  by `_`.
   function Cluster_Title (Rel_Path : String) return String;

   --  The entries of the `sources:` field of a cluster node's text. Nothing
   --  when there is no such field; an entry that does not have the written
   --  shape is skipped.
   function Parse_Sources (Cluster_Source : String)
      return Source_Entry_Vectors.Vector;

   --  The entry for Slug, from the first node of S that lists it.
   function Resolve_Slug
     (S : in out Synapse.Ports.Store.Store'Class; Slug : String)
      return Source_Entry_Options.Option;

   --  Every entry of every node of S.
   function All_Entities (S : in out Synapse.Ports.Store.Store'Class)
      return Source_Entry_Vectors.Vector;

end Synapse_Bard.Cluster;
