with Ada.Directories;
with Ada.Exceptions;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;

with Synapse.Adapters.File_Bytes;

package body Synapse_Bard.Manuscript is

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   LF : constant Character := Character'Val (10);
   CR : constant Character := Character'Val (13);

   Largest_File : constant := 2**26;

   --  Raised inside this package with the reason a manuscript is refused;
   --  Load turns it into a failed result.
   Refused : exception;

   procedure Refuse (Message : String) with No_Return is
   begin
      Ada.Exceptions.Raise_Exception (Refused'Identity, Message);
   end Refuse;

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   ---------------------------------------------------------------------------
   --  Names
   ---------------------------------------------------------------------------

   function Unslugify (Name : String) return String is
      Last   : constant Natural :=
        (if Name'Length >= 3 and then Name (Name'Last - 2 .. Name'Last) = ".md"
         then Name'Last - 3
         else Name'Last);
      Result : String := Name (Name'First .. Last);
      Slug   : constant Boolean :=
        (for some C of Result => C in '_' | '-')
        and then (for all C of Result => C /= ' ');
   begin
      if not Slug then
         return Result;
      end if;
      for C of Result loop
         if C in '_' | '-' then
            C := ' ';
         end if;
      end loop;
      if Result'Length > 0 and then Result (Result'First) in 'a' .. 'z' then
         Result (Result'First) :=
           Character'Val
             (Character'Pos (Result (Result'First))
              - Character'Pos ('a') + Character'Pos ('A'));
      end if;
      return Result;
   end Unslugify;

   ---------------------------------------------------------------------------
   --  Files
   ---------------------------------------------------------------------------

   --  The lines of Text without their line feed or carriage return. A final
   --  line feed does not start another line.
   function Split_Lines (Text : String) return Synapse.Core.Text_Lists.Vector
   is
      Result : Synapse.Core.Text_Lists.Vector;
      Start  : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = LF then
            declare
               Stop : constant Natural :=
                 (if I > Start and then Text (I - 1) = CR then I - 2
                  else I - 1);
            begin
               Result.Append (To_Unbounded_String (Text (Start .. Stop)));
            end;
            Start := I + 1;
         end if;
      end loop;
      if Start <= Text'Last then
         Result.Append (To_Unbounded_String (Text (Start .. Text'Last)));
      end if;
      return Result;
   end Split_Lines;

   function Read_File (Path : String) return String is
   begin
      return Synapse.Adapters.File_Bytes.Read (Path, Largest_File);
   exception
      when Synapse.Adapters.File_Bytes.Too_Large =>
         Refuse (Path & ": larger than the manuscript limit");
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         Refuse (Path & ": cannot be read");
   end Read_File;

   function Is_Directory (Path : String) return Boolean is
     (Ada.Directories.Exists (Path)
      and then Ada.Directories.Kind (Path) = Ada.Directories.Directory);

   function Is_File (Path : String) return Boolean is
     (Ada.Directories.Exists (Path)
      and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File);

   ---------------------------------------------------------------------------
   --  Index files
   ---------------------------------------------------------------------------

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   --  Whether Entry names a place under the folder holding the index: not
   --  absolute and with no `.` or `..` part.
   function Stays_Inside (Item : String) return Boolean is
      Start : Positive := Item'First;
   begin
      if Item'Length = 0 or else Item (Item'First) = '/' then
         return False;
      end if;
      for I in Item'First .. Item'Last + 1 loop
         if I > Item'Last or else Item (I) = '/' then
            declare
               Part : constant String := Item (Start .. I - 1);
            begin
               if Part = "." or else Part = ".." then
                  return False;
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;
      return True;
   end Stays_Inside;

   --  The paths an index lists, in order: its ordered-list items. Blank lines
   --  are skipped; any other line is a refusal.
   function Index_Entries
     (Origin, Text : String) return Synapse.Core.Text_Lists.Vector
   is
      Lines  : constant Synapse.Core.Text_Lists.Vector := Split_Lines (Text);
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for N in 1 .. Natural (Lines.Length) loop
         declare
            Line : constant String :=
              Ada.Strings.Fixed.Trim
                (To_String (Lines (N)), Ada.Strings.Both);
            Where : constant String := Origin & ":" & Image (N) & ": ";
            Digits_End : Natural := Line'First - 1;
         begin
            if Line'Length > 0 then
               while Digits_End < Line'Last
                 and then Is_Digit (Line (Digits_End + 1))
               loop
                  Digits_End := Digits_End + 1;
               end loop;
               if Digits_End = Line'First - 1
                 or else Digits_End + 2 > Line'Last
                 or else Line (Digits_End + 1) not in '.' | ')'
                 or else Line (Digits_End + 2) /= ' '
               then
                  Refuse (Where & "not an ordered list item");
               end if;
               declare
                  Item : constant String :=
                    Ada.Strings.Fixed.Trim
                      (Line (Digits_End + 3 .. Line'Last), Ada.Strings.Both);
                  Last : constant Natural :=
                    (if Item'Length > 0 and then Item (Item'Last) = '/'
                     then Item'Last - 1
                     else Item'Last);
               begin
                  if not Stays_Inside (Item (Item'First .. Last)) then
                     Refuse
                       (Where & "'" & Item
                        & "' is not a path inside the folder");
                  end if;
                  Result.Append
                    (To_Unbounded_String (Item (Item'First .. Last)));
               end;
            end if;
         end;
      end loop;
      if Result.Is_Empty then
         Refuse (Origin & ": lists no paths");
      end if;
      return Result;
   end Index_Entries;

   ---------------------------------------------------------------------------
   --  Books
   ---------------------------------------------------------------------------

   function Folder_Book (Dir : String) return Book is
      Index   : constant String := Dir & "/index.md";
      Entries : Synapse.Core.Text_Lists.Vector;
      Result  : Book;
   begin
      if not Is_File (Index) then
         Refuse (Dir & ": a book folder needs an index.md");
      end if;
      Entries := Index_Entries (Index, Read_File (Index));
      Result.Title :=
        To_Unbounded_String (Unslugify (Ada.Directories.Simple_Name (Dir)));
      for Item of Entries loop
         declare
            Path : constant String := Dir & "/" & To_String (Item);
         begin
            if not Is_File (Path) then
               Refuse (Index & ": '" & To_String (Item) & "' is not a file");
            end if;
            Result.Chapters.Append
              (Chapter'
                 (Name  =>
                    To_Unbounded_String
                      (Unslugify (Ada.Directories.Simple_Name (Path))),
                  File  => To_Unbounded_String (Path),
                  First => 1,
                  Last  => Natural (Split_Lines (Read_File (Path)).Length)));
         end;
      end loop;
      return Result;
   end Folder_Book;

   --  The text of a heading line after its `#`s, or "" when Line is not a
   --  heading of exactly Level `#`s followed by a space.
   function Heading_Text (Line : String; Level : Positive) return String is
      Marks : constant String (1 .. Level) := [others => '#'];
   begin
      if Line'Length > Level
        and then Line (Line'First .. Line'First + Level - 1) = Marks
        and then Line (Line'First + Level) = ' '
      then
         return Ada.Strings.Fixed.Trim
           (Line (Line'First + Level + 1 .. Line'Last), Ada.Strings.Both);
      end if;
      return "";
   end Heading_Text;

   function Is_Heading (Line : String; Level : Positive) return Boolean is
      Marks : constant String (1 .. Level) := [others => '#'];
   begin
      return Line'Length > Level
        and then Line (Line'First .. Line'First + Level - 1) = Marks
        and then Line (Line'First + Level) = ' ';
   end Is_Heading;

   function File_Book (Path : String) return Book is
      Lines       : constant Synapse.Core.Text_Lists.Vector :=
        Split_Lines (Read_File (Path));
      Total       : constant Natural := Natural (Lines.Length);
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
            Line  : constant String := To_String (Lines (N));
            Where : constant String := Path & ":" & Image (N) & ": ";
            Blank : constant Boolean :=
              Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both)'Length = 0;
         begin
            if Is_Heading (Line, 1) then
               if Seen_Title then
                  Refuse (Where & "a second H1; a book has one title");
               end if;
               if Heading_Text (Line, 1) = "" then
                  Refuse (Where & "the H1 has no title");
               end if;
               Seen_Title := True;
               Result.Title := To_Unbounded_String (Heading_Text (Line, 1));
            elsif not Seen_Title then
               if not Blank then
                  Refuse (Where & "the first line of a book must be its H1");
               end if;
            elsif Is_Heading (Line, 2) then
               if Heading_Text (Line, 2) = "" then
                  Refuse (Where & "the H2 has no chapter name");
               end if;
               Close (N - 1);
               Current :=
                 (Name  => To_Unbounded_String (Heading_Text (Line, 2)),
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
        (if Is_Directory (Root) then Ada.Directories.Full_Name (Root) else "");
      Index   : constant String := Full & "/index.md";
      Result  : Series;
   begin
      if Full = "" then
         return Loaded.Failure
           (To_Unbounded_String (Root & ": not a folder"));
      end if;
      begin
         if not Is_File (Index) then
            Refuse (Full & ": a manuscript root needs an index.md");
         end if;
         for Item of Index_Entries (Index, Read_File (Index)) loop
            declare
               Path : constant String := Full & "/" & To_String (Item);
            begin
               if Is_Directory (Path) then
                  Result.Append (Folder_Book (Path));
               elsif Is_File (Path) then
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
         Lines : constant Synapse.Core.Text_Lists.Vector :=
           Split_Lines (Read_File (To_String (Item.File)));
      begin
         for N in Item.First .. Item.Last loop
            Result.Append (Lines (N));
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
         Append (Result, LF);
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
                     Lines : constant Synapse.Core.Text_Lists.Vector :=
                       Chapter_Lines (C);
                  begin
                     if Natural (Lines.Length) = C.Last - C.First + 1
                       and then Ada.Strings.Fixed.Index
                         (To_String (Lines (Line - C.First + 1)), Quote) > 0
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
