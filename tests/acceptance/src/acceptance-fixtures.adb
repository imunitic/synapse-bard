with Ada.Directories;
with Ada.Finalization;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;

with Synapse.Adapters.File_Bytes;
with Synapse.Adapters.System_Process;
with Synapse.Core.Text_Lists;

package body Acceptance.Fixtures is

   use Ada.Strings.Unbounded;

   function Make_Directory (Label : String) return String is
      Path : constant String :=
        Synapse.Adapters.File_Bytes.Temp_Dir & "/synapse-bard-acceptance-"
        & Label;
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
      Ada.Directories.Create_Path (Path);
      return Path;
   end Make_Directory;

   function Run_Program
     (Program : String; Dir : String; Args : Synapse.Core.Text_Lists.Vector)
      return Result
   is
      Runner : Synapse.Adapters.System_Process.System_Runner;
   begin
      return
        Runner.Run
          (Program, Args,
           (Cwd => To_Unbounded_String (Dir), others => <>));
   end Run_Program;

   procedure Init_Git (Dir : String) is
      Args : Synapse.Core.Text_Lists.Vector;
   begin
      Args.Append (To_Unbounded_String ("init"));
      Args.Append (To_Unbounded_String ("-q"));
      declare
         R : constant Result := Run_Program ("git", Dir, Args);
      begin
         pragma Assert (R.Exit_Code = 0);
      end;
   end Init_Git;

   procedure Put_File (Dir, Rel, Content : String) is
      Path : constant String := Dir & "/" & Rel;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put_File;

   procedure Remove (Dir : String) is
   begin
      if Ada.Directories.Exists (Dir) then
         Ada.Directories.Delete_Tree (Dir);
      end if;
   end Remove;

   function Is_Enclosed (Dir : String) return Boolean is
      Here : Unbounded_String := To_Unbounded_String (Dir);
   begin
      loop
         declare
            Parent : constant String :=
              Ada.Directories.Containing_Directory (To_String (Here));
         begin
            if Parent = To_String (Here) then
               return False;
            end if;
            if Ada.Directories.Exists (Parent & "/.git") then
               return True;
            end if;
            Here := To_Unbounded_String (Parent);
         end;
      end loop;
   exception
      when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Name_Error =>
         return False;
   end Is_Enclosed;

   function Run
     (Dir : String; A1 : String := ""; A2 : String := ""; A3 : String := "";
      A4  : String := "") return Result
   is
      Words : constant array (1 .. 4) of Unbounded_String :=
        [To_Unbounded_String (A1), To_Unbounded_String (A2),
         To_Unbounded_String (A3), To_Unbounded_String (A4)];
      Args  : Synapse.Core.Text_Lists.Vector;
   begin
      for W of Words loop
         if W /= "" then
            Args.Append (W);
         end if;
      end loop;
      return Run_Program (Binary, Dir, Args);
   end Run;

   --  Sets Name to Value for the life of the object, or unsets it when Value is
   --  empty, and restores what it was.
   type Variable_Guard (Name_Length : Natural) is
     limited new Ada.Finalization.Limited_Controlled with
   record
      Name     : String (1 .. Name_Length);
      Was_Set  : Boolean;
      Previous : Unbounded_String;
   end record;

   overriding procedure Finalize (G : in out Variable_Guard) is
   begin
      if G.Was_Set then
         Ada.Environment_Variables.Set (G.Name, To_String (G.Previous));
      else
         Ada.Environment_Variables.Clear (G.Name);
      end if;
   end Finalize;

   function Guard (Name, Value : String) return Variable_Guard is
      Existing : constant Boolean := Ada.Environment_Variables.Exists (Name);
   begin
      return G : Variable_Guard (Name'Length) do
         G.Name := Name;
         G.Was_Set := Existing;
         if Existing then
            G.Previous :=
              To_Unbounded_String (Ada.Environment_Variables.Value (Name));
         end if;
         if Value = "" then
            Ada.Environment_Variables.Clear (Name);
         else
            Ada.Environment_Variables.Set (Name, Value);
         end if;
      end return;
   end Guard;

   function Run_Hook
     (Dir : String; Hook : String; Stdin : String; Home : String := "";
      Plugin_Root : String := ""; Content_Root : String := "") return Result
   is
      Runner : Synapse.Adapters.System_Process.System_Runner;
      Args   : Synapse.Core.Text_Lists.Vector;
      G_Home : Variable_Guard := Guard ("HOME", Home);
      G_Plug : Variable_Guard := Guard ("CLAUDE_PLUGIN_ROOT", Plugin_Root);
      G_Cont : Variable_Guard :=
        Guard ("SYNAPSE_BARD_CONTENT_ROOT", Content_Root);
   begin
      if Hook /= "" then
         Args.Append (To_Unbounded_String (Hook));
      end if;
      return
        Runner.Run
          (Binary & "-hook", Args,
           (Cwd       => To_Unbounded_String (Dir), Has_Stdin => True,
            Stdin     => To_Unbounded_String (Stdin)));
   end Run_Hook;

   function Contains (Text, Part : String) return Boolean is
     (for some I in Text'First .. Text'Last - Part'Length + 1 =>
        Text (I .. I + Part'Length - 1) = Part);

end Acceptance.Fixtures;
