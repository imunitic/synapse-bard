with Ada.Characters.Handling;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;
with Synapse.Core.Graph_Model;

with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Frontmatter_Extractor is

   use Ada.Strings.Unbounded;

   package Tag_Payload renames Synapse.Core.Tag_Payload;
   package Graph_Model renames Synapse.Core.Graph_Model;

   --  A file over this many bytes is not read.
   Largest_Note : constant := 2**20;

   --  Refuse past this many nested-map levels: a generous multiple of what
   --  real data needs (three), kept as a guard against runaway indentation.
   Max_Frames : constant := 8;

   Identity_Field : constant String := "name";
   Kind_Field     : constant String := "template";

   LF : constant Character := Synapse_Bard.Syntax.LF;
   CR : constant Character := Synapse_Bard.Syntax.CR;
   HT : constant Character := Character'Val (9);

   function Name (Reason : Refusal) return String is
     (Ada.Characters.Handling.To_Lower (Reason'Image));

   ---------------------------------------------------------------------------
   --  Text helpers
   ---------------------------------------------------------------------------

   function Trim_Blanks (S : String) return String is
     (Ada.Strings.Fixed.Trim (S, Ada.Strings.Both));

   function Trim_CR (S : String) return String is
      Last : Integer := S'Last;
   begin
      while Last >= S'First and then S (Last) = CR loop
         Last := Last - 1;
      end loop;
      return S (S'First .. Last);
   end Trim_CR;

   function Starts_With (S, Prefix : String) return Boolean is
     (S'Length >= Prefix'Length
      and then S (S'First .. S'First + Prefix'Length - 1) = Prefix);

   function Ends_With (S, Suffix : String) return Boolean is
     (S'Length >= Suffix'Length
      and then S (S'Last - Suffix'Length + 1 .. S'Last) = Suffix);

   function Unquote (Value : String) return String is
     (if Value'Length >= 2
        and then Value (Value'First) in '"' | '''
        and then Value (Value'Last) = Value (Value'First)
      then Value (Value'First + 1 .. Value'Last - 1)
      else Value);

   function Is_Wikilink (Value : String) return Boolean is
      Inner : constant String := Unquote (Value);
   begin
      return Starts_With (Inner, "[[") and then Ends_With (Inner, "]]");
   end Is_Wikilink;

   --  The first `:` outside a quoted span; 0 when there is none, meaning the
   --  text is a bare value and not a `key: value` pair.
   function Top_Level_Colon (Body_Text : String) return Natural is
      Quote : Character := ASCII.NUL;
   begin
      for I in Body_Text'Range loop
         declare
            C : constant Character := Body_Text (I);
         begin
            if Quote /= ASCII.NUL then
               if C = Quote then
                  Quote := ASCII.NUL;
               end if;
            elsif C in '"' | ''' then
               Quote := C;
            elsif C = ':' then
               return I;
            end if;
         end;
      end loop;
      return 0;
   end Top_Level_Colon;

   --  Whether Text holds a closing `]` outside any quoted span.
   function Has_Top_Level_Close (Text : String) return Boolean is
      Quote : Character := ASCII.NUL;
   begin
      for C of Text loop
         if Quote /= ASCII.NUL then
            if C = Quote then
               Quote := ASCII.NUL;
            end if;
         elsif C in '"' | ''' then
            Quote := C;
         elsif C = ']' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Top_Level_Close;

   --  A flow-list element this reader accepts: a quoted string, a bare
   --  wikilink, or a bare word with no nested-structure characters.
   function Is_Scalar_Element (Element : String) return Boolean is
   begin
      if Element'Length >= 2
        and then Element (Element'First) in '"' | '''
        and then Element (Element'Last) = Element (Element'First)
      then
         return True;
      end if;
      if Is_Wikilink (Element) then
         return True;
      end if;
      return
        not (for some C of Element => C in ':' | '{' | '[' | '"' | ''');
   end Is_Scalar_Element;

   ---------------------------------------------------------------------------
   --  The scan
   ---------------------------------------------------------------------------

   --  One nested-map level on the path from the root to the field being read.
   --  Indent is the column its own `key:` line started at.
   type Frame is record
      Indent : Natural;
      Key    : Unbounded_String;
   end record;

   package Frame_Vectors is new Ada.Containers.Vectors (Positive, Frame);

   Note_Refused : exception;

   --  The root `template:` value, searched on its own so that the order of
   --  fields does not matter; empty when there is none.
   function Root_Kind (Source : String) return Unbounded_String is
      Position : Positive := Source'First;
      Finished : Boolean := False;
      Skipped  : Boolean := False;
   begin
      loop
         exit when Finished;
         declare
            Stop  : Natural := Position;
            First : constant Positive := Position;
         begin
            while Stop <= Source'Last and then Source (Stop) /= LF loop
               Stop := Stop + 1;
            end loop;
            if Stop > Source'Last then
               Finished := True;
            end if;
            Position := Stop + 1;
            if not Skipped then
               Skipped := True;  --  the opening fence
            else
               declare
                  Line : constant String :=
                    Trim_CR (Source (First .. Stop - 1));
               begin
                  exit when Line = "---";
                  if Line'Length > 0 and then Line (Line'First) not in ' ' | HT
                  then
                     declare
                        Colon : constant Natural :=
                          Ada.Strings.Fixed.Index (Line, ":");
                     begin
                        if Colon /= 0
                          and then Trim_Blanks (Line (Line'First .. Colon - 1))
                                   = Kind_Field
                        then
                           return
                             To_Unbounded_String
                               (Unquote
                                  (Trim_Blanks
                                     (Line (Colon + 1 .. Line'Last))));
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      return Null_Unbounded_String;
   end Root_Kind;

   function Joined (Frames : Frame_Vectors.Vector; Key : String) return String
   is
      Result : Unbounded_String;
   begin
      for F of Frames loop
         Append (Result, F.Key);
         Append (Result, '.');
      end loop;
      Append (Result, Key);
      return To_String (Result);
   end Joined;

   procedure Scan
     (Source : String; Tags : out Tag_Payload.Tag_Vectors.Vector;
      Result : out Maybe_Refusal)
   is
      Cursor   : Positive := Source'First;
      Finished : Boolean := False;
      Row      : Natural := 0;
      Frames   : Frame_Vectors.Vector;
      Closed   : Boolean := False;
      Kind     : Unbounded_String;

      procedure Refuse (Why : Refusal) is
      begin
         Result := Maybe_Refusal'(Refused => True, Why => Why);
         raise Note_Refused;
      end Refuse;

      --  The next line, without its line feed. Pieces are split on LF alone,
      --  so a text ending in LF has a last, empty piece.
      procedure Next_Piece (Line : out Unbounded_String; Found : out Boolean)
      is
         Stop : Natural := Cursor;
      begin
         if Finished then
            Line := Null_Unbounded_String;
            Found := False;
            return;
         end if;
         while Stop <= Source'Last and then Source (Stop) /= LF loop
            Stop := Stop + 1;
         end loop;
         Line := To_Unbounded_String (Source (Cursor .. Stop - 1));
         Found := True;
         if Stop > Source'Last then
            Finished := True;
         else
            Cursor := Stop + 1;
         end if;
      end Next_Piece;

      procedure Add (Which : Graph_Model.Role; Name, Of_Kind, Line : String)
      is
      begin
         Tags.Append
           (Graph_Model.Tag'
              (Name       => To_Unbounded_String (Name),
               Kind       => To_Unbounded_String (Of_Kind),
               Which      => Which,
               Line       => Row,
               Expression => To_Unbounded_String (Line)));
      end Add;

      --  Every `[[wikilink]]` in Value becomes its own ref.
      procedure Scan_Value (Qualified_Key, Value, Line : String) is
         Targets : constant Synapse.Core.Text_Lists.Vector :=
           Frontmatter_Fields.Wikilink_Targets (Unquote (Value));
      begin
         for Target of Targets loop
            Add (Graph_Model.Ref, To_String (Target), Qualified_Key, Line);
         end loop;
      end Scan_Value;

      --  `key: [elem, elem, ...]`. Every element must be a scalar (itself
      --  scanned for wikilinks), or the whole file is refused.
      procedure Scan_Flow_List (Key, Value, Line : String) is
      begin
         if not Ends_With (Value, "]") then
            Refuse (Flow_Collection);
         end if;
         declare
            Inner : constant String :=
              Trim_Blanks (Value (Value'First + 1 .. Value'Last - 1));
         begin
            if Inner'Length = 0 then
               return;
            end if;
            declare
               Qualified : constant String := Joined (Frames, Key);
               Quote     : Character := ASCII.NUL;
               Start     : Positive := Inner'First;
            begin
               for I in Inner'First .. Inner'Last + 1 loop
                  declare
                     C : constant Character :=
                       (if I > Inner'Last then ',' else Inner (I));
                  begin
                     if Quote /= ASCII.NUL then
                        if C = Quote then
                           Quote := ASCII.NUL;
                        end if;
                     elsif C in '"' | ''' then
                        Quote := C;
                     elsif C in '{' | '[' then
                        Refuse (Flow_Collection);
                     elsif C = ',' then
                        declare
                           Element : constant String :=
                             Trim_Blanks (Inner (Start .. I - 1));
                        begin
                           if Element'Length = 0
                             or else not Is_Scalar_Element (Element)
                           then
                              Refuse (Flow_Collection);
                           end if;
                           Scan_Value (Qualified, Element, Line);
                           Start := I + 1;
                        end;
                     end if;
                  end;
               end loop;
               if Quote /= ASCII.NUL then
                  Refuse (Flow_Collection);
               end if;
            end;
         end;
      end Scan_Flow_List;

      Piece : Unbounded_String;
      Got   : Boolean;

      --  `key: [` with no `]` on its line: keep reading lines until the
      --  closing bracket, then scan the joined list.
      procedure Scan_Spanning_Flow_List (Key, Value, Line : String) is
         Buffer : Unbounded_String := To_Unbounded_String (Value);
      begin
         while not Has_Top_Level_Close (To_String (Buffer)) loop
            Next_Piece (Piece, Got);
            if not Got then
               Refuse (Malformed_Line);
            end if;
            Row := Row + 1;
            declare
               Continued : constant String := Trim_CR (To_String (Piece));
               Stripped  : constant String := Trim_Blanks (Continued);
            begin
               if (for some C of Continued => C = HT) then
                  Refuse (Tab_Indent);
               end if;
               if Stripped = "---" then
                  Refuse (Malformed_Line);
               end if;
               Append (Buffer, ' ' & Stripped);
            end;
         end loop;
         Scan_Flow_List (Key, To_String (Buffer), Line);
      end Scan_Spanning_Flow_List;

      --  A `key: value` pair with a non-empty value.
      procedure Read_Pair (Key, Value, Line : String) is
      begin
         case Value (Value'First) is
            when '&' | '*' =>
               Refuse (Anchor_Or_Alias);

            when '|' | '>' =>
               Refuse (Block_Scalar);

            when '{' =>
               --  Only an empty flow map is accepted.
               if not Ends_With (Value, "}")
                 or else Trim_Blanks
                           (Value (Value'First + 1 .. Value'Last - 1))'Length
                         /= 0
               then
                  Refuse (Flow_Collection);
               end if;

            when '[' =>
               if Is_Wikilink (Value) then
                  --  `[[Target]]` is also valid flow syntax; scanned like
                  --  any scalar.
                  Scan_Value (Joined (Frames, Key), Value, Line);
               else
                  Scan_Spanning_Flow_List (Key, Value, Line);
               end if;

            when others =>
               if Frames.Is_Empty and then Key = Identity_Field then
                  Add
                    (Graph_Model.Def, Unquote (Value),
                     (if Length (Kind) = 0 then "entity"
                      else To_String (Kind)),
                     Line);
               elsif Frames.Is_Empty and then Key = Kind_Field then
                  null;  --  names no other entity
               else
                  Scan_Value (Joined (Frames, Key), Value, Line);
               end if;
         end case;
      end Read_Pair;

      --  One line inside the frontmatter, not blank and not a comment.
      procedure Read_Line (Line : String; Indent : Natural) is
         Text      : constant String :=
           Line (Line'First + Indent .. Line'Last);
         Is_Item   : constant Boolean := Starts_With (Text, "- ");
         Item_Body : constant String :=
           (if Is_Item then Text (Text'First + 2 .. Text'Last) else Text);
         Colon     : constant Natural := Top_Level_Colon (Item_Body);
      begin
         if Text = "-" then
            return;  --  an empty list item
         end if;
         if Colon = 0 then
            --  A bare scalar list entry, under the key that owns the list.
            if not Is_Item or else Frames.Is_Empty then
               Refuse (Malformed_Line);
            end if;
            Scan_Value (To_String (Frames.Last_Element.Key), Item_Body, Line);
            return;
         end if;
         declare
            Key   : constant String :=
              Trim_Blanks (Item_Body (Item_Body'First .. Colon - 1));
            Value : constant String :=
              Trim_Blanks (Item_Body (Colon + 1 .. Item_Body'Last));
         begin
            if Key'Length = 0 then
               Refuse (Malformed_Line);
            end if;
            if Value'Length = 0 then
               --  Introduces a nested map, or a list the next lines walk into.
               if Natural (Frames.Length) >= Max_Frames then
                  Refuse (Nesting_Too_Deep);
               end if;
               Frames.Append
                 (Frame'(Indent => Indent, Key => To_Unbounded_String (Key)));
            else
               Read_Pair (Key, Value, Line);
            end if;
         end;
      end Read_Line;
   begin
      Tags.Clear;
      Result := Maybe_Refusal'(Refused => False);

      Next_Piece (Piece, Got);
      if Trim_CR (To_String (Piece)) /= "---" then
         Refuse (No_Frontmatter);
      end if;

      Kind := Root_Kind (Source);

      loop
         Next_Piece (Piece, Got);
         exit when not Got;
         Row := Row + 1;
         declare
            Line    : constant String := Trim_CR (To_String (Piece));
            Trimmed : constant String := Trim_Blanks (Line);
            Indent  : Natural := 0;
         begin
            if Line = "---" then
               Closed := True;
               exit;
            end if;
            if (for some C of Line => C = HT) then
               Refuse (Tab_Indent);
            end if;
            --  Blank lines and full-line comments carry no structure.
            if Trimmed'Length > 0 and then Trimmed (Trimmed'First) /= '#' then
               while Indent < Line'Length
                 and then Line (Line'First + Indent) = ' '
               loop
                  Indent := Indent + 1;
               end loop;
               --  Leave the frames this line has dedented out of.
               while not Frames.Is_Empty
                 and then Frames.Last_Element.Indent >= Indent
               loop
                  Frames.Delete_Last;
               end loop;
               Read_Line (Line, Indent);
            end if;
         end;
      end loop;

      if not Closed then
         Refuse (Unterminated);
      end if;
   exception
      when Note_Refused =>
         Tags.Clear;
   end Scan;

   overriding
   function Extract
     (E     : in out Extractor; Root : String;
      Paths :        Synapse.Core.Text_Lists.Vector)
      return Synapse.Ports.Extractor.Outcome_Vectors.Vector
   is
      Outcomes : Synapse.Ports.Extractor.Outcome_Vectors.Vector;
   begin
      E.Refusals.Clear;
      for Item of Paths loop
         declare
            Path    : constant String := To_String (Item);
            Reason  : Maybe_Refusal;
            Tags    : Tag_Payload.Tag_Vectors.Vector;
            Outcome : Synapse.Ports.Extractor.Outcome;
         begin
            if not Ends_With (Path, ".md") then
               Reason := Maybe_Refusal'(Refused => True, Why => Not_A_Note);
            else
               declare
                  Full : constant String :=
                    (if Root'Length = 0 then Path else Root & "/" & Path);
               begin
                  Scan
                    (Synapse.Adapters.File_Bytes.Read (Full, Largest_Note),
                     Tags, Reason);
                  if not Reason.Refused then
                     Outcome := (Kind => Synapse.Ports.Extractor.With_Tags,
                                 Tags => Tags);
                  end if;
               exception
                  when Synapse.Adapters.File_Bytes.Too_Large
                     | Ada.IO_Exceptions.Name_Error
                     | Ada.IO_Exceptions.Use_Error
                     | Ada.IO_Exceptions.Device_Error
                     | Ada.IO_Exceptions.End_Error
                     | Ada.IO_Exceptions.Data_Error =>
                     Reason := Maybe_Refusal'(Refused => False);
               end;
            end if;
            E.Refusals.Append (Reason);
            Outcomes.Append (Outcome);
         end;
      end loop;
      return Outcomes;
   end Extract;

   function Last_Refusal
     (E : Extractor; Index : Positive) return Maybe_Refusal is
     (E.Refusals (Index));

end Synapse_Bard.Frontmatter_Extractor;
