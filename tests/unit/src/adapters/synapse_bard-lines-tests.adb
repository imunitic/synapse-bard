with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Synapse.Core.Text_Lists;

package body Synapse_Bard.Lines.Tests is

   use AUnit.Assertions;

   LF : constant String := [Character'Val (10)];
   CR : constant String := [Character'Val (13)];

   function Joined (Text : String) return String is
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Line of Split (Text) loop
         Ada.Strings.Unbounded.Append (Result, "[");
         Ada.Strings.Unbounded.Append (Result, Line);
         Ada.Strings.Unbounded.Append (Result, "]");
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Joined;

   procedure Split_Cuts_At_Line_Feeds
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Joined ("a" & LF & "b") = "[a][b]", "two lines");
      Assert (Joined ("a" & LF & "b" & LF) = "[a][b]",
              "a final line feed starts no line");
      Assert (Joined ("a" & CR & LF & "b") = "[a][b]", "CRLF");
      Assert (Joined ("a" & LF & LF & "b") = "[a][][b]", "a blank line");
      Assert (Joined (LF) = "[]", "a single line feed is one empty line");
      Assert (Joined ("") = "", "no text, no lines");
      Assert (Natural (Split ("x").Length) = 1, "no line feed at all");
   end Split_Cuts_At_Line_Feeds;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Lines");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Split_Cuts_At_Line_Feeds'Access,
         "Split cuts a text into lines at line feeds");
   end Register_Tests;

end Synapse_Bard.Lines.Tests;
