with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

with Synapse_Bard.Graph_Store;

--  What `sync` writes to `_bard/graph/`, computed without writing a byte: the
--  clusters of the source tree, every candidate's frontmatter extracted in one
--  batch, and each cluster rendered with the hand-written tail of its
--  existing node. `sync` and the hook's session-start drift check both call
--  it, so there is one definition of what `sync` produces.

package Synapse_Bard.Sync_Plan is

   --  One cluster node `sync` would write.
   type Planned_Cluster is record
      --  The node's file name: `Characters - Main.md`.
      Node      : Ada.Strings.Unbounded.Unbounded_String;
      --  Its whole text, as a write would produce it, the existing node's
      --  preserved tail included: `Cluster.Generated_Region` of it is what
      --  drift detection compares with the disk.
      Body_Text : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Planned_Cluster_Vectors is new Ada.Containers.Vectors
     (Positive, Planned_Cluster);

   type Plan is record
      --  In cluster order, bytewise by boundary.
      Clusters     : Planned_Cluster_Vectors.Vector;
      --  `skipped (<reason>): <path>` and `COLLISION: ...` lines, in the order
      --  the candidates were visited, each ending in a line feed. Only the
      --  command that writes prints them.
      Report_Lines : Synapse.Core.Text_Lists.Vector;
      Ingested     : Natural := 0;
      Skipped      : Natural := 0;
      Collisions   : Natural := 0;
   end record;

   --  Repo_Root is the repository whose source tree is clustered. The store
   --  is read, to find each cluster's existing tail, and never written.
   --
   --  Every top-level folder not starting with `_` or `.` is searched for a
   --  cluster boundary: the shallowest directory that directly holds a `.md`
   --  file, which owns every `.md` below it. A slug (a file name without
   --  `.md`) is unique across the whole graph, since it must resolve to one
   --  path: a second claimant is a collision and is dropped.
   function Compute_Plan
     (Repo_Root : String; Store : in out Synapse.Ports.Store.Store'Class)
      return Plan;

   --  Deletes every node of Store that Written does not contain, and says how
   --  many it removed: a folder that no longer produces an entity must not
   --  leave a stale node behind.
   function Reconcile
     (Store   : in out Synapse_Bard.Graph_Store.Graph_Store;
      Written : Synapse.Core.Text_Lists.Vector) return Natural;

end Synapse_Bard.Sync_Plan;
