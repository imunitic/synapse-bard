with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse.Core.Text_Search;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Graph_Store;

package body Synapse_Bard.Commands.Search is

   use Ada.Strings.Unbounded;
   use Support;

   function Trim_Blanks (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Search_Usage);
         return 2;
      end if;
      declare
         First    : constant String := Arg (Args, 1);
         Is_Field : constant Boolean := First = "--field";
      begin
         if Is_Help (First) then
            Err_Text (Env, Usage.Search_Usage);
            return 0;
         end if;
         if Is_Field and then Count (Args) < 2 then
            Err_Text
              (Env,
               "synapse-bard search: --field needs a key:value argument" & LF
               & Usage.Search_Usage);
            return 2;
         end if;
         declare
            Query : constant String :=
              (if Is_Field then Arg (Args, 2) else First);
            Used  : constant Positive := (if Is_Field then 2 else 1);
         begin
            if Count (Args) > Used then
               Err_Text
                 (Env,
                  "synapse-bard search: unexpected argument '"
                  & Arg (Args, Used + 1) & "'" & LF & Usage.Search_Usage);
               return 2;
            end if;

            declare
               Colon : constant Natural :=
                 (if Is_Field then Ada.Strings.Fixed.Index (Query, ":") else 0);
            begin
               if Is_Field
                 and then (Colon = 0
                           or else Trim_Blanks
                                     (Query (Query'First .. Colon - 1))'Length
                                   = 0
                           or else Trim_Blanks
                                     (Query (Colon + 1 .. Query'Last))'Length
                                   = 0)
               then
                  Err_Text
                    (Env,
                     "synapse-bard search: --field needs key:value, got '"
                     & Query & "'" & LF & Usage.Search_Usage);
                  return 2;
               end if;

               declare
                  Key   : constant String :=
                    (if Is_Field then Trim_Blanks (Query (Query'First .. Colon - 1))
                     else "");
                  Value : constant String :=
                    (if Is_Field then Trim_Blanks (Query (Colon + 1 .. Query'Last))
                     else "");
                  Found : constant Roots.Roots_Options.Option :=
                    Roots.Resolve_Or_Report (Env);
               begin
                  if not Found.Found then
                     return 1;
                  end if;
                  declare
                     Store   : Synapse_Bard.Graph_Store.Graph_Store :=
                       Synapse_Bard.Graph_Store.Create
                         (To_String (Found.Value.Graph));
                     Entries : constant Cluster.Source_Entry_Vectors.Vector :=
                       Cluster.All_Entities (Store);
                     Output  : Unbounded_String;
                  begin
                     for E of Entries loop
                        declare
                           Src : constant Maybe_Text :=
                             Read_Source
                               (To_String (Found.Value.Repo) & "/"
                                & To_String (E.Path));
                        begin
                           --  Only the frontmatter block is searched, never
                           --  the prose after it.
                           if Src.Found then
                              declare
                                 Block : constant Frontmatter_Fields.Maybe_Text :=
                                   Frontmatter_Fields.Block
                                     (To_String (Src.Value));
                              begin
                                 if Block.Found then
                                    declare
                                       Text : constant String :=
                                         To_String (Block.Value);
                                    begin
                                       if Is_Field then
                                          declare
                                             Line : constant Maybe_Text :=
                                               Graph_Store.Field_Line
                                                 (Text, Key, Value);
                                          begin
                                             if Line.Found then
                                                Append
                                                  (Output,
                                                   To_String (E.Slug)
                                                   & " (1)  "
                                                   & To_String (Line.Value)
                                                   & LF);
                                             end if;
                                          end;
                                       else
                                          declare
                                             Hits : constant Natural :=
                                               Synapse.Core.Text_Search
                                                 .Count_Ignore_Case
                                                 (Text, Query);
                                             Where : constant Synapse.Core
                                               .Text_Search.Maybe_Line :=
                                                 Synapse.Core.Text_Search
                                                   .First_Matching_Line
                                                   (Text, Query);
                                          begin
                                             if Hits > 0 then
                                                Append
                                                  (Output,
                                                   To_String (E.Slug) & " ("
                                                   & Ada.Strings.Fixed.Trim
                                                       (Natural'Image (Hits),
                                                        Ada.Strings.Left)
                                                   & ")  "
                                                   & (if Where.Found
                                                      then Text
                                                        (Where.Value.First
                                                         .. Where.Value.Last)
                                                      else "")
                                                   & LF);
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                     if Length (Output) = 0 then
                        Append (Output, "no matches for '" & Query & "'" & LF);
                     end if;
                     Out_Text (Env, To_String (Output));
                     return 0;
                  end;
               end;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Search;
