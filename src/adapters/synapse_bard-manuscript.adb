with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Synapse.Core.Decimal_Image;

with Synapse_Bard.Files;
with Synapse_Bard.Lines;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Manuscript is

   use Ada.Strings.Unbounded;
   use Synapse.Core.Decimal_Image;

   Largest_File : constant := 2**26;

   --  Raised inside this package with the reason a manuscript is refused;
   --  Load turns it into a failed result.
   Refused : exception;

   procedure Refuse (Message : String) with No_Return is
   begin
      Ada.Exceptions.Raise_Exception (Refused'Identity, Message);
   end Refuse;

   function Read_File (Path : String) return String is
      Text   : Unbounded_String;
      Status : Files.Read_Status;
   begin
      Files.Read (Path, Largest_File, Text, Status);
      case Status is
         when Files.Read_Ok =>
            return To_String (Text);
         when Files.Too_Large =>
            Refuse (Path & ": larger than the manuscript limit");
         when Files.Unreadable =>
            Refuse (Path & ": cannot be read");
      end case;
   end Read_File;

   ---------------------------------------------------------------------------
   --  Index files
   ---------------------------------------------------------------------------

   --  The paths an index lists, in order: its ordered-list items. Blank lines
   --  are skipped; any other line is a refusal.
   function Index_Entries
     (Origin, Text : String) return Synapse.Core.Text_Lists.Vector
   is
      Lines  : constant Synapse.Core.Text_Lists.Vector :=
        Synapse_Bard.Lines.Split (Text);
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for N in 1 .. Natural (Lines.Length) loop
         declare
            Line  : constant String := Syntax.Trim (To_String (Lines (N)));
            Where : constant String := Origin & ":" & Image (N) & ": ";
         begin
            if Line'Length > 0 then
               declare
                  Start : constant Natural := Syntax.Item_Start (Line);
               begin
                  if Start = 0 then
                     Refuse (Where & "not an ordered list item");
                  end if;
                  declare
                     Item : constant String :=
                       Syntax.Trim (Line (Start .. Line'Last));
                     Last : constant Natural :=
                       (if Item'Length > 0 and then Item (Item'Last) = '/'
                        then Item'Last - 1
                        else Item'Last);
                  begin
                     if not Syntax.Stays_Inside (Item (Item'First .. Last))
                     then
                        Refuse
                          (Where & "'" & Item
                           & "' is not a path inside the folder");
                     end if;
                     Result.Append
                       (To_Unbounded_String (Item (Item'First .. Last)));
                  end;
               end;
            end if;
         end;
      end loop;
      if Result.Is_Empty then
         Refuse (Origin & ": lists no paths");
      end if;
      return Result;
   end Index_Entries;

   --  Refuses Item, listed by the index Origin, when Base & "/" & Item passes
   --  through a symbolic link.
   procedure Refuse_Link (Origin, Base, Item : String) is
   begin
      if Files.Has_Link_Below (Base, Item) then
         Refuse
           (Origin & ": '" & Item & "' is or passes through a symbolic link");
      end if;
   end Refuse_Link;

   ---------------------------------------------------------------------------
   --  Books
   ---------------------------------------------------------------------------

   function Folder_Book (Dir : String) return Book is
      Index   : constant String := Dir & "/index.md";
      Entries : Synapse.Core.Text_Lists.Vector;
      Result  : Book;
   begin
      if not Files.Is_File (Index) then
         Refuse (Dir & ": a book folder needs an index.md");
      end if;
      Entries := Index_Entries (Index, Read_File (Index));
      Result.Title :=
        To_Unbounded_String
          (Syntax.Unslugify (Ada.Directories.Simple_Name (Dir)));
      for Item of Entries loop
         declare
            Path : constant String := Dir & "/" & To_String (Item);
         begin
            Refuse_Link (Index, Dir, To_String (Item));
            if not Files.Is_File (Path) then
               Refuse (Index & ": '" & To_String (Item) & "' is not a file");
            end if;
            Result.Chapters.Append
              (Chapter'
                 (Name  =>
                    To_Unbounded_String
                      (Syntax.Unslugify (Ada.Directories.Simple_Name (Path))),
                  File  => To_Unbounded_String (Path),
                  First => 1,
                  Last  =>
                    Natural
                      (Lines.Split (Read_File (Path)).Length)));
         end;
      end loop;
      return Result;
   end Folder_Book;

   function File_Book (Path : String) return Book is
      Text        : constant Synapse.Core.Text_Lists.Vector :=
        Lines.Split (Read_File (Path));
      Total       : constant Natural := Natural (Text.Length);
      Result      : Book;
      Seen_Title  : Boolean := False;
      Open        : Boolean := False;
      Current     : Chapter;

      procedure Close (Last : Natural) is
      begin
         if Open then
            Current.Last := Last;
            Result.Chapters.Append (Current);
            Open := False;
         end if;
      end Close;
   begin
      for N in 1 .. Total loop
         declare
            Line  : constant String := To_String (Text (N));
            Where : constant String := Path & ":" & Image (N) & ": ";
            Blank : constant Boolean := Syntax.Trim (Line)'Length = 0;
         begin
            if Syntax.Is_Heading (Line, 1) then
               if Seen_Title then
                  Refuse (Where & "a second H1; a book has one title");
               end if;
               if Syntax.Heading_Text (Line, 1) = "" then
                  Refuse (Where & "the H1 has no title");
               end if;
               Seen_Title := True;
               Result.Title :=
                 To_Unbounded_String (Syntax.Heading_Text (Line, 1));
            elsif not Seen_Title then
               if not Blank then
                  Refuse (Where & "the first line of a book must be its H1");
               end if;
            elsif Syntax.Is_Heading (Line, 2) then
               if Syntax.Heading_Text (Line, 2) = "" then
                  Refuse (Where & "the H2 has no chapter name");
               end if;
               Close (N - 1);
               Current :=
                 (Name  => To_Unbounded_String (Syntax.Heading_Text (Line, 2)),
                  File  => To_Unbounded_String (Path),
                  First => N + 1,
                  Last  => N);
               Open := True;
            elsif not Open and then not Blank then
               Refuse (Where & "text between the title and the first chapter");
            end if;
         end;
      end loop;
      Close (Total);
      if not Seen_Title then
         Refuse (Path & ": has no H1");
      end if;
      if Result.Chapters.Is_Empty then
         Refuse (Path & ": has no H2 chapters");
      end if;
      return Result;
   end File_Book;

   function Load (Root : String) return Loaded.Result is
      Full    : constant String :=
        (if Files.Is_Directory (Root) then Ada.Directories.Full_Name (Root)
         else "");
      Index   : constant String := Full & "/index.md";
      Result  : Series;
   begin
      if Full = "" then
         return Loaded.Failure
           (To_Unbounded_String (Root & ": not a folder"));
      end if;
      begin
         if not Files.Is_File (Index) then
            Refuse (Full & ": a manuscript root needs an index.md");
         end if;
         for Item of Index_Entries (Index, Read_File (Index)) loop
            declare
               Path : constant String := Full & "/" & To_String (Item);
            begin
               Refuse_Link (Index, Full, To_String (Item));
               if Files.Is_Directory (Path) then
                  Result.Append (Folder_Book (Path));
               elsif Files.Is_File (Path) then
                  Result.Append (File_Book (Path));
               else
                  Refuse
                    (Index & ": '" & To_String (Item) & "' does not exist");
               end if;
            end;
         end loop;
      exception
         when E : Refused =>
            return Loaded.Failure
              (To_Unbounded_String (Ada.Exceptions.Exception_Message (E)));
      end;
      return Loaded.Success (Result);
   end Load;

   function Chapter_Lines
     (Item : Chapter) return Synapse.Core.Text_Lists.Vector
   is
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      if Item.Last < Item.First then
         return Result;
      end if;
      declare
         Text : constant Synapse.Core.Text_Lists.Vector :=
           Lines.Split (Read_File (To_String (Item.File)));
      begin
         for N in Item.First .. Item.Last loop
            Result.Append (Text (N));
         end loop;
      end;
      return Result;
   exception
      when Refused | Constraint_Error =>
         Result.Clear;
         return Result;
   end Chapter_Lines;

   function Chapter_Text (Item : Chapter) return String is
      Result : Unbounded_String;
   begin
      for Line of Chapter_Lines (Item) loop
         Append (Result, Line);
         Append (Result, Syntax.LF);
      end loop;
      return To_String (Result);
   end Chapter_Text;

   function Holds_Quote
     (Books : Series; Book_Title, Chapter_Name : String; Line : Positive;
      Quote : String) return Boolean is
   begin
      if Quote = "" then
         return False;
      end if;
      for B of Books loop
         if To_String (B.Title) = Book_Title then
            for C of B.Chapters loop
               if To_String (C.Name) = Chapter_Name
                 and then Line in C.First .. C.Last
               then
                  declare
                     Text : constant Synapse.Core.Text_Lists.Vector :=
                       Chapter_Lines (C);
                  begin
                     if Natural (Text.Length) = C.Last - C.First + 1
                       and then Ada.Strings.Fixed.Index
                         (To_String (Text (Line - C.First + 1)), Quote) > 0
                     then
                        return True;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
      return False;
   end Holds_Quote;

end Synapse_Bard.Manuscript;
