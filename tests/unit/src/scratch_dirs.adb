with Ada.Directories;

with GNAT.OS_Lib;

with Synapse.Adapters.File_Bytes;

package body Scratch_Dirs is

   --  `rm -rf` removes a symbolic link itself, where Delete_Tree tries to
   --  empty the folder it points to.
   procedure Remove (Path : String) is
      Args    : GNAT.OS_Lib.Argument_List :=
        [1 => new String'("-rf"), 2 => new String'(Path)];
      Success : Boolean;
   begin
      GNAT.OS_Lib.Spawn ("/bin/rm", Args, Success);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      if not Success then
         raise Program_Error with "cannot remove " & Path;
      end if;
   end Remove;

   function Make (Label : String) return String is
      Path : constant String :=
        Synapse.Adapters.File_Bytes.Temp_Dir & "/synapse-bard-test-" & Label;
   begin
      Remove (Path);
      Ada.Directories.Create_Path (Path);
      return Path;
   end Make;

   procedure Link (Target, Path : String) is
      Args    : GNAT.OS_Lib.Argument_List :=
        [1 => new String'("-s"), 2 => new String'(Target),
         3 => new String'(Path)];
      Success : Boolean;
   begin
      GNAT.OS_Lib.Spawn ("/bin/ln", Args, Success);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      if not Success then
         raise Program_Error with "cannot link " & Path;
      end if;
   end Link;

end Scratch_Dirs;
