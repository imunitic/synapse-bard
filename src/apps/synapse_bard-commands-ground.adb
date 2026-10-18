with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;

with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Grounding;
with Synapse_Bard.Manuscript;

package body Synapse_Bard.Commands.Ground is

   use Ada.Strings.Unbounded;
   use Support;

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Ground_Usage);
         return 2;
      end if;
      if Is_Help (Arg (Args, 1)) then
         Err_Text (Env, Usage.Ground_Usage);
         return 0;
      end if;
      if Count (Args) /= 2 then
         Err_Text (Env, Usage.Ground_Usage);
         return 2;
      end if;
      declare
         Work   : constant Maybe_Text := Work_Dir (Env);
         Loaded : constant Synapse_Bard.Manuscript.Loaded.Result :=
           Synapse_Bard.Manuscript.Load (Resolve_Path (Env, Arg (Args, 1)));
         Source : constant Maybe_Text :=
           Read_Source (Resolve_Path (Env, Arg (Args, 2)));
      begin
         if not Work.Found then
            Err_Text
              (Env,
               "synapse-bard ground: SYNAPSE_BARD_WORK_DIR is not set" & LF);
            return 1;
         end if;
         if not Synapse_Bard.Manuscript.Loaded.Is_Success (Loaded) then
            Err_Text
              (Env,
               "synapse-bard ground: "
               & To_String (Synapse_Bard.Manuscript.Loaded.Error (Loaded))
               & LF);
            return 1;
         end if;
         if not Source.Found then
            Err_Text
              (Env,
               "synapse-bard ground: cannot read the roster '"
               & Arg (Args, 2) & "'" & LF);
            return 1;
         end if;
         declare
            Roster : constant Synapse_Bard.Grounding.Parsed.Result :=
              Synapse_Bard.Grounding.Parse_Roster (To_String (Source.Value));
         begin
            if not Synapse_Bard.Grounding.Parsed.Is_Success (Roster) then
               Err_Text
                 (Env,
                  "synapse-bard ground: "
                  & To_String (Synapse_Bard.Grounding.Parsed.Error (Roster))
                  & LF);
               return 1;
            end if;
            declare
               Found : constant Synapse_Bard.Grounding.Reference_Vectors.Vector
                 := Synapse_Bard.Grounding.Ground
                      (Synapse_Bard.Manuscript.Loaded.Value (Loaded),
                       Synapse_Bard.Grounding.Parsed.Value (Roster));
               Path  : constant String :=
                 Resolve_Path (Env, To_String (Work.Value)) & "/_refs.tsv";
            begin
               Ada.Directories.Create_Path
                 (Ada.Directories.Containing_Directory (Path));
               Synapse.Adapters.File_Bytes.Write
                 (Path, Synapse_Bard.Grounding.Image (Found));
               Out_Text
                 (Env,
                  "Wrote " & Path & " (" & Image (Natural (Found.Length))
                  & " references)" & LF);
               return 0;
            exception
               when Ada.IO_Exceptions.Name_Error
                  | Ada.IO_Exceptions.Use_Error
                  | Ada.IO_Exceptions.Device_Error =>
                  Err_Text
                    (Env,
                     "synapse-bard ground: cannot write " & Path & LF);
                  return 1;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Ground;
