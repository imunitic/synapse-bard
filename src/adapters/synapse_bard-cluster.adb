with Ada.Strings.Fixed;

with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Cluster is

   use Ada.Strings.Unbounded;

   LF : constant Character := Synapse_Bard.Syntax.LF;

   --  U+2014 EM DASH in UTF-8.
   Em_Dash : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#94#)];

   Start_Marker : constant String := "<!-- synapse:generated:start -->";

   function Marker_At (Text : String) return Natural is
     (Ada.Strings.Fixed.Index (Text, End_Marker));

   function Preserved_Tail (Existing_Body : String) return String is
      Index : constant Natural := Marker_At (Existing_Body);
   begin
      if Index = 0 then
         return "";
      end if;
      return Existing_Body (Index + End_Marker'Length .. Existing_Body'Last);
   end Preserved_Tail;

   function Generated_Region (Body_Text : String) return String is
      Index : constant Natural := Marker_At (Body_Text);
   begin
      if Index = 0 then
         return Body_Text;
      end if;
      return Body_Text (Body_Text'First .. Index + End_Marker'Length - 1);
   end Generated_Region;

   function Is_Dirty (Existing : Maybe_Text; Computed : String) return Boolean
   is
   begin
      if not Existing.Found then
         return True;
      end if;
      return Generated_Region (To_String (Existing.Value))
        /= Generated_Region (Computed);
   end Is_Dirty;

   function Would_Remove
     (Existing, Planned : Synapse.Core.Text_Lists.Vector)
      return Synapse.Core.Text_Lists.Vector
   is
      Kept   : Synapse.Core.Text_Lists.Set;
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for Name of Planned loop
         Kept.Include (To_String (Name));
      end loop;
      for Name of Existing loop
         if not Kept.Contains (To_String (Name)) then
            Result.Append (Name);
         end if;
      end loop;
      return Result;
   end Would_Remove;

   function Render_Cluster_Body
     (Title : String; Entries : Write_Entry_Vectors.Vector; Tail : String)
      return String
   is
      Result : Unbounded_String;
   begin
      Append (Result, "---" & LF & "title: """ & Title & """" & LF);
      Append (Result, "sources:" & LF);
      for E of Entries loop
         Append
           (Result,
            "  - slug: """ & To_String (E.Slug) & """" & LF
            & "    path: """ & To_String (E.Path) & """" & LF);
      end loop;
      Append
        (Result,
         "---" & LF & LF & Start_Marker & LF & "## Entities" & LF);
      for E of Entries loop
         Append
           (Result,
            "- [[" & To_String (E.Slug) & "]] " & Em_Dash & " "
            & To_String (E.Name) & LF);
      end loop;
      Append (Result, End_Marker);
      Append (Result, Tail);
      return To_String (Result);
   end Render_Cluster_Body;

   function Cluster_Title (Rel_Path : String) return String is
      Result   : Unbounded_String;
      At_Start : Boolean := True;
   begin
      for C of Rel_Path loop
         if C = '/' then
            Append (Result, " - ");
            At_Start := True;
         else
            declare
               Mapped : Character := C;
            begin
               if At_Start and then Mapped in 'a' .. 'z' then
                  Mapped := Character'Val (Character'Pos (Mapped) - 32);
               end if;
               if Mapped in ':' | '*' | '?' | '"' | '<' | '>' | '|' then
                  Mapped := '_';
               end if;
               Append (Result, Mapped);
            end;
            At_Start := False;
         end if;
      end loop;
      return To_String (Result);
   end Cluster_Title;

   --  `  - slug: "severen"` gives `severen`: the fixed, always double-quoted
   --  shape written above. Nothing for anything else, rather than a guess.
   function Quoted_Value_After (Line, Key : String) return Maybe_Text is
      Index : constant Natural := Ada.Strings.Fixed.Index (Line, Key);
   begin
      if Index = 0 then
         return Synapse.Core.Optional_Text.None;
      end if;
      declare
         After : constant String :=
           Ada.Strings.Fixed.Trim
             (Line (Index + Key'Length .. Line'Last), Ada.Strings.Both);
      begin
         if After'Length < 2 or else After (After'First) /= '"'
           or else After (After'Last) /= '"'
         then
            return Synapse.Core.Optional_Text.None;
         end if;
         return Synapse.Core.Optional_Text.Of_Value
           (To_Unbounded_String (After (After'First + 1 .. After'Last - 1)));
      end;
   end Quoted_Value_After;

   function Parse_Sources (Cluster_Source : String)
      return Source_Entry_Vectors.Vector
   is
      Result : Source_Entry_Vectors.Vector;
      Raw    : constant Frontmatter_Fields.Maybe_Text :=
        Frontmatter_Fields.Raw_Field (Cluster_Source, "sources");
   begin
      if not Raw.Found then
         return Result;
      end if;
      declare
         Text     : constant String := To_String (Raw.Value);
         Position : Positive := Text'First;

         --  The next line of Text; False once there is none.
         procedure Next_Line (Line : out Unbounded_String; Found : out Boolean)
         is
            Stop : Natural := Position;
         begin
            if Position > Text'Last then
               Line := Null_Unbounded_String;
               Found := False;
               return;
            end if;
            while Stop <= Text'Last and then Text (Stop) /= LF loop
               Stop := Stop + 1;
            end loop;
            Line := To_Unbounded_String (Text (Position .. Stop - 1));
            Position := Stop + 1;
            Found := True;
         end Next_Line;

         Slug_Line, Path_Line : Unbounded_String;
         Got                  : Boolean;
      begin
         Next_Line (Slug_Line, Got);  --  the `sources:` line itself
         loop
            Next_Line (Slug_Line, Got);
            exit when not Got;
            if Ada.Strings.Fixed.Trim
                 (To_String (Slug_Line), Ada.Strings.Both)'Length /= 0
            then
               Next_Line (Path_Line, Got);
               exit when not Got;
               declare
                  Slug : constant Maybe_Text :=
                    Quoted_Value_After (To_String (Slug_Line), "slug:");
                  Path : constant Maybe_Text :=
                    Quoted_Value_After (To_String (Path_Line), "path:");
               begin
                  if Slug.Found and then Path.Found then
                     Result.Append
                       (Source_Entry'(Slug => Slug.Value,
                                      Path => Path.Value));
                  end if;
               end;
            end if;
         end loop;
      end;
      return Result;
   end Parse_Sources;

   function Resolve_Slug
     (S : in out Synapse.Ports.Store.Store'Class; Slug : String)
      return Source_Entry_Options.Option
   is
      Names : constant Synapse.Core.Text_Lists.Vector := S.List;
   begin
      for Name of Names loop
         declare
            Node : constant Synapse.Ports.Store.Maybe_Text :=
              S.Read (To_String (Name));
         begin
            if Node.Found then
               for Item of Parse_Sources (To_String (Node.Value)) loop
                  if To_String (Item.Slug) = Slug then
                     return Source_Entry_Options.Of_Value (Item);
                  end if;
               end loop;
            end if;
         end;
      end loop;
      return Source_Entry_Options.None;
   end Resolve_Slug;

   function All_Entities (S : in out Synapse.Ports.Store.Store'Class)
      return Source_Entry_Vectors.Vector
   is
      Names  : constant Synapse.Core.Text_Lists.Vector := S.List;
      Result : Source_Entry_Vectors.Vector;
   begin
      for Name of Names loop
         declare
            Node : constant Synapse.Ports.Store.Maybe_Text :=
              S.Read (To_String (Name));
         begin
            if Node.Found then
               Result.Append_Vector (Parse_Sources (To_String (Node.Value)));
            end if;
         end;
      end loop;
      return Result;
   end All_Entities;

end Synapse_Bard.Cluster;
