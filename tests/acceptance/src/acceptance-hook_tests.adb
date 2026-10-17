with Ada.Directories;

with AUnit.Assertions;

with Synapse.Core.JSON;

with Acceptance.Fixtures;

package body Acceptance.Hook_Tests is

   use AUnit.Assertions;
   use Acceptance.Fixtures;

   package JSON renames Synapse.Core.JSON;

   use type JSON.Kind;

   function L (Text : String) return String is (Text & LF);

   function Payload (Cwd : String; Session : String := "") return String is
     ("{""cwd"": """ & Cwd & """"
      & (if Session = "" then "" else ", ""session_id"": """ & Session & """")
      & "}");

   --  The `additionalContext` of the hook output for Event, or "" when the
   --  output is not the expected shape.
   function Context_Of (Output, Event : String) return String is
      Parsed : constant JSON.Parse_Result := JSON.Parse (Output);
   begin
      if not Parsed.Ok then
         return "<not JSON>";
      end if;
      declare
         Top : constant JSON.Value := Parsed.Item;
      begin
         if JSON.Kind_Of (Top) /= JSON.JSON_Object
           or else not JSON.Has_Member (Top, "hookSpecificOutput")
         then
            return "<no hookSpecificOutput>";
         end if;
         declare
            Inner : constant JSON.Value :=
              JSON.Member_Value (Top, "hookSpecificOutput");
         begin
            if JSON.Kind_Of (Inner) /= JSON.JSON_Object
              or else not JSON.Has_Member (Inner, "hookEventName")
              or else not JSON.Has_Member (Inner, "additionalContext")
              or else JSON.As_String (JSON.Member_Value (Inner, "hookEventName"))
                      /= Event
            then
               return "<wrong shape>";
            end if;
            return JSON.As_String (JSON.Member_Value (Inner, "additionalContext"));
         end;
      end;
   end Context_Of;

   function Make_Repo (Label : String; Used : Boolean) return String is
      Dir : constant String := Make_Directory (Label);
   begin
      Init_Git (Dir);
      if Used then
         Ada.Directories.Create_Path (Dir & "/_bard/graph");
      end if;
      return Dir;
   end Make_Repo;

   procedure Session_Start_Output (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Plain  : constant String := Make_Repo ("hook-plain", False);
      Used   : constant String := Make_Repo ("hook-used", True);
      Plugin : constant String := Make_Directory ("hook-plugin");
      Home   : constant String := Make_Directory ("hook-home");
   begin
      declare
         R : constant Result := Run_Hook (Plain, "session-start", Payload (Plain), Home);
      begin
         Assert (R.Exit_Code = 0, "plain repository: exit code");
         Assert (Out_Text (R) = "", "plain repository: silent");
      end;

      declare
         R : constant Result := Run_Hook (Used, "session-start", Payload (Used), Home);
      begin
         Assert (R.Exit_Code = 0, "no index: exit code");
         Assert
           (Contains
              (Context_Of (Out_Text (R), "SessionStart"),
               "No Writer's notes vault index found at " & Used
               & "/_bard/vault/Index.md -- offer to seed it from the shipped "
               & "default (this plugin's own Index.md.template)"),
            "the seed offer, was <" & Out_Text (R) & ">");
         Assert
           (not Ada.Directories.Exists (Used & "/_bard/vault"),
            "the hook seeds nothing");
      end;

      Put_File (Used, "_bard/vault/Index.md", L ("# Index") & L ("- notes"));
      Put_File (Plugin, "synapse-bard-claude.md", L ("Standing instructions."));
      declare
         R : constant Result :=
           Run_Hook (Used, "session-start", Payload (Used), Home, Plugin);
         Text : constant String := Context_Of (Out_Text (R), "SessionStart");
      begin
         Assert (R.Exit_Code = 0, "with an index: exit code");
         Assert (Contains (Text, "Standing instructions."), "the instructions");
         Assert
           (Contains (Text, "Writer's notes vault index (" & Used & "/_bard/vault/Index.md)"),
            "the index heading");
         Assert (Contains (Text, "# Index" & LF & "- notes"), "the index text");
         Assert
           (Out_Text (R) (Out_Text (R)'Last) = LF,
            "one line of JSON, ending in a line feed");
      end;

      declare
         Empty : constant Result := Run_Hook (Used, "session-start", "", Home, Plugin);
         Junk  : constant Result := Run_Hook (Used, "session-start", "not json", Home, Plugin);
      begin
         Assert (Empty.Exit_Code = 0 and then Junk.Exit_Code = 0, "exit codes");
         Assert
           (Contains (Context_Of (Out_Text (Empty), "SessionStart"), "# Index")
            and then Contains
              (Context_Of (Out_Text (Junk), "SessionStart"), "# Index"),
            "no usable payload: the working directory is used");
      end;
      Remove (Plain);
      Remove (Used);
      Remove (Plugin);
      Remove (Home);
   end Session_Start_Output;

   procedure Stop_Nudge_Output (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plain : constant String := Make_Repo ("nudge-plain", False);
      Used  : constant String := Make_Repo ("nudge-used", True);
      Home  : constant String := Make_Directory ("nudge-home");
   begin
      for Turn in 1 .. 24 loop
         declare
            R : constant Result :=
              Run_Hook (Used, "stop-nudge", Payload (Used, "one"), Home);
         begin
            Assert (R.Exit_Code = 0, "exit code on turn" & Turn'Image);
            Assert (Out_Text (R) = "", "silent on turn" & Turn'Image);
         end;
      end loop;
      declare
         R : constant Result :=
           Run_Hook (Used, "stop-nudge", Payload (Used, "one"), Home);
         Text : constant String := Context_Of (Out_Text (R), "Stop");
      begin
         Assert (R.Exit_Code = 0, "exit code on turn 25");
         Assert
           (Contains (Text, "This session has grown substantial (25 turns, "
                            & "re-armed at the 25-turn mark)."),
            "the 25th turn nudges, was <" & Out_Text (R) & ">");
         Assert (Contains (Text, "_bard/vault/"), "it names the vault");
      end;
      declare
         Other : constant Result :=
           Run_Hook (Used, "stop-nudge", Payload (Used, "two"), Home);
      begin
         Assert (Out_Text (Other) = "", "another session counts on its own");
      end;
      declare
         R : constant Result :=
           Run_Hook (Plain, "stop-nudge", Payload (Plain, "three"), Home);
      begin
         Assert (R.Exit_Code = 0 and then Out_Text (R) = "",
                 "silent without _bard");
         Assert
           (not Ada.Directories.Exists
                  (Home & "/.claude/state/synapse-bard-stop-nudge-total-three"),
            "and nothing counted");
      end;
      declare
         R : constant Result := Run_Hook (Used, "stop-nudge", Payload (Used), "");
      begin
         Assert (R.Exit_Code = 0 and then Out_Text (R) = "",
                 "silent without HOME");
      end;
      Remove (Plain);
      Remove (Used);
      Remove (Home);
   end Stop_Nudge_Output;

   procedure Hook_Usage (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Directory ("hook-usage");
   begin
      declare
         R : constant Result := Run_Hook (Dir, "", "");
      begin
         Assert (R.Exit_Code = 2, "no hook");
         Assert (Contains (Err_Text (R), "usage: synapse-bard-hook <hook>"), "usage");
      end;
      declare
         R : constant Result := Run_Hook (Dir, "--help", "");
      begin
         Assert (R.Exit_Code = 0, "--help");
      end;
      declare
         R : constant Result := Run_Hook (Dir, "bogus", "");
      begin
         Assert (R.Exit_Code = 2, "unknown hook");
         Assert
           (Contains (Err_Text (R), "synapse-bard-hook: unknown hook 'bogus'"),
            "its message");
      end;
      Remove (Dir);
   end Hook_Usage;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("synapse-bard-hook");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Session_Start_Output'Access,
         "session-start: silent, the seed offer, the injected context");
      Register_Routine
        (T, Stop_Nudge_Output'Access,
         "stop-nudge: silent for 24 turns, a nudge on the 25th");
      Register_Routine
        (T, Hook_Usage'Access, "usage, help and an unknown hook");
   end Register_Tests;

end Acceptance.Hook_Tests;
