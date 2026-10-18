with Ada.Strings.Unbounded;

with Synapse_Bard.Files;

package body Synapse_Bard.Commands.Support is

   Largest_Source : constant := 2**20;

   function Arg (Args : Arguments; N : Positive) return String is
     (Ada.Strings.Unbounded.To_String (Args (N)));

   function Count (Args : Arguments) return Natural is
     (Natural (Args.Length));

   procedure Out_Text (Env : Environment; Text : String) is
   begin
      Env.Console.Write_Out (Text);
   end Out_Text;

   procedure Err_Text (Env : Environment; Text : String) is
   begin
      Env.Console.Write_Err (Text);
   end Err_Text;

   function Strip_Md_Suffix (Text : String) return String is
     (if Text'Length >= 3 and then Text (Text'Last - 2 .. Text'Last) = ".md"
      then Text (Text'First .. Text'Last - 3)
      else Text);

   function Resolve_Path (Env : Environment; Path : String) return String is
     (if Path'Length > 0 and then Path (Path'First) = '/' then Path
      else Ada.Strings.Unbounded.To_String (Env.Start) & "/" & Path);

   function Content_Root (Env : Environment) return Maybe_Text is
     (Env.Vars.Get ("SYNAPSE_BARD_CONTENT_ROOT"));

   function Work_Dir (Env : Environment) return Maybe_Text is
      Value : constant Maybe_Text := Env.Vars.Get ("SYNAPSE_BARD_WORK_DIR");
   begin
      if Value.Found
        and then Ada.Strings.Unbounded.Length (Value.Value) > 0
      then
         return Value;
      end if;
      return Synapse.Core.Optional_Text.None;
   end Work_Dir;

   function Read_Source (Path : String) return Maybe_Text is
     (Files.Read_Text (Path, Largest_Source));

   function Check_Usage
     (Env : Environment; Usage : String; Args : Arguments; Wanted : Natural)
      return Exit_Options.Option
   is
   begin
      if Args.Is_Empty and then Wanted > 0 then
         Err_Text (Env, Usage);
         return Exit_Options.Of_Value (2);
      end if;
      if not Args.Is_Empty and then Is_Help (Arg (Args, 1)) then
         Err_Text (Env, Usage);
         return Exit_Options.Of_Value (0);
      end if;
      if Count (Args) /= Wanted then
         Err_Text (Env, Usage);
         return Exit_Options.Of_Value (2);
      end if;
      return Exit_Options.None;
   end Check_Usage;

   function Load_Manuscript
     (Env : Environment; Command, Root : String)
      return Synapse_Bard.Manuscript.Loaded.Result
   is
      Loaded : constant Synapse_Bard.Manuscript.Loaded.Result :=
        Synapse_Bard.Manuscript.Load (Resolve_Path (Env, Root));
   begin
      if not Synapse_Bard.Manuscript.Loaded.Is_Success (Loaded) then
         Err_Text
           (Env,
            "synapse-bard " & Command & ": "
            & Ada.Strings.Unbounded.To_String
                (Synapse_Bard.Manuscript.Loaded.Error (Loaded))
            & LF);
      end if;
      return Loaded;
   end Load_Manuscript;

end Synapse_Bard.Commands.Support;
