with Ada.Strings.Unbounded;

with Synapse.Core.Frontmatter;
with Synapse.Core.Wikilinks;

package body Synapse_Bard.Frontmatter_Fields is

   package FM renames Synapse.Core.Frontmatter;

   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   function Line_Text (Source : String; Item : FM.Span) return String is
     (Source (Source'First + Item.First .. Source'First + Item.Stop - 1));

   --  A line a root key can start on: not blank, indented or a comment.
   function Starts_Root_Key (Line : String) return Boolean is
     (Line'Length > 0 and then Line (Line'First) not in ' ' | ASCII.HT | '#');

   function Key_Of (Line : String) return String is
      Found      : Boolean;
      Key, Value : FM.Span;
   begin
      FM.Split_Key_Value (Line, Found, Key, Value);
      if Found then
         return Line (Line'First + Key.First .. Line'First + Key.Stop - 1);
      else
         return "";
      end if;
   end Key_Of;

   function Has_Block (Source : String) return Boolean is
     (FM.Has_Frontmatter (Source));

   function Block (Source : String) return Maybe_Text is
      Located : constant FM.Block := FM.Locate (Source);
   begin
      if not Located.Present then
         return Synapse.Core.Optional_Text.None;
      end if;
      return Synapse.Core.Optional_Text.Of_Value
        (To_Unbounded_String
           (Source (Source'First .. Source'First + Located.Body_Start - 1)));
   end Block;

   function Root_Keys (Source : String) return Synapse.Core.Text_Lists.Vector
   is
      Located  : constant FM.Block := FM.Locate (Source);
      Result   : Synapse.Core.Text_Lists.Vector;
      Position : Natural;
      Item     : FM.Span;
      Found    : Boolean;
   begin
      if not Located.Present then
         return Result;
      end if;
      Position := Located.Lines_Start;
      loop
         FM.Next_Line (Source, Located, Position, Item, Found);
         exit when not Found;
         declare
            Line : constant String := Line_Text (Source, Item);
         begin
            if Starts_Root_Key (Line) then
               declare
                  Key : constant String := Key_Of (Line);
               begin
                  if Key'Length > 0 then
                     Result.Append (To_Unbounded_String (Key));
                  end if;
               end;
            end if;
         end;
      end loop;
      return Result;
   end Root_Keys;

   function Raw_Field (Source, Key : String) return Maybe_Text is
      Located   : constant FM.Block := FM.Locate (Source);
      Position  : Natural;
      Item      : FM.Span;
      Found     : Boolean;
      Capturing : Boolean := False;
      Output    : Unbounded_String;
   begin
      if not Located.Present then
         return Synapse.Core.Optional_Text.None;
      end if;
      Position := Located.Lines_Start;
      loop
         FM.Next_Line (Source, Located, Position, Item, Found);
         exit when not Found;
         declare
            Line : constant String := Line_Text (Source, Item);
         begin
            if Capturing then
               --  A non-blank line back at column zero ends the block; a
               --  blank line inside it does not.
               exit when Line'Length > 0 and then Line (Line'First) /= ' ';
               Append (Output, Line & LF);
            elsif Starts_Root_Key (Line) and then Key_Of (Line) = Key then
               Append (Output, Line & LF);
               Capturing := True;
            end if;
         end;
      end loop;
      if not Capturing then
         return Synapse.Core.Optional_Text.None;
      end if;
      return Synapse.Core.Optional_Text.Of_Value (Output);
   end Raw_Field;

   function Wikilink_Targets
     (Text : String) return Synapse.Core.Text_Lists.Vector is
     (Synapse.Core.Wikilinks.Extract (Text));

end Synapse_Bard.Frontmatter_Fields;
