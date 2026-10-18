with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.File_Bytes;

package body Synapse_Bard.Files.Tests is

   use AUnit.Assertions;
   use type Read_Status;

   procedure Put (Root, Name, Content : String) is
      Path : constant String := Root & "/" & Name;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put;

   procedure Kinds_Are_Told_Apart
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : constant String := Scratch_Dirs.Make ("files-kinds");
   begin
      Put (Root, "dir/file.md", "text");
      Assert (Is_Directory (Root & "/dir"), "a folder");
      Assert (not Is_File (Root & "/dir"), "a folder is not a file");
      Assert (Is_File (Root & "/dir/file.md"), "a file");
      Assert (not Is_Directory (Root & "/dir/file.md"),
              "a file is not a folder");
      Assert (not Is_File (Root & "/missing")
              and then not Is_Directory (Root & "/missing"),
              "a missing path is neither");
      Scratch_Dirs.Remove (Root);
   end Kinds_Are_Told_Apart;

   procedure Read_Reports_Why_It_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root   : constant String := Scratch_Dirs.Make ("files-read");
      Text   : Ada.Strings.Unbounded.Unbounded_String;
      Status : Read_Status;
   begin
      Put (Root, "a.md", "hello");
      Read (Root & "/a.md", 100, Text, Status);
      Assert (Status = Read_Ok
              and then Ada.Strings.Unbounded.To_String (Text) = "hello",
              "a small file");
      Read (Root & "/a.md", 3, Text, Status);
      Assert (Status = Too_Large, "over the limit");
      Assert (Ada.Strings.Unbounded.Length (Text) = 0, "no text then");
      Read (Root & "/missing.md", 100, Text, Status);
      Assert (Status = Unreadable, "a missing file");
      Assert (not Read_Text (Root & "/missing.md", 100).Found,
              "none for an unreadable file");
      Assert (Read_Text (Root & "/a.md", 100).Found, "some for a readable one");
      Scratch_Dirs.Remove (Root);
   end Read_Reports_Why_It_Fails;

   procedure Links_Below_A_Folder_Are_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root    : constant String := Scratch_Dirs.Make ("files-links");
      Outside : constant String := Scratch_Dirs.Make ("files-links-outside");
   begin
      Put (Root, "real/chapter.md", "text");
      Put (Outside, "secret.md", "text");
      Scratch_Dirs.Link (Outside, Root & "/shortcut");
      Scratch_Dirs.Link (Outside & "/secret.md", Root & "/real/linked.md");
      Assert (not Has_Link_Below (Root, "real"), "a real folder");
      Assert (not Has_Link_Below (Root, "real/chapter.md"), "a real file");
      Assert (Has_Link_Below (Root, "shortcut"), "a linked folder");
      Assert (Has_Link_Below (Root, "shortcut/secret.md"),
              "a file under a linked folder");
      Assert (Has_Link_Below (Root, "real/linked.md"), "a linked file");
      Assert (not Has_Link_Below (Root, "missing"), "a missing path");
      Scratch_Dirs.Remove (Root);
      Scratch_Dirs.Remove (Outside);
   end Links_Below_A_Folder_Are_Found;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Files");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Kinds_Are_Told_Apart'Access,
         "Is_Directory and Is_File tell a folder from a file");
      Register_Routine
        (T, Read_Reports_Why_It_Fails'Access,
         "Read reports a file that is too large or unreadable");
      Register_Routine
        (T, Links_Below_A_Folder_Are_Found'Access,
         "Has_Link_Below finds a link anywhere in a relative path");
   end Register_Tests;

end Synapse_Bard.Files.Tests;
