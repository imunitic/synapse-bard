with Ada.Strings.Unbounded;

with AUnit.Assertions;

package body Synapse_Bard.Frontmatter_Fields.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function Text_Of (Item : Maybe_Text) return String is
     (if Item.Found then To_String (Item.Value) else "<none>");

   procedure Raw_Field_Is_A_Single_Line_Scalar_With_Its_Key
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "template: ""widget""" & LF & "name: ""gadget""" & LF
        & "---" & LF;
   begin
      Assert
        (Text_Of (Raw_Field (Source, "template")) =
           "template: ""widget""" & LF,
         "single-line scalar, key included");
   end Raw_Field_Is_A_Single_Line_Scalar_With_Its_Key;

   procedure Raw_Field_Is_A_Nested_Block_Of_Objects
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "name: ""gadget""" & LF & "images:" & LF
        & "  - path: ""widgets/gadget/face.png""" & LF
        & "    description: ""Front view""" & LF
        & "    source: ""Drawn by hand""" & LF
        & "  - path: ""widgets/gadget/side.png""" & LF
        & "    description: ""Side view""" & LF & "cast:" & LF
        & "  - name: ""Someone""" & LF & "---";
   begin
      Assert
        (Text_Of (Raw_Field (Source, "images")) =
           "images:" & LF & "  - path: ""widgets/gadget/face.png""" & LF
           & "    description: ""Front view""" & LF
           & "    source: ""Drawn by hand""" & LF
           & "  - path: ""widgets/gadget/side.png""" & LF
           & "    description: ""Side view""" & LF,
         "the whole block up to the next root key");
   end Raw_Field_Is_A_Nested_Block_Of_Objects;

   procedure Raw_Field_Spans_A_Blank_Line_Inside_The_Block
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "name: ""A""" & LF & "open_questions:" & LF
        & "  - ""First""" & LF & LF & "  - ""Second""" & LF
        & "status: ""Alive""" & LF & "---";
   begin
      Assert
        (Text_Of (Raw_Field (Source, "open_questions")) =
           "open_questions:" & LF & "  - ""First""" & LF & LF
           & "  - ""Second""" & LF,
         "stops at the next root key, not at the blank line");
   end Raw_Field_Spans_A_Blank_Line_Inside_The_Block;

   procedure Raw_Field_Is_None_For_A_Missing_Key_Or_No_Frontmatter
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (not Raw_Field ("---" & LF & "name: ""A""" & LF & "---" & LF,
                        "nonexistent").Found,
         "a key that is not there");
      Assert
        (not Raw_Field ("# Just prose" & LF, "name").Found,
         "a file with no frontmatter");
   end Raw_Field_Is_None_For_A_Missing_Key_Or_No_Frontmatter;

   procedure Raw_Field_Returns_A_Block_Scalar_Raw
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "name: ""A""" & LF & "summary: |" & LF
        & "  a paragraph" & LF & "  more" & LF & "template: ""x""" & LF
        & "---" & LF;
   begin
      Assert
        (Text_Of (Raw_Field (Source, "summary")) =
           "summary: |" & LF & "  a paragraph" & LF & "  more" & LF,
         "a block scalar comes back as written");
   end Raw_Field_Returns_A_Block_Scalar_Raw;

   procedure Block_Runs_From_The_Opening_To_The_Closing_Fence
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "name: ""A""" & LF & "template: ""x""" & LF & "---" & LF
        & LF & "Prose body, never included." & LF;
   begin
      Assert
        (Text_Of (Block (Source)) =
           "---" & LF & "name: ""A""" & LF & "template: ""x""" & LF & "---"
           & LF,
         "prose body dropped");
   end Block_Runs_From_The_Opening_To_The_Closing_Fence;

   procedure Block_Handles_No_Newline_After_The_Closing_Fence
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String := "---" & LF & "name: ""A""" & LF & "---";
   begin
      Assert (Text_Of (Block (Source)) = Source, "the whole text");
   end Block_Handles_No_Newline_After_The_Closing_Fence;

   procedure Block_Is_None_Without_Frontmatter_Or_When_Unterminated
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (not Block ("# Just prose" & LF).Found, "no frontmatter");
      Assert
        (not Block ("---" & LF & "name: ""A""" & LF).Found, "unterminated");
   end Block_Is_None_Without_Frontmatter_Or_When_Unterminated;

   procedure Root_Keys_Lists_Only_Column_Zero_Keys_In_Order
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "---" & LF & "# --- Identity ---" & LF & "name: """"" & LF
        & "role: """"                    # trailing comment" & LF
        & "age: null" & LF & "appearance:" & LF & "  height: """"" & LF
        & "  build: """"" & LF & "images:" & LF & "  - path: """"" & LF
        & "    description: """"" & LF & "---" & LF;
      Keys   : constant Synapse.Core.Text_Lists.Vector := Root_Keys (Source);
   begin
      Assert (Natural (Keys.Length) = 5, "five root keys");
      Assert (To_String (Keys (1)) = "name", "first");
      Assert (To_String (Keys (2)) = "role", "second");
      Assert (To_String (Keys (3)) = "age", "third");
      Assert (To_String (Keys (4)) = "appearance", "fourth");
      Assert (To_String (Keys (5)) = "images", "fifth");
   end Root_Keys_Lists_Only_Column_Zero_Keys_In_Order;

   procedure Root_Keys_Is_Empty_Without_Frontmatter
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Root_Keys ("# Just prose" & LF).Is_Empty, "no keys");
      Assert (not Has_Block ("# Just prose" & LF), "no block");
   end Root_Keys_Is_Empty_Without_Frontmatter;

   procedure Wikilink_Targets_Finds_Every_Target_Duplicates_Included
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Targets : constant Synapse.Core.Text_Lists.Vector :=
        Wikilink_Targets
          ("Mentions [[widget|Widget]] here, then again as [[widget]]." & LF
           & "A new line references [[gadget|Gadget]].");
   begin
      Assert (Natural (Targets.Length) = 3, "three links");
      Assert (To_String (Targets (1)) = "widget", "first");
      Assert (To_String (Targets (2)) = "widget", "duplicate kept");
      Assert (To_String (Targets (3)) = "gadget", "on the second line");
   end Wikilink_Targets_Finds_Every_Target_Duplicates_Included;

   procedure Wikilink_Targets_Is_Empty_Without_Links
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Wikilink_Targets ("Plain prose, no brackets here.").Is_Empty,
         "no links");
   end Wikilink_Targets_Is_Empty_Without_Links;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Frontmatter_Fields");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Raw_Field_Is_A_Single_Line_Scalar_With_Its_Key'Access,
         "Raw_Field returns a single-line scalar verbatim, key included");
      Register_Routine
        (T, Raw_Field_Is_A_Nested_Block_Of_Objects'Access,
         "Raw_Field returns a multi-line nested block, list of objects "
         & "included");
      Register_Routine
        (T, Raw_Field_Spans_A_Blank_Line_Inside_The_Block'Access,
         "Raw_Field stops at the next root key, not at a blank line");
      Register_Routine
        (T, Raw_Field_Is_None_For_A_Missing_Key_Or_No_Frontmatter'Access,
         "Raw_Field is none for a missing key and for no frontmatter");
      Register_Routine
        (T, Raw_Field_Returns_A_Block_Scalar_Raw'Access,
         "Raw_Field never refuses: a block scalar comes back raw");
      Register_Routine
        (T, Block_Runs_From_The_Opening_To_The_Closing_Fence'Access,
         "Block runs from the opening to the closing fence, body dropped");
      Register_Routine
        (T, Block_Handles_No_Newline_After_The_Closing_Fence'Access,
         "Block handles no newline after the closing fence");
      Register_Routine
        (T, Block_Is_None_Without_Frontmatter_Or_When_Unterminated'Access,
         "Block is none for no frontmatter or an unterminated block");
      Register_Routine
        (T, Root_Keys_Lists_Only_Column_Zero_Keys_In_Order'Access,
         "Root_Keys lists only column-zero keys, skipping sub-fields and "
         & "comments");
      Register_Routine
        (T, Root_Keys_Is_Empty_Without_Frontmatter'Access,
         "Root_Keys is empty for a file with no frontmatter");
      Register_Routine
        (T, Wikilink_Targets_Finds_Every_Target_Duplicates_Included'Access,
         "Wikilink_Targets finds every target, duplicates included");
      Register_Routine
        (T, Wikilink_Targets_Is_Empty_Without_Links'Access,
         "Wikilink_Targets is empty for text with no links");
   end Register_Tests;

end Synapse_Bard.Frontmatter_Fields.Tests;
