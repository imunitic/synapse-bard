with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Manuscript;

package body Synapse_Bard.Commands.Manuscript is

   use Ada.Strings.Unbounded;
   use Support;

   TAB : constant Character := Character'Val (9);

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Manuscript_Usage);
         return 2;
      end if;
      if Is_Help (Arg (Args, 1)) then
         Err_Text (Env, Usage.Manuscript_Usage);
         return 0;
      end if;
      if Count (Args) > 1 then
         Err_Text
           (Env,
            "synapse-bard manuscript: unexpected argument '" & Arg (Args, 2)
            & "'" & LF & Usage.Manuscript_Usage);
         return 2;
      end if;
      declare
         Loaded : constant Synapse_Bard.Manuscript.Loaded.Result :=
           Synapse_Bard.Manuscript.Load (Resolve_Path (Env, Arg (Args, 1)));
         Output : Unbounded_String;
      begin
         if not Synapse_Bard.Manuscript.Loaded.Is_Success (Loaded) then
            Err_Text
              (Env,
               "synapse-bard manuscript: "
               & To_String (Synapse_Bard.Manuscript.Loaded.Error (Loaded))
               & LF);
            return 1;
         end if;
         for B of Synapse_Bard.Manuscript.Loaded.Value (Loaded) loop
            for C of B.Chapters loop
               Append
                 (Output,
                  To_String (B.Title) & TAB & To_String (C.Name) & TAB
                  & To_String (C.File) & TAB & Image (C.First) & TAB
                  & Image (C.Last) & LF);
            end loop;
         end loop;
         Out_Text (Env, To_String (Output));
         return 0;
      end;
   end Run;

end Synapse_Bard.Commands.Manuscript;
