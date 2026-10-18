with Ada.Directories;
with Ada.IO_Exceptions;

with Synapse.Adapters.File_Bytes;
with Synapse.Core.Text_Lists;

with Synapse_Bard.Files;

package body Synapse_Bard.Templates is

   use Ada.Strings.Unbounded;
   use type Files.Read_Status;

   Largest_Template : constant := 2**20;

   function "<" (Left, Right : Template) return Boolean is
     (Left.Kind < Right.Kind);

   package Template_Sorting is new Template_Vectors.Generic_Sorting;

   --  The templates directly in Dir; none when Dir is not a folder.
   function Templates_In (Dir : String) return Template_Vectors.Vector is
      Result : Template_Vectors.Vector;
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      if not Files.Is_Directory (Dir) then
         return Result;
      end if;
      Ada.Directories.Start_Search
        (Search, Dir, "*" & Suffix,
         [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length > Suffix'Length then
               Result.Append
                 (Template'
                    (Kind =>
                       To_Unbounded_String
                         (Name (Name'First .. Name'Last - Suffix'Length)),
                     Path => To_Unbounded_String (Dir & "/" & Name)));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      Template_Sorting.Sort (Result);
      return Result;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         return Template_Vectors.Empty_Vector;
   end Templates_In;

   function Resolve (Repo_Root : String) return Resolved.Result is
      Own : constant Template_Vectors.Vector :=
        Templates_In (Repo_Root & "/_templates");
   begin
      if not Own.Is_Empty then
         return Resolved.Success (Own);
      end if;
      return Resolved.Failure
        (To_Unbounded_String
           ("no template set: " & Repo_Root & "/_templates holds no *"
            & Suffix & " file"));
   end Resolve;

   function Install (Repo_Root, Content_Root : String) return Installed.Result
   is
      Target  : constant String := Repo_Root & "/_templates";
      Shipped : constant Template_Vectors.Vector :=
        (if Content_Root = "" then Template_Vectors.Empty_Vector
         else Templates_In (Content_Root & "/templates"));
      Copies  : Template_Vectors.Vector;
      Texts   : Synapse.Core.Text_Lists.Vector;
   begin
      if not Templates_In (Target).Is_Empty then
         return Installed.Failure
           (To_Unbounded_String
              (Target & " already holds templates; nothing installed"));
      end if;
      if Shipped.Is_Empty then
         return Installed.Failure
           (To_Unbounded_String ("the package ships no default template set"));
      end if;
      --  Everything is read before anything is written, so a template that
      --  cannot be read leaves no partial set behind.
      for T of Shipped loop
         declare
            Text   : Unbounded_String;
            Status : Files.Read_Status;
         begin
            Files.Read (To_String (T.Path), Largest_Template, Text, Status);
            if Status /= Files.Read_Ok then
               return Installed.Failure
                 (To_Unbounded_String
                    ("cannot read " & To_String (T.Path)));
            end if;
            Texts.Append (Text);
         end;
      end loop;
      Ada.Directories.Create_Path (Target);
      for I in 1 .. Natural (Shipped.Length) loop
         declare
            Destination : constant String :=
              Target & "/" & To_String (Shipped (I).Kind) & Suffix;
         begin
            Synapse.Adapters.File_Bytes.Write
              (Destination, To_String (Texts (I)));
            Copies.Append
              (Template'(Kind => Shipped (I).Kind,
                         Path => To_Unbounded_String (Destination)));
         end;
      end loop;
      return Installed.Success (Copies);
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         return Installed.Failure
           (To_Unbounded_String ("cannot copy the default templates into "
                                 & Target));
   end Install;

end Synapse_Bard.Templates;
