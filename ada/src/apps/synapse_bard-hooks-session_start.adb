with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Hooks.Output;
with Synapse_Bard.Hooks.Payload;

package body Synapse_Bard.Hooks.Session_Start is

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   Blank_Line : constant String := [Character'Val (10), Character'Val (10)];

   function Plugin_Root
     (Vars : Synapse.Ports.Variables.Variables'Class) return Maybe_Text
   is
      Plugin  : constant Maybe_Text := Vars.Get ("CLAUDE_PLUGIN_ROOT");
   begin
      if Plugin.Found then
         return Plugin;
      end if;
      return Vars.Get ("SYNAPSE_BARD_CONTENT_ROOT");
   end Plugin_Root;

   function Under_Root
     (Vars : Synapse.Ports.Variables.Variables'Class; Name : String)
      return Maybe_Text
   is
      Root : constant Maybe_Text := Plugin_Root (Vars);
   begin
      if not Root.Found then
         return Synapse.Core.Optional_Text.None;
      end if;
      return Synapse.Core.Optional_Text.Of_Value
        (To_Unbounded_String (To_String (Root.Value) & "/" & Name));
   end Under_Root;

   function Template_Path
     (Vars : Synapse.Ports.Variables.Variables'Class) return Maybe_Text is
     (Under_Root (Vars, "Index.md.template"));

   function Claude_Md_Path
     (Vars : Synapse.Ports.Variables.Variables'Class) return Maybe_Text is
     (Under_Root (Vars, "synapse-bard-claude.md"));

   function Bard_Enabled (Repo_Root : String) return Boolean is
      Path : constant String := Repo_Root & "/_bard";
   begin
      return
        Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         return False;
   end Bard_Enabled;

   function Absolute (Start, Cwd : String) return String is
   begin
      if Cwd = "." then
         return Start;
      elsif Cwd'Length > 0
        and then (Cwd (Cwd'First) in '/' | '\'
                  or else (Cwd'Length > 1 and then Cwd (Cwd'First + 1) = ':'))
      then
         return Cwd;
      end if;
      return Start & "/" & Cwd;
   end Absolute;

   --  The text of a file, nothing when it cannot be read or is over Limit.
   function Read_Text (Path : String; Limit : Natural) return Maybe_Text is
   begin
      return Synapse.Core.Optional_Text.Of_Value
        (To_Unbounded_String
           (Synapse.Adapters.File_Bytes.Read (Path, Limit)));
   exception
      when Synapse.Adapters.File_Bytes.Too_Large
         | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         return Synapse.Core.Optional_Text.None;
   end Read_Text;

   procedure Run (Env : Environment) is
      Input : constant Payload.Payload := Payload.Read (Env);
      Cwd   : constant Payload.Maybe_Text := Payload.Str (Input, "cwd");
      Found : constant Commands.Roots.Roots_Options.Option :=
        Commands.Roots.Resolve
          (Absolute
             (To_String (Env.Start),
              (if Cwd.Found then To_String (Cwd.Value) else ".")));
   begin
      if not Found.Found then
         return;
      end if;
      declare
         Repo       : constant String := To_String (Found.Value.Repo);
         Index_Path : constant String := Repo & "/_bard/vault/Index.md";
         Claude     : Maybe_Text := Synapse.Core.Optional_Text.None;
         Claude_At  : constant Maybe_Text := Claude_Md_Path (Env.Vars.all);
         Index      : constant Maybe_Text := Read_Text (Index_Path, 64 * 2**20);
         Output     : Unbounded_String;
      begin
         if not Bard_Enabled (Repo) then
            return;
         end if;
         if Claude_At.Found then
            Claude := Read_Text (To_String (Claude_At.Value), 2**20);
         end if;

         if Claude.Found and then Length (Claude.Value) > 0 then
            Append (Output, Claude.Value);
         end if;

         --  Offer, never seed: the hook stays read-only. Reaching this point
         --  means a person already used bard here, just not the vault side.
         declare
            Template : constant Maybe_Text := Template_Path (Env.Vars.all);
            Part     : constant String :=
              (if Index.Found
               then
                 "Writer's notes vault index (" & Index_Path
                 & ") -- read before creating or linking any note; prefer "
                 & "linking to an existing note over duplicating content, "
                 & "and fall back to linking this index if nothing more "
                 & "specific applies:" & Blank_Line & To_String (Index.Value)
               else
                 "No Writer's notes vault index found at " & Index_Path
                 & " -- offer to seed it from the shipped default ("
                 & (if Template.Found then To_String (Template.Value)
                    else "this plugin's own Index.md.template")
                 & ") before creating or linking any note.");
         begin
            if Part'Length > 0 then
               if Length (Output) > 0 then
                  Append (Output, Blank_Line);
               end if;
               Append (Output, Part);
            end if;
         end;
         Hooks.Output.Emit_Context (Env, "SessionStart", To_String (Output));
      end;
   end Run;

end Synapse_Bard.Hooks.Session_Start;
