with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Synapse.Adapters.File_Bytes;
with Synapse.Core.Graph_Model;
with Synapse.Ports.Extractor;

package body Synapse_Bard.Frontmatter_Extractor.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use type Synapse.Core.Graph_Model.Role;
   use type Synapse.Ports.Extractor.Outcome_Kind;

   package Tag_Vectors renames Synapse.Core.Tag_Payload.Tag_Vectors;

   Def : constant Synapse.Core.Graph_Model.Role :=
     Synapse.Core.Graph_Model.Def;
   Ref : constant Synapse.Core.Graph_Model.Role :=
     Synapse.Core.Graph_Model.Ref;

   LF : constant String := [Character'Val (10)];
   HT : constant String := [Character'Val (9)];

   function L (Text : String) return String is (Text & LF);

   --  An entity with a list of objects three levels below the root.
   Widget : constant String :=
     L ("---") & L ("template: ""part""") & L ("name: ""Widget One""")
     & L ("owner: ""The Workshop""")
     & L ("tags: [""small"", ""brass"", ""round"", ""spare"", ""stock""]")
     & LF & L ("relationships:") & L ("  role_in_set: ""The Hub""")
     & L ("  key_relationships:") & L ("    - name: ""Gadget Two""")
     & L ("      link: ""[[gadget-two]]""")
     & L ("      kinds: [""fits_with"", ""same_batch""]")
     & L ("      type: ""Fitting""")
     & L ("      dynamic: ""Mounts on the left""")
     & L ("    - name: ""Sprocket""") & L ("      link: ""[[sprocket]]""")
     & L ("      kinds: [""driven_by""]") & L ("      type: ""Driver""") & LF
     & L ("accessories:") & L ("  fasteners:")
     & L ("    - name: ""Hex bolt""")
     & L ("      link: ""[[hex-bolt-set]]""")
     & L ("      description: ""Shipped with the part""") & L ("---") & LF
     & L ("Prose body, never parsed.");

   procedure Scan_Ok
     (Source : String; Tags : out Tag_Vectors.Vector)
   is
      Result : Maybe_Refusal;
   begin
      Scan (Source, Tags, Result);
      Assert
        (not Result.Refused,
         "refused: " & (if Result.Refused then Name (Result.Why) else ""));
   end Scan_Ok;

   function Count
     (Tags : Tag_Vectors.Vector; Which : Synapse.Core.Graph_Model.Role)
      return Natural
   is
      Total : Natural := 0;
   begin
      for Item of Tags loop
         if Item.Which = Which then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count;

   function Has_Ref
     (Tags : Tag_Vectors.Vector; Target, Kind : String) return Boolean is
     (for some Item of Tags =>
        Item.Which = Ref and then To_String (Item.Name) = Target
        and then To_String (Item.Kind) = Kind);

   function Refusal_Of (Source : String) return Maybe_Refusal is
      Tags   : Tag_Vectors.Vector;
      Result : Maybe_Refusal;
   begin
      Scan (Source, Tags, Result);
      Assert (Tags.Is_Empty, "a refused note gives no tags");
      return Result;
   end Refusal_Of;

   procedure A_Def_Is_The_Identity_And_Kind_Is_The_Template
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok (Widget, Tags);
      Assert (Count (Tags, Def) = 1, "one def");
      for Item of Tags loop
         if Item.Which = Def then
            Assert (To_String (Item.Name) = "Widget One", "name");
            Assert (To_String (Item.Kind) = "part", "kind");
            Assert (Item.Line = 2, "rows count from the opening fence");
         end if;
      end loop;
   end A_Def_Is_The_Identity_And_Kind_Is_The_Template;

   procedure Objects_Three_Levels_Deep_Keep_Their_Dotted_Paths
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok (Widget, Tags);
      Assert
        (Has_Ref (Tags, "gadget-two", "relationships.key_relationships.link"),
         "first object");
      Assert
        (Has_Ref (Tags, "sprocket", "relationships.key_relationships.link"),
         "second object");
      Assert
        (Has_Ref (Tags, "hex-bolt-set", "accessories.fasteners.link"),
         "another branch");
      Assert (Count (Tags, Ref) = 3, "flow lists of plain strings add none");
   end Objects_Three_Levels_Deep_Keep_Their_Dotted_Paths;

   procedure A_Flow_List_Of_Plain_Strings_Is_Not_A_Refusal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok (Widget, Tags);
      Assert (Count (Tags, Def) = 1, "parsed");
   end A_Flow_List_Of_Plain_Strings_Is_Not_A_Refusal;

   procedure Several_Wikilinks_In_One_Scalar_Are_Separate_Refs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""tool""") & L ("name: ""Bench Vise""")
         & L ("current_holder: ""[[widget-one|Widget One]] (active), "
              & "[[gadget-two|Gadget Two]] (issued, never used)""")
         & L ("---"),
         Tags);
      Assert (Has_Ref (Tags, "widget-one", "current_holder"), "first");
      Assert (Has_Ref (Tags, "gadget-two", "current_holder"), "second");
      Assert (Count (Tags, Ref) = 2, "exactly two");
   end Several_Wikilinks_In_One_Scalar_Are_Separate_Refs;

   procedure A_Flow_List_Mixing_Prose_And_Links_Resolves_Each_Element
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""set""") & L ("name: ""The Kit""")
         & L ("links:")
         & L ("  rivals: [""[[Sprocket]] (declared rival)"", "
              & """[[hex-bolt-set|Hex Bolts]] (internal rival)""]")
         & L ("---"),
         Tags);
      Assert (Has_Ref (Tags, "Sprocket", "links.rivals"), "first element");
      Assert
        (Has_Ref (Tags, "hex-bolt-set", "links.rivals"), "second element");
   end A_Flow_List_Mixing_Prose_And_Links_Resolves_Each_Element;

   procedure A_Bare_Scalar_Block_List_Uses_The_Parent_Key
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""tool""") & L ("name: ""Hand Saw""")
         & L ("previous_holders:") & L ("  - ""Corner shop (sold)""")
         & L ("  - ""[[gadget-two|Gadget Two]] (borrowed, left anonymously)""")
         & L ("---"),
         Tags);
      Assert (Has_Ref (Tags, "gadget-two", "previous_holders"), "qualified");
      Assert (Count (Tags, Ref) = 1, "only the entry with a link");
   end A_Bare_Scalar_Block_List_Uses_The_Parent_Key;

   procedure Without_A_Template_The_Kind_Is_Entity
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok (L ("---") & L ("name: Bare") & L ("---"), Tags);
      Assert (To_String (Tags (Tags.First_Index).Kind) = "entity", "default");
   end Without_A_Template_The_Kind_Is_Entity;

   procedure Everything_Outside_The_Subset_Is_Refused
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      procedure Check (Source : String; Why : Refusal; Index : Positive) is
         Result : constant Maybe_Refusal := Refusal_Of (Source);
      begin
         Assert
           (Result.Refused,
            "case" & Index'Image & " was accepted, not refused");
         Assert
           (Result.Why = Why,
            "case" & Index'Image & ": expected " & Name (Why) & ", got "
            & Name (Result.Why));
      end Check;
   begin
      Check (L ("---") & L ("name: A") & L ("base: &anchor x") & L ("---"),
             Anchor_Or_Alias, 1);
      Check (L ("---") & L ("name: A") & L ("same_as: *anchor") & L ("---"),
             Anchor_Or_Alias, 2);
      Check (L ("---") & L ("name: A") & L ("summary: |")
             & L ("  a paragraph") & L ("---"),
             Block_Scalar, 3);
      Check (L ("---") & L ("name: A") & L ("summary: >") & L ("  folded")
             & L ("---"),
             Block_Scalar, 4);
      Check (L ("---") & L ("name: A") & L ("refs: {a: b}") & L ("---"),
             Flow_Collection, 5);
      Check (L ("---") & L ("name: A") & L ("refs: [a: b]") & L ("---"),
             Flow_Collection, 6);
      Check (L ("---") & L ("name: A") & L ("list:") & L (HT & "- x")
             & L ("---"),
             Tab_Indent, 7);
      Check (L ("---") & L ("name: A") & L ("template: person"),
             Unterminated, 8);
      Check (L ("# Just prose") & LF & L ("No frontmatter here."),
             No_Frontmatter, 9);
      Check (L ("---") & L ("name: A") & L ("no colon on this line")
             & L ("---"),
             Malformed_Line, 10);
      Check (L ("---") & L ("- Orphan") & L ("---"), Malformed_Line, 11);
   end Everything_Outside_The_Subset_Is_Refused;

   procedure Empty_Lists_Are_Fine
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("name: A") & L ("tags: []") & L ("secrets: []")
         & L ("---"),
         Tags);
      Assert (Count (Tags, Ref) = 0, "no refs");
   end Empty_Lists_Are_Fine;

   procedure An_Empty_Flow_Map_Is_Fine_A_Non_Empty_One_Refuses
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("name: A") & L ("roles: {}") & L ("proficiency: { }")
         & L ("---"),
         Tags);
      Assert (Count (Tags, Ref) = 0, "no refs");
      Assert
        (Refusal_Of (L ("---") & L ("name: A") & L ("refs: {a: b}")
                     & L ("---")) =
           Maybe_Refusal'(Refused => True, Why => Flow_Collection),
         "a non-empty map");
   end An_Empty_Flow_Map_Is_Fine_A_Non_Empty_One_Refuses;

   procedure A_Flow_List_Spanning_Lines_Closes_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""part""") & L ("name: ""Widget One""")
         & L ("open_questions: [")
         & L ("  ""Where did the spare come from?"",")
         & L ("  ""Is it the same batch as [[gadget-two|Gadget]]?""")
         & L ("]") & L ("status: ""Stocked""") & L ("---"),
         Tags);
      --  The field after the list still parses: the continuation loop
      --  stopped exactly at the closing bracket.
      Assert (Count (Tags, Def) = 1, "one def");
      Assert (Has_Ref (Tags, "gadget-two", "open_questions"), "the link");
   end A_Flow_List_Spanning_Lines_Closes_Correctly;

   procedure Full_Line_Comments_Are_Skipped_Not_Refused
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""part""") & L ("# --- Identity ---")
         & L ("name: ""Widget Three""")
         & L ("name_meaning: ""Named for its shape""") & LF
         & L ("# --- Appearance ---") & L ("appearance:")
         & L ("  size: ""Short""") & L ("  colour: ""Red""") & L ("---"),
         Tags);
      Assert (Count (Tags, Def) = 1, "one def");
      Assert
        (To_String (Tags (Tags.First_Index).Name) = "Widget Three", "name");
   end Full_Line_Comments_Are_Skipped_Not_Refused;

   procedure A_Scene_Break_In_The_Prose_Is_Not_A_Second_Document
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tags : Tag_Vectors.Vector;
   begin
      Scan_Ok
        (L ("---") & L ("template: ""part""") & L ("name: ""Widget One""")
         & L ("---") & LF & L ("First scene.") & LF & L ("---") & LF
         & L ("Second scene, after the break.") & LF & L ("---"),
         Tags);
      Assert (Count (Tags, Def) = 1, "one def");
      Assert
        (To_String (Tags (Tags.First_Index).Name) = "Widget One", "name");
   end A_Scene_Break_In_The_Prose_Is_Not_A_Second_Document;

   procedure A_Batch_Reports_Each_Paths_Own_Refusal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir   : constant String := Synapse.Adapters.File_Bytes.Temp_Dir;
      Names : constant array (1 .. 3) of Unbounded_String :=
        [To_Unbounded_String ("bard-a.md"), To_Unbounded_String ("bard-b.md"),
         To_Unbounded_String ("bard-c.md")];
      E     : Extractor;
      Paths : Synapse.Core.Text_Lists.Vector;
   begin
      Synapse.Adapters.File_Bytes.Write
        (Dir & "/" & To_String (Names (1)),
         L ("---") & L ("name: A") & L ("summary: |") & L ("  block scalar")
         & L ("---"));
      Synapse.Adapters.File_Bytes.Write
        (Dir & "/" & To_String (Names (2)),
         L ("---") & L ("name: B") & L ("refs: {a: b}") & L ("---"));
      Synapse.Adapters.File_Bytes.Write
        (Dir & "/" & To_String (Names (3)), L ("no frontmatter at all"));
      for N of Names loop
         Paths.Append (N);
      end loop;
      Paths.Append (To_Unbounded_String ("missing.md"));
      Paths.Append (To_Unbounded_String ("notes.txt"));

      declare
         Outcomes : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
           E.Extract (Dir, Paths);
      begin
         Assert (Natural (Outcomes.Length) = 5, "one outcome per path");
         for Outcome of Outcomes loop
            Assert
              (Outcome.Kind = Synapse.Ports.Extractor.Unsupported,
               "none of the five parses");
         end loop;
      end;
      Assert (E.Last_Refusal (1) = (Refused => True, Why => Block_Scalar),
              "first");
      Assert (E.Last_Refusal (2) = (Refused => True, Why => Flow_Collection),
              "second");
      Assert (E.Last_Refusal (3) = (Refused => True, Why => No_Frontmatter),
              "third");
      Assert
        (not E.Last_Refusal (4).Refused, "a missing file is not refused");
      Assert (E.Last_Refusal (5) = (Refused => True, Why => Not_A_Note),
              "not a note");

      for N of Names loop
         Ada.Directories.Delete_File (Dir & "/" & To_String (N));
      end loop;
   end A_Batch_Reports_Each_Paths_Own_Refusal;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Frontmatter_Extractor");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, A_Def_Is_The_Identity_And_Kind_Is_The_Template'Access,
         "a def is the entity's identity, kind is the root template");
      Register_Routine
        (T, Objects_Three_Levels_Deep_Keep_Their_Dotted_Paths'Access,
         "list of objects three levels deep: each field keeps its own path");
      Register_Routine
        (T, A_Flow_List_Of_Plain_Strings_Is_Not_A_Refusal'Access,
         "a flow list of plain strings causes no refusal and no refs");
      Register_Routine
        (T, Several_Wikilinks_In_One_Scalar_Are_Separate_Refs'Access,
         "several wikilinks in one scalar each become their own ref");
      Register_Routine
        (T, A_Flow_List_Mixing_Prose_And_Links_Resolves_Each_Element'Access,
         "a flow list mixing prose and wikilinks resolves each element");
      Register_Routine
        (T, A_Bare_Scalar_Block_List_Uses_The_Parent_Key'Access,
         "a bare scalar block list qualifies every entry by the parent key");
      Register_Routine
        (T, Without_A_Template_The_Kind_Is_Entity'Access,
         "no template falls back to the kind entity");
      Register_Routine
        (T, Everything_Outside_The_Subset_Is_Refused'Access,
         "everything outside the subset is refused, not skipped");
      Register_Routine
        (T, Empty_Lists_Are_Fine'Access,
         "an empty flow list and an empty list-of-scalars key are fine");
      Register_Routine
        (T, An_Empty_Flow_Map_Is_Fine_A_Non_Empty_One_Refuses'Access,
         "an empty flow map is fine; a non-empty one refuses");
      Register_Routine
        (T, A_Flow_List_Spanning_Lines_Closes_Correctly'Access,
         "a flow list spanning several lines closes correctly");
      Register_Routine
        (T, Full_Line_Comments_Are_Skipped_Not_Refused'Access,
         "full-line comments are skipped, not refused");
      Register_Routine
        (T, A_Scene_Break_In_The_Prose_Is_Not_A_Second_Document'Access,
         "a scene break in the prose body is not a second document");
      Register_Routine
        (T, A_Batch_Reports_Each_Paths_Own_Refusal'Access,
         "a batch reports each path's own refusal, not the last one");
   end Register_Tests;

end Synapse_Bard.Frontmatter_Extractor.Tests;
