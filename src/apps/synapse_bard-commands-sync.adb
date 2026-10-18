with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Graph_Store;
with Synapse_Bard.Sync_Plan;
with Synapse_Bard.Vault_Index_Template;
with Synapse.Core.Decimal_Image;

package body Synapse_Bard.Commands.Sync is

   use Ada.Strings.Unbounded;
   use Support;

   function Image (Value : Natural) return String
   renames Synapse.Core.Decimal_Image.Image;

   --  Seeds `Index.md` of the vault from the starter index when it does not
   --  exist. Bringing the tool up in a repository with `sync` is the signal
   --  that the vault should exist, so there is no confirmation. Whether it
   --  seeded anything.
   function Seed_Vault_Index (Vault : String) return Boolean is
      Path : constant String := Vault & "/Index.md";
   begin
      if Ada.Directories.Exists (Path) then
         return False;
      end if;
      Ada.Directories.Create_Path (Vault);
      Synapse.Adapters.File_Bytes.Write
        (Path, Synapse_Bard.Vault_Index_Template.Text);
      return True;
   end Seed_Vault_Index;

   --  Writes every planned cluster, then deletes whatever node the plan did
   --  not produce.
   function Run_Write
     (Env    : Environment;
      Store  : in out Synapse_Bard.Graph_Store.Graph_Store;
      Plan   : Synapse_Bard.Sync_Plan.Plan;
      Vault  : String) return Exit_Code
   is
      Output  : Unbounded_String;
      Written : Synapse.Core.Text_Lists.Vector;
   begin
      for Line of Plan.Report_Lines loop
         Append (Output, Line);
      end loop;
      for Planned of Plan.Clusters loop
         declare
            Result : constant Synapse.Ports.Store.Write_Result :=
              Store.Write (To_String (Planned.Node), To_String (Planned.Body_Text));
         begin
            pragma Assert (Result.Accepted);
         end;
         Written.Append (Planned.Node);
      end loop;
      declare
         Removed : constant Natural :=
           Synapse_Bard.Sync_Plan.Reconcile (Store, Written);
         Seeded  : constant Boolean := Seed_Vault_Index (Vault);
      begin
         Append
           (Output,
            LF & "ingested: " & Image (Plan.Ingested) & LF
            & "skipped (unsupported): " & Image (Plan.Skipped) & LF
            & "collisions: " & Image (Plan.Collisions) & LF
            & "clusters: " & Image (Natural (Plan.Clusters.Length)) & LF
            & "removed (no longer in source): " & Image (Removed) & LF);
         if Seeded then
            Append (Output, "seeded " & Vault & "/Index.md (first use)" & LF);
         end if;
      end;
      Out_Text (Env, To_String (Output));
      return 0;
   end Run_Write;

   --  `--check`: reads only. A cluster is dirty when its generated region
   --  differs from the disk or its node does not exist yet; a node the plan
   --  does not produce is what a real sync would delete.
   function Run_Check
     (Env   : Environment;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store;
      Plan  : Synapse_Bard.Sync_Plan.Plan) return Exit_Code
   is
      Dirty   : Synapse.Core.Text_Lists.Vector;
      Planned : Synapse.Core.Text_Lists.Vector;
      Output  : Unbounded_String;
   begin
      for P of Plan.Clusters loop
         Planned.Append (P.Node);
         if Cluster.Is_Dirty
              (Store.Read (To_String (P.Node)), To_String (P.Body_Text))
         then
            Dirty.Append (P.Node);
         end if;
      end loop;
      declare
         Stale : constant Synapse.Core.Text_Lists.Vector :=
           Cluster.Would_Remove (Store.List, Planned);
         Total : constant Natural :=
           Natural (Dirty.Length) + Natural (Stale.Length);
      begin
         if Total = 0 then
            Out_Text
              (Env, "_bard/graph/ matches source -- no drift" & LF);
            return 0;
         end if;
         for Node of Dirty loop
            Append (Output, "drift: " & To_String (Node) & LF);
         end loop;
         for Node of Stale loop
            Append (Output, "would remove: " & To_String (Node) & LF);
         end loop;
         Append
           (Output,
            LF & Image (Total) & " cluster(s) out of date -- run `synapse-bard"
            & " sync`" & LF);
         Out_Text (Env, To_String (Output));
         return 1;
      end;
   end Run_Check;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
      Check : Boolean := False;
   begin
      if not Args.Is_Empty then
         if Is_Help (Arg (Args, 1)) then
            Err_Text (Env, Usage.Sync_Usage);
            return 0;
         end if;
         if Arg (Args, 1) = "--check" then
            Check := True;
         else
            Err_Text
              (Env,
               "synapse-bard sync: unexpected argument '" & Arg (Args, 1)
               & "'" & LF & Usage.Sync_Usage);
            return 2;
         end if;
         if Count (Args) > 1 then
            Err_Text
              (Env,
               "synapse-bard sync: unexpected argument '" & Arg (Args, 2)
               & "'" & LF & Usage.Sync_Usage);
            return 2;
         end if;
      end if;
      declare
         Found : constant Roots.Roots_Options.Option :=
           Roots.Resolve_Or_Report (Env);
      begin
         if not Found.Found then
            return 1;
         end if;
         declare
            Store : Synapse_Bard.Graph_Store.Graph_Store :=
              Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
            Plan  : constant Synapse_Bard.Sync_Plan.Plan :=
              Synapse_Bard.Sync_Plan.Compute_Plan
                (To_String (Found.Value.Repo), Store);
         begin
            return
              (if Check then Run_Check (Env, Store, Plan)
               else Run_Write (Env, Store, Plan, To_String (Found.Value.Vault)));
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Sync;
