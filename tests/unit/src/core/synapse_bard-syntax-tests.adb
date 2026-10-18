with AUnit.Assertions;

package body Synapse_Bard.Syntax.Tests is

   use AUnit.Assertions;

   procedure Trim_Drops_Spaces_At_Both_Ends
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Trim ("  a b  ") = "a b", "both ends");
      Assert (Trim ("   ") = "", "only spaces");
      Assert (Trim ("") = "", "empty");
      Assert (Trim ("a") = "a", "nothing to drop");
      Assert (Trim ([TAB, 'a']) = [TAB, 'a'], "a tab is not a space");
   end Trim_Drops_Spaces_At_Both_Ends;

   procedure Stays_Inside_Refuses_Escapes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Stays_Inside ("book"), "a name");
      Assert (Stays_Inside ("book/one.md"), "a path");
      Assert (Stays_Inside ("a..b/c"), "dots inside a name");
      Assert (Stays_Inside (".hidden"), "a hidden name");
      Assert (not Stays_Inside (""), "empty");
      Assert (not Stays_Inside ("/etc/passwd"), "absolute");
      Assert (not Stays_Inside (".."), "parent");
      Assert (not Stays_Inside ("../x"), "parent first");
      Assert (not Stays_Inside ("a/../x"), "parent in the middle");
      Assert (not Stays_Inside ("a/.."), "parent last");
      Assert (not Stays_Inside ("."), "current");
      Assert (not Stays_Inside ("a/./b"), "current in the middle");
   end Stays_Inside_Refuses_Escapes;

   procedure Headings_Have_Exactly_Their_Marks_And_A_Space
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Is_Heading ("# Title", 1), "H1");
      Assert (Is_Heading ("## Chapter", 2), "H2");
      Assert (not Is_Heading ("## Chapter", 1), "an H2 is not an H1");
      Assert (not Is_Heading ("# Title", 2), "an H1 is not an H2");
      Assert (not Is_Heading ("#Title", 1), "needs a space");
      Assert (not Is_Heading ("#", 1), "no text and no space");
      Assert (not Is_Heading ("", 1), "empty");
      Assert (Heading_Text ("#  The Title  ", 1) = "The Title", "trimmed");
      Assert (Heading_Text ("## Dawn", 2) = "Dawn", "H2 text");
      Assert (Heading_Text ("# ", 1) = "", "no title");
      Assert (Heading_Text ("plain", 1) = "", "not a heading");
   end Headings_Have_Exactly_Their_Marks_And_A_Space;

   procedure Item_Start_Finds_The_Text_Of_An_Ordered_Item
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Item_Start ("1. book") = 4, "dot");
      Assert (Item_Start ("12) book") = 5, "parenthesis, two digits");
      Assert (Item_Start ("1.book") = 0, "needs a space");
      Assert (Item_Start (". book") = 0, "needs a number");
      Assert (Item_Start ("- book") = 0, "a bullet");
      Assert (Item_Start ("1.") = 0, "nothing after the marker");
      Assert (Item_Start ("") = 0, "empty");
      Assert (Item_Start ("12") = 0, "digits only");
   end Item_Start_Finds_The_Text_Of_An_Ordered_Item;

   procedure Unslugify_Makes_A_Title_From_A_Name
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Unslugify ("some_title_of_the_chapter.md")
         = "Some title of the chapter", "underscores and extension");
      Assert (Unslugify ("the_star-forge") = "The star forge", "folder name");
      Assert
        (Unslugify ("01_the_beginning.md") = "01 the beginning",
         "a numeric prefix stays");
      Assert
        (Unslugify ("Keep_McGregor") = "Keep McGregor",
         "no other character changes");
      Assert (Unslugify ("notes.txt") = "notes.txt", "only .md is dropped");
      Assert
        (Unslugify ("The Star Forge") = "The Star Forge",
         "a name with spaces is already a title");
      Assert
        (Unslugify ("The Star Forge.md") = "The Star Forge",
         "the extension still goes");
      Assert
        (Unslugify ("the star_forge") = "the star_forge",
         "a space means it is not a slug");
      Assert (Unslugify ("Prologue.md") = "Prologue", "no separator");
      Assert (Unslugify ("") = "", "empty stays empty");
      Assert (Unslugify (".md") = "", "only the extension");
   end Unslugify_Makes_A_Title_From_A_Name;

   procedure Words_Are_Letters_Digits_And_Underscore
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Is_Word (Character'Pos ('a')), "letter");
      Assert (Is_Word (Character'Pos ('7')), "digit");
      Assert (Is_Word (Character'Pos ('_')), "underscore");
      Assert (not Is_Word (Character'Pos (' ')), "space");
      Assert (not Is_Word (Character'Pos ('-')), "hyphen");
      Assert (Is_Word (16#E9#), "a letter with an accent");
      Assert (not Is_Word (16#201C#), "a curly quote");
      Assert (not Is_Word (16#2014#), "an em dash");
      Assert (Is_Word (16#4E2D#), "a CJK letter");
      Assert (not Is_Word (16#3002#), "a CJK full stop");
   end Words_Are_Letters_Digits_And_Underscore;

   procedure Holds_Word_Needs_Word_Boundaries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Holds_Word ("Alice walked", "Alice"), "at the start");
      Assert (Holds_Word ("said Alice", "Alice"), "at the end");
      Assert (Holds_Word ("Alice", "Alice"), "the whole line");
      Assert (Holds_Word ("Alice's cat", "Alice"), "before an apostrophe");
      Assert (Holds_Word ("""Alice,"" he said", "Alice"), "in quotes");
      Assert (not Holds_Word ("Alicia", "Alice"), "a longer word");
      Assert (not Holds_Word ("Malice", "Alice"), "inside a word");
      Assert (not Holds_Word ("Alice_2", "Alice"), "underscore continues");
      Assert (not Holds_Word ("Alice", ""), "an empty term");
      Assert (not Holds_Word ("Al", "Alice"), "a term longer than the line");
      Assert (not Holds_Word ("", "Alice"), "an empty line");
      Assert
        (Holds_Word ("The Captain spoke", "the Captain") = False,
         "case matters");
      Assert (Holds_Word ("a Cap-tain b", "Cap-tain"), "punctuation inside");
      Assert
        (Holds_Word ([Character'Val (16#E2#), Character'Val (16#80#),
                      Character'Val (16#9C#)] & "Alice",
                     "Alice"),
         "after a curly quote");
   end Holds_Word_Needs_Word_Boundaries;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Syntax");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Trim_Drops_Spaces_At_Both_Ends'Access,
         "Trim drops the spaces at both ends");
      Register_Routine
        (T, Stays_Inside_Refuses_Escapes'Access,
         "Stays_Inside refuses empty, absolute, . and .. paths");
      Register_Routine
        (T, Headings_Have_Exactly_Their_Marks_And_A_Space'Access,
         "a heading has exactly its marks and a space");
      Register_Routine
        (T, Item_Start_Finds_The_Text_Of_An_Ordered_Item'Access,
         "Item_Start finds the text of an ordered list item");
      Register_Routine
        (T, Unslugify_Makes_A_Title_From_A_Name'Access,
         "Unslugify turns a file or folder name into a title");
      Register_Routine
        (T, Words_Are_Letters_Digits_And_Underscore'Access,
         "Is_Word is true for letters, digits and underscore");
      Register_Routine
        (T, Holds_Word_Needs_Word_Boundaries'Access,
         "Holds_Word needs a boundary on both sides");
   end Register_Tests;

end Synapse_Bard.Syntax.Tests;
