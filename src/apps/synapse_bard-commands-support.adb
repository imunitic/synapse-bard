with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;

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
   begin
      return Synapse.Core.Optional_Text.Of_Value
        (Ada.Strings.Unbounded.To_Unbounded_String
           (Synapse.Adapters.File_Bytes.Read (Path, Largest_Source)));
   exception
      when Synapse.Adapters.File_Bytes.Too_Large
         | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         return Synapse.Core.Optional_Text.None;
   end Read_Source;

end Synapse_Bard.Commands.Support;
