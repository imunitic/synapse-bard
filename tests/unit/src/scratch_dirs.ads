--  A fresh directory under the temporary directory for one test.
package Scratch_Dirs is

   --  A new, empty directory whose name contains Label; its absolute path.
   function Make (Label : String) return String;

   --  A symbolic link at Path, which is not under an existing link, to Target.
   procedure Link (Target, Path : String);

   --  Removes the directory and everything in it.
   procedure Remove (Path : String);

end Scratch_Dirs;
