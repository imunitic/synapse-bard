with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Fixed;

with Synapse.Core.Graph_Model;
with Synapse.Ports.Extractor;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Frontmatter_Extractor;
with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Graph_Store;
with Synapse_Bard.Templates;

package body Synapse_Bard.Commands.Verify is

   use Ada.Strings.Unbounded;
   use Support;
   use type Synapse.Core.Graph_Model.Role;
   use type Synapse.Ports.Extractor.Outcome_Kind;

   function Total_Findings (R : Report) return Natural is
     (Natural (R.Frontmatter_Misses.Length) + Natural (R.Prose_Misses.Length)
      + Natural (R.Kind_Misses.Length));

   function Trim_Blanks (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Unquote (Value : String) return String is
     (if Value'Length >= 2
        and then Value (Value'First) in '"' | '''
        and then Value (Value'Last) = Value (Value'First)
      then Value (Value'First + 1 .. Value'Last - 1)
      else Value);

   --  The values of a `kinds:` field as `Raw_Field` returns it: a flow list on
   --  the key's own line, or a block list on the lines below it. Not a general
   --  YAML reader, just the fixed shape the field has.
   function Kinds_Values (Raw : String) return Synapse.Core.Text_Lists.Vector
   is
      Result : Synapse.Core.Text_Lists.Vector;
      Stop   : constant Natural :=
        Ada.Strings.Fixed.Index (Raw, [Character'Val (10)]);
      First  : constant String :=
        (if Stop = 0 then Raw else Raw (Raw'First .. Stop - 1));
      Colon  : constant Natural := Ada.Strings.Fixed.Index (First, ":");
   begin
      if Colon = 0 then
         return Result;
      end if;
      declare
         Value : constant String := Trim_Blanks (First (Colon + 1 .. First'Last));
      begin
         if Value'Length /= 0 then
            if Value'Length >= 2 and then Value (Value'First) = '['
              and then Value (Value'Last) = ']'
            then
               declare
                  Inner : constant String :=
                    Trim_Blanks (Value (Value'First + 1 .. Value'Last - 1));
                  Start : Positive := Inner'First;
               begin
                  for I in Inner'First .. Inner'Last + 1 loop
                     if I > Inner'Last or else Inner (I) = ',' then
                        declare
                           Element : constant String :=
                             Trim_Blanks (Inner (Start .. I - 1));
                        begin
                           if Element'Length > 0 then
                              Result.Append
                                (To_Unbounded_String (Unquote (Element)));
                           end if;
                        end;
                        Start := I + 1;
                     end if;
                  end loop;
               end;
            end if;
            return Result;
         end if;
      end;
      if Stop = 0 then
         return Result;
      end if;
      declare
         Position : Positive := Stop + 1;
      begin
         while Position <= Raw'Last loop
            declare
               Next : Natural := Position;
            begin
               while Next <= Raw'Last and then Raw (Next) /= Character'Val (10)
               loop
                  Next := Next + 1;
               end loop;
               declare
                  Line : constant String := Trim_Blanks (Raw (Position .. Next - 1));
               begin
                  if Line'Length >= 2 and then Line (Line'First .. Line'First + 1)
                                               = "- "
                  then
                     Result.Append
                       (To_Unbounded_String
                          (Unquote
                             (Trim_Blanks (Line (Line'First + 2 .. Line'Last)))));
                  end if;
               end;
               Position := Next + 1;
            end;
         end loop;
      end;
      return Result;
   end Kinds_Values;

   package Count_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, Natural);

   function Tally_Before (Left, Right : Tally) return Boolean is
     (if Left.Count /= Right.Count then Left.Count > Right.Count
      else Left.Target < Right.Target);

   package Tally_Sorting is new Tally_Vectors.Generic_Sorting (Tally_Before);

   function Allowed_Kinds
     (Repo_Root : String) return Synapse.Core.Text_Lists.Vector
   is
      Set : constant Synapse_Bard.Templates.Resolved.Result :=
        Synapse_Bard.Templates.Resolve (Repo_Root);
   begin
      if Synapse_Bard.Templates.Resolved.Is_Success (Set) then
         for T of Synapse_Bard.Templates.Resolved.Value (Set) loop
            if To_String (T.Kind) = "kinds" then
               declare
                  Text : constant Maybe_Text :=
                    Read_Source (To_String (T.Path));
               begin
                  if Text.Found then
                     declare
                        Raw : constant Frontmatter_Fields.Maybe_Text :=
                          Frontmatter_Fields.Raw_Field
                            (To_String (Text.Value), "kinds");
                     begin
                        if Raw.Found then
                           return Kinds_Values (To_String (Raw.Value));
                        end if;
                     end;
                  end if;
               end;
            end if;
         end loop;
      end if;
      return Synapse.Core.Text_Lists.Vectors.Empty_Vector;
   end Allowed_Kinds;

   function Compute_Report
     (Repo_Root : String; Allowed : Synapse.Core.Text_Lists.Vector;
      Store : in out Synapse.Ports.Store.Store'Class) return Report
   is
      Entries   : constant Cluster.Source_Entry_Vectors.Vector :=
        Cluster.All_Entities (Store);
      Slugs     : Synapse.Core.Text_Lists.Set;
      Paths     : Synapse.Core.Text_Lists.Vector;
      Counts    : Count_Maps.Map;
      Result    : Report;
      Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor;
   begin
      for E of Entries loop
         Slugs.Include (To_String (E.Slug));
         Paths.Append (E.Path);
      end loop;
      declare
         Outcomes : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
           Extractor.Extract (Repo_Root, Paths);
      begin
         for I in 1 .. Natural (Entries.Length) loop
            declare
               File : constant Unbounded_String := Entries (I).Path;
            begin
               --  Check 1: frontmatter refs resolve.
               if Outcomes (I).Kind = Synapse.Ports.Extractor.With_Tags then
                  for Tag of Outcomes (I).Tags loop
                     if Tag.Which = Synapse.Core.Graph_Model.Ref
                       and then not Slugs.Contains
                         (Strip_Md_Suffix (To_String (Tag.Name)))
                     then
                        Result.Frontmatter_Misses.Append
                          (Miss'(File => File, Field => Tag.Kind,
                                 Target => Tag.Name));
                     end if;
                  end loop;
               end if;

               declare
                  Src : constant Maybe_Text :=
                    Read_Source (Repo_Root & "/" & To_String (File));
               begin
                  if Src.Found then
                     declare
                        Text  : constant String := To_String (Src.Value);
                        Block : constant Frontmatter_Fields.Maybe_Text :=
                          Frontmatter_Fields.Block (Text);
                     begin
                        --  Check 2: prose-body wikilinks resolve, and a
                        --  resolved target is tallied once per entity.
                        if Block.Found then
                           declare
                              Prose   : constant String :=
                                Text (Text'First + Length (Block.Value)
                                      .. Text'Last);
                              Counted : Synapse.Core.Text_Lists.Set;
                           begin
                              for Raw of Frontmatter_Fields.Wikilink_Targets
                                (Prose)
                              loop
                                 declare
                                    Target : constant String :=
                                      Strip_Md_Suffix (To_String (Raw));
                                 begin
                                    if not Slugs.Contains (Target) then
                                       Result.Prose_Misses.Append
                                         (Miss'(File   => File,
                                                Field  =>
                                                  To_Unbounded_String ("prose"),
                                                Target => Raw));
                                    elsif not Counted.Contains (Target) then
                                       Counted.Insert (Target);
                                       if Counts.Contains (Target) then
                                          Counts.Replace
                                            (Target,
                                             Counts.Element (Target) + 1);
                                       else
                                          Counts.Insert (Target, 1);
                                       end if;
                                    end if;
                                 end;
                              end loop;
                           end;
                        end if;

                        --  Check 3: `kinds:` values are allowed ones.
                        declare
                           Raw : constant Frontmatter_Fields.Maybe_Text :=
                             Frontmatter_Fields.Raw_Field (Text, "kinds");
                        begin
                           if Raw.Found and then not Allowed.Is_Empty then
                              for Value of Kinds_Values (To_String (Raw.Value))
                              loop
                                 if not Allowed.Contains (Value) then
                                    Result.Kind_Misses.Append
                                      (Miss'(File   => File,
                                             Field  =>
                                               To_Unbounded_String ("kinds"),
                                             Target => Value));
                                 end if;
                              end loop;
                           end if;
                        end;
                     end;
                  end if;
               end;
            end;
         end loop;
      end;

      for C in Counts.Iterate loop
         Result.Mentions.Append
           (Tally'(Target => To_Unbounded_String (Count_Maps.Key (C)),
                   Count  => Count_Maps.Element (C)));
      end loop;
      Tally_Sorting.Sort (Result.Mentions);
      return Result;
   end Compute_Report;

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if not Args.Is_Empty then
         if Is_Help (Arg (Args, 1)) then
            Err_Text (Env, Usage.Verify_Usage);
            return 0;
         end if;
         Err_Text
           (Env,
            "synapse-bard verify: unexpected argument '" & Arg (Args, 1) & "'"
            & LF & Usage.Verify_Usage);
         return 2;
      end if;
      declare
         Found : constant Roots.Roots_Options.Option :=
           Roots.Resolve_Or_Report (Env);
      begin
         if not Found.Found then
            return 1;
         end if;
         declare
            Store  : Synapse_Bard.Graph_Store.Graph_Store :=
              Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
            Allowed : constant Synapse.Core.Text_Lists.Vector :=
              Allowed_Kinds (To_String (Found.Value.Repo));
            R      : constant Report :=
              Compute_Report (To_String (Found.Value.Repo), Allowed, Store);
            Output : Unbounded_String;

            procedure List (Misses : Miss_Vectors.Vector) is
            begin
               for M of Misses loop
                  Append
                    (Output,
                     To_String (M.File) & ":" & To_String (M.Field) & " -> "
                     & To_String (M.Target) & " (unresolved)" & LF);
               end loop;
            end List;
         begin
            Append
              (Output,
               "broken frontmatter links: "
               & Image (Natural (R.Frontmatter_Misses.Length)) & LF
               & "broken prose links: "
               & Image (Natural (R.Prose_Misses.Length)) & LF
               & (if Allowed.Is_Empty
                  then "kinds values: not checked (no kinds template)"
                  else "unknown kinds values: "
                       & Image (Natural (R.Kind_Misses.Length)))
               & LF);
            List (R.Frontmatter_Misses);
            List (R.Prose_Misses);
            List (R.Kind_Misses);
            if not R.Mentions.Is_Empty then
               Append (Output, LF & "mention counts:" & LF);
               for T of R.Mentions loop
                  Append
                    (Output, To_String (T.Target) & ": " & Image (T.Count) & LF);
               end loop;
            end if;
            Out_Text (Env, To_String (Output));
            return (if Total_Findings (R) /= 0 then 1 else 0);
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Verify;
