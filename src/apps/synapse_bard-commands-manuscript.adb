with Ada.Strings.Unbounded;

with Synapse.Core.Decimal_Image;

with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Manuscript;

package body Synapse_Bard.Commands.Manuscript is

   use Ada.Strings.Unbounded;
   use Support;

   package Books renames Synapse_Bard.Manuscript;

   function Image (Value : Natural) return String
   renames Synapse.Core.Decimal_Image.Image;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
      Early : constant Exit_Options.Option :=
        Check_Usage (Env, Usage.Manuscript_Usage, Args, 1);
   begin
      if Early.Found then
         return Early.Value;
      end if;
      declare
         Loaded : constant Books.Loaded.Result :=
           Load_Manuscript (Env, "manuscript", Arg (Args, 1));
         Output : Unbounded_String;
      begin
         if not Books.Loaded.Is_Success (Loaded) then
            return 1;
         end if;
         for B of Books.Loaded.Value (Loaded) loop
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
