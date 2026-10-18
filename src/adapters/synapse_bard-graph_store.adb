with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Synapse.Core.Node_Path;
with Synapse.Core.Text_Search;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Graph_Store is

   use Ada.Strings.Unbounded;

   LF : constant Character := Synapse_Bard.Syntax.LF;
   CR : constant Character := Synapse_Bard.Syntax.CR;
   HT : constant Character := Character'Val (9);

   function Create (Root : String) return Graph_Store is
     (Port.Store with
        Root => To_Unbounded_String (Root),
        Disk => Synapse.Adapters.Disk_Store.Create (Root, ""));

   overriding
   function Read
     (S : in out Graph_Store; Node : String) return Port.Maybe_Text is
     (S.Disk.Read (Node));

   overriding
   function Write
     (S : in out Graph_Store; Node, Content : String) return Port.Write_Result
   is (S.Disk.Write (Node, Content));

   overriding
   function List (S : in out Graph_Store) return Synapse.Core.Text_Lists.Vector
   is (S.Disk.List);

   procedure Delete (S : in out Graph_Store; Node : String) is
   begin
      if not Synapse.Core.Node_Path.Is_Safe (Node) then
         raise Port.Unsafe_Node with Node;
      end if;
      declare
         Path : constant String := To_String (S.Root) & "/" & Node;
      begin
         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_File (Path);
         end if;
      exception
         when Ada.IO_Exceptions.Name_Error =>
            null;  --  gone between the check and the delete
      end;
   end Delete;

   ---------------------------------------------------------------------------
   --  Text helpers
   ---------------------------------------------------------------------------

   function Trim_Blanks (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Lower_ASCII (Text : String) return String is
      Result : String := Text;
   begin
      for C of Result loop
         if C in 'A' .. 'Z' then
            C := Character'Val (Character'Pos (C) + 32);
         end if;
      end loop;
      return Result;
   end Lower_ASCII;

   function Unquote (Value : String) return String is
     (if Value'Length >= 2
        and then Value (Value'First) in '"' | '''
        and then Value (Value'Last) = Value (Value'First)
      then Value (Value'First + 1 .. Value'Last - 1)
      else Value);

   ---------------------------------------------------------------------------
   --  Field queries
   ---------------------------------------------------------------------------

   type Field_Query (Valid : Boolean := False) is record
      case Valid is
         when True =>
            Key, Value : Unbounded_String;

         when False =>
            null;
      end case;
   end record;

   --  `faction:Some Name` gives key `faction` and value `Some Name`. Anything
   --  without exactly one colon, or with an empty key or value, is not a
   --  field query.
   function Parse_Field_Query (Query : String) return Field_Query is
      Colon : constant Natural := Ada.Strings.Fixed.Index (Query, ":");
   begin
      if Colon = 0
        or else Ada.Strings.Fixed.Index (Query (Colon + 1 .. Query'Last), ":")
                /= 0
      then
         return (Valid => False);
      end if;
      declare
         Key   : constant String :=
           Trim_Blanks (Query (Query'First .. Colon - 1));
         Value : constant String :=
           Trim_Blanks (Query (Colon + 1 .. Query'Last));
      begin
         if Key'Length = 0 or else Value'Length = 0 then
            return (Valid => False);
         end if;
         return
           (Valid => True, Key => To_Unbounded_String (Key),
            Value => To_Unbounded_String (Value));
      end;
   end Parse_Field_Query;

   function Field_Line (Body_Text, Key, Value : String) return Maybe_Text is
      Position : Positive := Body_Text'First;
      Opening  : Boolean := True;
   begin
      while Position <= Body_Text'Last + 1 loop
         declare
            Stop : Natural := Position;
         begin
            while Stop <= Body_Text'Last and then Body_Text (Stop) /= LF loop
               Stop := Stop + 1;
            end loop;
            declare
               Raw  : constant String := Body_Text (Position .. Stop - 1);
               Last : Natural := Raw'Last;
            begin
               while Last >= Raw'First and then Raw (Last) = CR loop
                  Last := Last - 1;
               end loop;
               declare
                  Line : constant String := Raw (Raw'First .. Last);
               begin
                  if Opening then
                     Opening := False;  --  the opening fence
                  elsif Line = "---" then
                     return Synapse.Core.Optional_Text.None;
                  elsif Line'Length > 0
                    and then Line (Line'First) not in ' ' | HT
                  then
                     declare
                        Colon : constant Natural :=
                          Ada.Strings.Fixed.Index (Line, ":");
                     begin
                        if Colon /= 0
                          and then Trim_Blanks (Line (Line'First .. Colon - 1))
                                   = Key
                        then
                           if Lower_ASCII
                                (Unquote
                                   (Trim_Blanks
                                      (Line (Colon + 1 .. Line'Last))))
                              = Lower_ASCII (Value)
                           then
                              return Synapse.Core.Optional_Text.Of_Value
                                (To_Unbounded_String (Line));
                           end if;
                           return Synapse.Core.Optional_Text.None;
                        end if;
                     end;
                  end if;
               end;
            end;
            Position := Stop + 1;
         end;
      end loop;
      return Synapse.Core.Optional_Text.None;
   end Field_Line;

   ---------------------------------------------------------------------------
   --  Search
   ---------------------------------------------------------------------------

   overriding
   function Search
     (S : in out Graph_Store; Query : String) return Port.Hit_Vectors.Vector
   is
      Field  : constant Field_Query := Parse_Field_Query (Query);
      Names  : constant Synapse.Core.Text_Lists.Vector := S.List;
      Result : Port.Hit_Vectors.Vector;
   begin
      for Name of Names loop
         declare
            Node : constant Port.Maybe_Text := S.Read (To_String (Name));
         begin
            if Node.Found then
               declare
                  Content : constant String := To_String (Node.Value);
               begin
                  if Field.Valid then
                     declare
                        Line : constant Maybe_Text :=
                          Field_Line
                            (Content, To_String (Field.Key),
                             To_String (Field.Value));
                     begin
                        if Line.Found then
                           Result.Append
                             (Port.Hit'(Node    => Name, Score => 1.0,
                                        Context => Line.Value));
                        end if;
                     end;
                  else
                     declare
                        Count : constant Natural :=
                          Synapse.Core.Text_Search.Count_Ignore_Case
                            (Content, Query);
                        Where : constant Synapse.Core.Text_Search.Maybe_Line :=
                          Synapse.Core.Text_Search.First_Matching_Line
                            (Content, Query);
                     begin
                        if Count > 0 then
                           Result.Append
                             (Port.Hit'
                                (Node    => Name, Score => Float (Count),
                                 Context =>
                                   To_Unbounded_String
                                     (if Where.Found
                                      then
                                        Content
                                          (Where.Value.First
                                           .. Where.Value.Last)
                                      else "")));
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      return Result;
   end Search;

end Synapse_Bard.Graph_Store;
