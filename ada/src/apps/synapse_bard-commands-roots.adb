with Ada.Directories;
with Ada.IO_Exceptions;

with Synapse_Bard.Commands.Support;

package body Synapse_Bard.Commands.Roots is

   use Ada.Strings.Unbounded;

   function Resolve (Start : String) return Roots_Options.Option is
      Dir : Unbounded_String := To_Unbounded_String (Start);
   begin
      loop
         declare
            Here : constant String := To_String (Dir);
         begin
            if Ada.Directories.Exists (Here & "/.git") then
               return Roots_Options.Of_Value
                 (Roots'
                    (Repo  => Dir,
                     Graph => To_Unbounded_String (Here & "/_bard/graph"),
                     Vault => To_Unbounded_String (Here & "/_bard/vault")));
            end if;
            declare
               Parent : constant String :=
                 Ada.Directories.Containing_Directory (Here);
            begin
               exit when Parent = Here;
               Dir := To_Unbounded_String (Parent);
            end;
         end;
      end loop;
      return Roots_Options.None;
   exception
      when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Name_Error =>
         return Roots_Options.None;
   end Resolve;

   function Resolve_Or_Report
     (Env : Environment) return Roots_Options.Option
   is
      Found : constant Roots_Options.Option := Resolve (To_String (Env.Start));
   begin
      if not Found.Found then
         Support.Err_Text
           (Env, "synapse-bard: not inside a git repository" & Support.LF);
      end if;
      return Found;
   end Resolve_Or_Report;

end Synapse_Bard.Commands.Roots;
