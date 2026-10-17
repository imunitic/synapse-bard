with Ada.Directories;

with Synapse.Adapters.File_Bytes;

package body Scratch_Dirs is

   function Make (Label : String) return String is
      Path : constant String :=
        Synapse.Adapters.File_Bytes.Temp_Dir & "/synapse-bard-test-" & Label;
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
      Ada.Directories.Create_Path (Path);
      return Path;
   end Make;

   procedure Remove (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   end Remove;

end Scratch_Dirs;
