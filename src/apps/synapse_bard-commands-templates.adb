with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Templates;

package body Synapse_Bard.Commands.Templates is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
      Install : constant Boolean :=
        Count (Args) = 1 and then Arg (Args, 1) = "--install";
      Early   : constant Exit_Options.Option :=
        (if Install then Exit_Options.None
         else Check_Usage (Env, Usage.Templates_Usage, Args, 0));
   begin
      if Early.Found then
         return Early.Value;
      end if;
      declare
         Found : constant Roots.Roots_Options.Option :=
           Roots.Resolve_Or_Report (Env);
      begin
         if not Found.Found then
            return 1;
         end if;
         declare
            Repo   : constant String := To_String (Found.Value.Repo);
            Output : Unbounded_String;
         begin
            if Install then
               declare
                  Content : constant Maybe_Text := Content_Root (Env);
                  Copies  : constant Synapse_Bard.Templates.Installed.Result :=
                    Synapse_Bard.Templates.Install
                      (Repo,
                       (if Content.Found then To_String (Content.Value)
                        else ""));
               begin
                  if not Synapse_Bard.Templates.Installed.Is_Success (Copies)
                  then
                     Err_Text
                       (Env,
                        "synapse-bard templates: "
                        & To_String
                            (Synapse_Bard.Templates.Installed.Error (Copies))
                        & LF);
                     return 1;
                  end if;
                  for T of Synapse_Bard.Templates.Installed.Value (Copies)
                  loop
                     Append (Output, "installed " & To_String (T.Path) & LF);
                  end loop;
                  Out_Text (Env, To_String (Output));
                  return 0;
               end;
            end if;
            declare
               Set : constant Synapse_Bard.Templates.Resolved.Result :=
                 Synapse_Bard.Templates.Resolve (Repo);
            begin
               if not Synapse_Bard.Templates.Resolved.Is_Success (Set) then
                  Err_Text
                    (Env,
                     "synapse-bard templates: "
                     & To_String (Synapse_Bard.Templates.Resolved.Error (Set))
                     & LF);
                  return 1;
               end if;
               for T of Synapse_Bard.Templates.Resolved.Value (Set) loop
                  Append
                    (Output,
                     To_String (T.Kind) & TAB & To_String (T.Path) & LF);
               end loop;
               Out_Text (Env, To_String (Output));
               return 0;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Templates;
