with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.Fake_Console;
with Synapse.Adapters.Fake_Variables;
with Synapse.Adapters.File_Bytes;

with Synapse_Bard.Hooks.Dispatch;
with Synapse_Bard.Hooks.Output;
with Synapse_Bard.Hooks.Payload;
with Synapse_Bard.Hooks.Session_Start;
with Synapse_Bard.Hooks.Stop_Nudge;
with Synapse_Bard.Hooks.Usage;

package body Synapse_Bard.Hooks.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   package Fakes renames Synapse.Adapters;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   function Contains (Text, Part : String) return Boolean is
     (for some I in Text'First .. Text'Last - Part'Length + 1 =>
        Text (I .. I + Part'Length - 1) = Part);

   ---------------------------------------------------------------------------
   --  Running a hook
   ---------------------------------------------------------------------------

   type Result is record
      Code     : Exit_Code;
      Out_Text : Unbounded_String;
      Err_Text : Unbounded_String;
   end record;

   function Run
     (Start : String; Hook : String; Stdin : String;
      Vars  : Fakes.Fake_Variables.Fake_Variables) return Result
   is
      Console : aliased Fakes.Fake_Console.Fake;
      Table   : aliased Fakes.Fake_Variables.Fake_Variables;
      Env     : constant Environment :=
        (Console => Console'Access, Vars => Table'Access,
         Start   => To_Unbounded_String (Start));
      Args    : Arguments;
      Code    : Exit_Code;
   begin
      Table.Table := Vars.Table;
      Console.Set_Stdin (Stdin);
      if Hook /= "" then
         Args.Append (To_Unbounded_String (Hook));
      end if;
      Code := Dispatch.Run (Env, Args);
      return
        (Code     => Code,
         Out_Text => To_Unbounded_String (Console.Out_Text),
         Err_Text => To_Unbounded_String (Console.Err_Text));
   end Run;

   No_Vars : Fakes.Fake_Variables.Fake_Variables;

   procedure Put_File (Root, Rel, Content : String) is
      Path : constant String := Root & "/" & Rel;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put_File;

   --  A repository; with `_bard/graph` when Used.
   function Make_Repo (Label : String; Used : Boolean := True) return String is
      Dir : constant String := Scratch_Dirs.Make (Label);
   begin
      Ada.Directories.Create_Path (Dir & "/.git");
      if Used then
         Ada.Directories.Create_Path (Dir & "/_bard/graph");
      end if;
      return Dir;
   end Make_Repo;

   function Payload_For (Cwd : String) return String is
     ("{""cwd"": " & Output.Json_String (Cwd) & "}");

   ---------------------------------------------------------------------------
   --  Output
   ---------------------------------------------------------------------------

   procedure Json_Escapes_What_A_Path_Can_Contain
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Em_Dash : constant String :=
        [Character'Val (16#E2#), Character'Val (16#80#),
         Character'Val (16#94#)];
   begin
      Assert
        (Output.Json_String
           ("World " & Em_Dash & " ""x""" & LF & "C:\dir" & Character'Val (9)
            & "tab") =
           """World " & Em_Dash & " \""x\""\nC:\\dir\ttab""",
         "quotes, newline, backslash, tab, UTF-8 as it is");
   end Json_Escapes_What_A_Path_Can_Contain;

   procedure A_Control_Byte_Is_Escaped
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Output.Json_String ("a" & Character'Val (1) & "b") = """a\u0001b""",
         "not emitted raw");
      Assert
        (Output.Json_String ([Character'Val (16#1F#)]) = """\u001f""",
         "lowercase hex");
   end A_Control_Byte_Is_Escaped;

   procedure Payload_Reads_Only_Top_Level_Strings
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Synapse_Bard.Hooks.Payload;
   begin
      Assert
        (Str (Parse ("{""cwd"": ""/x"", ""n"": 3}"), "cwd").Found, "a string");
      Assert
        (To_String (Str (Parse ("{""cwd"": ""/x""}"), "cwd").Value) = "/x",
         "its value");
      Assert (not Str (Parse (""), "cwd").Found, "empty input");
      Assert (not Str (Parse ("not json"), "cwd").Found, "malformed input");
      Assert (not Str (Parse ("[1, 2]"), "cwd").Found, "an array");
      Assert (not Str (Parse ("{""cwd"": 3}"), "cwd").Found, "a number");
      Assert (not Str (Parse ("{""cwd"": """"}"), "cwd").Found, "empty string");
      Assert (not Str (Parse ("{""a"": {""cwd"": ""/x""}}"), "cwd").Found,
              "only the top level");
   end Payload_Reads_Only_Top_Level_Strings;

   procedure Dispatch_Usage_Help_And_Unknown
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("hook-dispatch");
      R   : Result := Run (Dir, "", "", No_Vars);
   begin
      Assert (R.Code = 2 and then To_String (R.Err_Text) = Usage.Main_Usage,
              "no hook is a usage error");
      R := Run (Dir, "--help", "", No_Vars);
      Assert (R.Code = 0 and then To_String (R.Err_Text) = Usage.Main_Usage,
              "--help");
      R := Run (Dir, "-h", "", No_Vars);
      Assert (R.Code = 0, "-h");
      R := Run (Dir, "bogus", "", No_Vars);
      Assert
        (R.Code = 2
         and then To_String (R.Err_Text) =
           L ("synapse-bard-hook: unknown hook 'bogus'") & Usage.Main_Usage,
         "an unknown hook");
      Assert (To_String (R.Out_Text) = "", "nothing on standard output");
      Scratch_Dirs.Remove (Dir);
   end Dispatch_Usage_Help_And_Unknown;

   ---------------------------------------------------------------------------
   --  Paths (the template and standing-instructions paths)
   ---------------------------------------------------------------------------

   --  A variable table holding one variable.
   procedure Only
     (V : in out Fakes.Fake_Variables.Fake_Variables; Name, Value : String) is
   begin
      V.Set (Name, Value);
   end Only;

   procedure Template_Path_Is_Nothing_Without_A_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (not Session_Start.Template_Path (No_Vars).Found,
         "neither variable set");
   end Template_Path_Is_Nothing_Without_A_Root;

   procedure Template_Path_Joins_The_Plugin_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      V   : Fakes.Fake_Variables.Fake_Variables;
   begin
      Only (V, "CLAUDE_PLUGIN_ROOT", "/plugins/synapse-bard");
      declare
         Got : constant Session_Start.Maybe_Text :=
           Session_Start.Template_Path (V);
      begin
      Assert
        (Got.Found
         and then To_String (Got.Value) =
           "/plugins/synapse-bard/Index.md.template",
         "CLAUDE_PLUGIN_ROOT");
      end;
   end Template_Path_Joins_The_Plugin_Root;

   procedure Template_Path_Joins_The_Content_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      V   : Fakes.Fake_Variables.Fake_Variables;
   begin
      Only (V, "SYNAPSE_BARD_CONTENT_ROOT", "/npm/synapse-bard");
      declare
         Got : constant Session_Start.Maybe_Text :=
           Session_Start.Template_Path (V);
      begin
      Assert
        (Got.Found
         and then To_String (Got.Value) =
           "/npm/synapse-bard/Index.md.template",
         "SYNAPSE_BARD_CONTENT_ROOT when the plugin root is unset");
      end;
   end Template_Path_Joins_The_Content_Root;

   procedure Claude_Md_Path_Is_Nothing_Without_A_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (not Session_Start.Claude_Md_Path (No_Vars).Found,
         "neither variable set");
   end Claude_Md_Path_Is_Nothing_Without_A_Root;

   procedure Claude_Md_Path_Joins_The_Plugin_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      V   : Fakes.Fake_Variables.Fake_Variables;
   begin
      Only (V, "CLAUDE_PLUGIN_ROOT", "/plugins/synapse-bard");
      declare
         Got : constant Session_Start.Maybe_Text :=
           Session_Start.Claude_Md_Path (V);
      begin
      Assert
        (Got.Found
         and then To_String (Got.Value) =
           "/plugins/synapse-bard/synapse-bard-claude.md",
         "CLAUDE_PLUGIN_ROOT");
      end;
   end Claude_Md_Path_Joins_The_Plugin_Root;

   procedure Claude_Md_Path_Joins_The_Content_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      V   : Fakes.Fake_Variables.Fake_Variables;
   begin
      Only (V, "SYNAPSE_BARD_CONTENT_ROOT", "/npm/synapse-bard");
      declare
         Got : constant Session_Start.Maybe_Text :=
           Session_Start.Claude_Md_Path (V);
      begin
      Assert
        (Got.Found
         and then To_String (Got.Value) =
           "/npm/synapse-bard/synapse-bard-claude.md",
         "SYNAPSE_BARD_CONTENT_ROOT when the plugin root is unset");
      end;
   end Claude_Md_Path_Joins_The_Content_Root;

   procedure Bard_Enabled_Needs_The_Directory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("hook-enabled");
   begin
      Assert (not Session_Start.Bard_Enabled (Dir), "no _bard");
      Ada.Directories.Create_Path (Dir & "/_bard/graph");
      Assert (Session_Start.Bard_Enabled (Dir), "once _bard/graph exists");
      Scratch_Dirs.Remove (Dir);
      Put_File (Dir, "_bard", "a file is not a directory");
      Assert (not Session_Start.Bard_Enabled (Dir), "a file named _bard");
      Scratch_Dirs.Remove (Dir);
   end Bard_Enabled_Needs_The_Directory;

   ---------------------------------------------------------------------------
   --  session-start
   ---------------------------------------------------------------------------

   procedure Session_Start_Is_Silent_Without_Bard
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Plain : constant String := Make_Repo ("hook-ss-plain", Used => False);
      None  : constant String := Scratch_Dirs.Make ("hook-ss-none");
      R     : Result;
   begin
      R := Run (Plain, "session-start", Payload_For (Plain), No_Vars);
      Assert
        (R.Code = 0 and then To_String (R.Out_Text) = ""
         and then To_String (R.Err_Text) = "",
         "a repository that never used bard");
      R := Run (None, "session-start", Payload_For (None), No_Vars);
      Assert (R.Code = 0 and then To_String (R.Out_Text) = "",
              "outside a repository");
      R := Run (Plain, "session-start", "", No_Vars);
      Assert (R.Code = 0 and then To_String (R.Out_Text) = "",
              "no payload, working directory a plain repository");
      Scratch_Dirs.Remove (Plain);
      Scratch_Dirs.Remove (None);
   end Session_Start_Is_Silent_Without_Bard;

   procedure Session_Start_Injects_Instructions_And_Index
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir  : constant String := Make_Repo ("hook-ss-index");
      Root : constant String := Scratch_Dirs.Make ("hook-ss-plugin");
      Vars : Fakes.Fake_Variables.Fake_Variables;
   begin
      Only (Vars, "CLAUDE_PLUGIN_ROOT", Root);
      Put_File (Dir, "_bard/vault/Index.md", L ("# Index") & L ("- notes"));
      Put_File (Root, "synapse-bard-claude.md", L ("Standing instructions."));
      declare
         R : constant Result :=
           Run (Dir, "session-start", Payload_For (Dir), Vars);
         Expected : constant String :=
           "{""hookSpecificOutput"":{""hookEventName"":""SessionStart"","
           & """additionalContext"":"
           & Output.Json_String
               (L ("Standing instructions.") & LF & LF
                & "Writer's notes vault index (" & Dir
                & "/_bard/vault/Index.md) -- read before creating or linking "
                & "any note; prefer linking to an existing note over "
                & "duplicating content, and fall back to linking this index "
                & "if nothing more specific applies:" & LF & LF
                & L ("# Index") & L ("- notes"))
           & "}}" & LF;
      begin
         Assert (R.Code = 0, "exit code");
         Assert (To_String (R.Out_Text) = Expected, "the injected context");
      end;
      Scratch_Dirs.Remove (Dir);
      Scratch_Dirs.Remove (Root);
   end Session_Start_Injects_Instructions_And_Index;

   procedure Session_Start_Offers_To_Seed_The_Index
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Repo ("hook-ss-offer");
   begin
      declare
         R : constant Result :=
           Run (Dir, "session-start", Payload_For (Dir), No_Vars);
      begin
         Assert
           (Contains
              (To_String (R.Out_Text),
               Output.Json_String
                 ("No Writer's notes vault index found at " & Dir
                  & "/_bard/vault/Index.md -- offer to seed it from the "
                  & "shipped default (this plugin's own Index.md.template) "
                  & "before creating or linking any note.")),
            "the offer, without a plugin root");
      end;
      declare
         V : Fakes.Fake_Variables.Fake_Variables;
         R : Result;
      begin
         Only (V, "SYNAPSE_BARD_CONTENT_ROOT", "/npm/bard");
         R := Run (Dir, "session-start", Payload_For (Dir), V);
         Assert
           (Contains (To_String (R.Out_Text), "(/npm/bard/Index.md.template)"),
            "the offer names the template under the content root");
         Assert (not Ada.Directories.Exists (Dir & "/_bard/vault"),
                 "the hook never seeds");
      end;
      Scratch_Dirs.Remove (Dir);
   end Session_Start_Offers_To_Seed_The_Index;

   procedure Session_Start_Works_From_A_Subdirectory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Repo ("hook-ss-sub");
   begin
      Put_File (Dir, "_bard/vault/Index.md", L ("# Index"));
      Ada.Directories.Create_Path (Dir & "/parts/deep");
      declare
         R : constant Result :=
           Run (Dir, "session-start", Payload_For (Dir & "/parts/deep"),
                No_Vars);
      begin
         Assert (Contains (To_String (R.Out_Text), "# Index"),
                 "the index at the repository top is found");
      end;
      declare
         R : constant Result :=
           Run (Dir & "/parts", "session-start", "{}", No_Vars);
      begin
         Assert (Contains (To_String (R.Out_Text), "# Index"),
                 "no cwd in the payload: the working directory is used");
      end;
      Scratch_Dirs.Remove (Dir);
   end Session_Start_Works_From_A_Subdirectory;

   procedure An_Unreadable_Instructions_File_Is_Left_Out
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Repo ("hook-ss-nofile");
   begin
      Put_File (Dir, "_bard/vault/Index.md", L ("# Index"));
      --  A root that is set to nothing still counts as set, and holds no file.
      declare
         V : Fakes.Fake_Variables.Fake_Variables;
         R : Result;
      begin
         Only (V, "CLAUDE_PLUGIN_ROOT", "/nonexistent");
         R := Run (Dir, "session-start", Payload_For (Dir), V);
         Assert
           (Contains (To_String (R.Out_Text), "Writer's notes vault index ("),
            "only the index is injected");
         Assert (not Contains (To_String (R.Out_Text), "Standing"),
                 "no instructions");
      end;
      Scratch_Dirs.Remove (Dir);
   end An_Unreadable_Instructions_File_Is_Left_Out;

   ---------------------------------------------------------------------------
   --  stop-nudge
   ---------------------------------------------------------------------------

   function Advance_Once (Home, Session : String) return Stop_Nudge.Tick is
      Console : aliased Fakes.Fake_Console.Fake;
      Table   : aliased Fakes.Fake_Variables.Fake_Variables;
      Env     : constant Environment :=
        (Console => Console'Access, Vars => Table'Access,
         Start   => Null_Unbounded_String);
   begin
      return Stop_Nudge.Advance (Env, Home, Session);
   end Advance_Once;

   procedure No_Nudge_Before_The_Check_In_Turn
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Home : constant String := Scratch_Dirs.Make ("hook-sn-before");
   begin
      for I in 1 .. Stop_Nudge.Interval - 1 loop
         Assert (not Advance_Once (Home, "s1").Text.Found, "turn" & I'Image);
      end loop;
      Scratch_Dirs.Remove (Home);
   end No_Nudge_Before_The_Check_In_Turn;

   procedure Nudge_Fires_On_The_Nth_Turn
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Home : constant String := Scratch_Dirs.Make ("hook-sn-fires");
      Last : Stop_Nudge.Tick;
   begin
      for I in 1 .. Stop_Nudge.Interval loop
         Last := Advance_Once (Home, "s1");
      end loop;
      Assert (Last.Text.Found, "the nudge");
      Assert
        (Contains (To_String (Last.Text.Value), "_bard/vault/"),
         "names the vault");
      Assert
        (Contains (To_String (Last.Text.Value), "25 turns"), "names the turns");
      Assert (Last.Total = 25, "the total");
      Scratch_Dirs.Remove (Home);
   end Nudge_Fires_On_The_Nth_Turn;

   procedure Nudge_Rearms_After_Another_Cycle
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Home  : constant String := Scratch_Dirs.Make ("hook-sn-rearm");
      Fires : Natural := 0;
   begin
      for I in 1 .. 2 * Stop_Nudge.Interval loop
         if Advance_Once (Home, "s1").Text.Found then
            Fires := Fires + 1;
         end if;
      end loop;
      Assert (Fires = 2, "two cycles, two nudges");
      Scratch_Dirs.Remove (Home);
   end Nudge_Rearms_After_Another_Cycle;

   procedure Sessions_Count_Independently
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Home : constant String := Scratch_Dirs.Make ("hook-sn-sessions");
   begin
      for I in 1 .. Stop_Nudge.Interval loop
         declare
            Ignored : constant Stop_Nudge.Tick := Advance_Once (Home, "s1");
         begin
            Assert (Ignored.Total = I, "s1 counts");
         end;
      end loop;
      declare
         Other : constant Stop_Nudge.Tick := Advance_Once (Home, "s2");
      begin
         Assert (not Other.Text.Found, "a fresh session has no turns yet");
         Assert (Other.Total = 1, "and counts from one");
      end;
      Scratch_Dirs.Remove (Home);
   end Sessions_Count_Independently;

   procedure A_Corrupt_Counter_Restarts_From_Zero
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Home : constant String := Scratch_Dirs.Make ("hook-sn-corrupt");
   begin
      Put_File
        (Home, ".claude/state/synapse-bard-stop-nudge-total-s1", "garbage");
      Assert (Advance_Once (Home, "s1").Total = 1, "restarted from zero");
      Assert
        (Synapse.Adapters.File_Bytes.Read
           (Home & "/.claude/state/synapse-bard-stop-nudge-total-s1", 64) =
           L ("1"),
         "and rewritten");
      Scratch_Dirs.Remove (Home);
   end A_Corrupt_Counter_Restarts_From_Zero;

   procedure The_Nudge_Cites_A_Heading_That_Exists
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Relative : constant String := "packages/synapse-bard/synapse-bard-claude.md";
      Dir      : Unbounded_String :=
        To_Unbounded_String (Ada.Directories.Current_Directory);
   begin
      --  Renaming the heading without the constant, or the reverse, leaves a
      --  pointer to a section that is not there.
      loop
         exit when Ada.Directories.Exists (To_String (Dir) & "/" & Relative);
         declare
            Parent : constant String :=
              Ada.Directories.Containing_Directory (To_String (Dir));
         begin
            Assert (Parent /= To_String (Dir), "the shipped file is found");
            Dir := To_Unbounded_String (Parent);
         end;
      end loop;
      Assert
        (Contains
           (LF & Synapse.Adapters.File_Bytes.Read
                   (To_String (Dir) & "/" & Relative, 2**20),
            LF & "# " & Stop_Nudge.Vault_Note_Heading & LF),
         "a heading line of synapse-bard-claude.md");
   end The_Nudge_Cites_A_Heading_That_Exists;

   procedure Stop_Nudge_Runs_Only_Where_Bard_Is_Used
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Plain : constant String := Make_Repo ("hook-sn-plain", Used => False);
      Used  : constant String := Make_Repo ("hook-sn-used");
      Home  : constant String := Scratch_Dirs.Make ("hook-sn-home");
      Vars  : Fakes.Fake_Variables.Fake_Variables;
      R     : Result;
   begin
      Only (Vars, "HOME", Home);
      R := Run (Plain, "stop-nudge", Payload_For (Plain), Vars);
      Assert (R.Code = 0 and then To_String (R.Out_Text) = "",
              "silent without _bard");
      Assert (not Ada.Directories.Exists (Home & "/.claude"),
              "and it counts nothing");
      R := Run (Used, "stop-nudge", Payload_For (Used), No_Vars);
      Assert (R.Code = 0 and then To_String (R.Out_Text) = "",
              "silent without HOME");
      for I in 1 .. Stop_Nudge.Interval - 1 loop
         R := Run (Used, "stop-nudge",
                   "{""cwd"": " & Output.Json_String (Used)
                   & ", ""session_id"": ""abc""}", Vars);
         Assert (To_String (R.Out_Text) = "", "no nudge yet");
      end loop;
      R := Run (Used, "stop-nudge",
                "{""cwd"": " & Output.Json_String (Used)
                & ", ""session_id"": ""abc""}", Vars);
      Assert
        (Contains
           (To_String (R.Out_Text), """hookEventName"":""Stop"""),
         "the 25th turn emits the nudge for the Stop event");
      Assert
        (Ada.Directories.Exists
           (Home & "/.claude/state/synapse-bard-stop-nudge-total-abc"),
         "the counter is named after the session");
      Scratch_Dirs.Remove (Plain);
      Scratch_Dirs.Remove (Used);
      Scratch_Dirs.Remove (Home);
   end Stop_Nudge_Runs_Only_Where_Bard_Is_Used;

   ---------------------------------------------------------------------------
   --  Registration
   ---------------------------------------------------------------------------

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Hooks");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Json_Escapes_What_A_Path_Can_Contain'Access,
         "a context payload escapes what a path can contain");
      Register_Routine
        (T, A_Control_Byte_Is_Escaped'Access,
         "a control byte is escaped rather than emitted raw");
      Register_Routine
        (T, Payload_Reads_Only_Top_Level_Strings'Access,
         "the payload reads top-level strings and nothing else");
      Register_Routine
        (T, Dispatch_Usage_Help_And_Unknown'Access,
         "usage, help and an unknown hook");
      Register_Routine
        (T, Template_Path_Is_Nothing_Without_A_Root'Access,
         "Template_Path is nothing with neither root variable");
      Register_Routine
        (T, Template_Path_Joins_The_Plugin_Root'Access,
         "Template_Path joins CLAUDE_PLUGIN_ROOT");
      Register_Routine
        (T, Template_Path_Joins_The_Content_Root'Access,
         "Template_Path joins SYNAPSE_BARD_CONTENT_ROOT");
      Register_Routine
        (T, Claude_Md_Path_Is_Nothing_Without_A_Root'Access,
         "Claude_Md_Path is nothing with neither root variable");
      Register_Routine
        (T, Claude_Md_Path_Joins_The_Plugin_Root'Access,
         "Claude_Md_Path joins CLAUDE_PLUGIN_ROOT");
      Register_Routine
        (T, Claude_Md_Path_Joins_The_Content_Root'Access,
         "Claude_Md_Path joins SYNAPSE_BARD_CONTENT_ROOT");
      Register_Routine
        (T, Bard_Enabled_Needs_The_Directory'Access,
         "Bard_Enabled needs a _bard directory");
      Register_Routine
        (T, Session_Start_Is_Silent_Without_Bard'Access,
         "session-start is silent without _bard and outside a repository");
      Register_Routine
        (T, Session_Start_Injects_Instructions_And_Index'Access,
         "session-start injects the instructions and the vault index");
      Register_Routine
        (T, Session_Start_Offers_To_Seed_The_Index'Access,
         "session-start offers to seed a missing index and never seeds");
      Register_Routine
        (T, Session_Start_Works_From_A_Subdirectory'Access,
         "session-start finds the repository from a subdirectory");
      Register_Routine
        (T, An_Unreadable_Instructions_File_Is_Left_Out'Access,
         "an unreadable instructions file is left out");
      Register_Routine
        (T, No_Nudge_Before_The_Check_In_Turn'Access,
         "no nudge before the check-in turn");
      Register_Routine
        (T, Nudge_Fires_On_The_Nth_Turn'Access,
         "the nudge fires on the Nth turn, naming the check-in mark");
      Register_Routine
        (T, Nudge_Rearms_After_Another_Cycle'Access,
         "the nudge re-arms after another cycle");
      Register_Routine
        (T, Sessions_Count_Independently'Access,
         "separate sessions count turns independently");
      Register_Routine
        (T, A_Corrupt_Counter_Restarts_From_Zero'Access,
         "a corrupt counter restarts from zero");
      Register_Routine
        (T, The_Nudge_Cites_A_Heading_That_Exists'Access,
         "the nudge cites a synapse-bard-claude.md heading that exists");
      Register_Routine
        (T, Stop_Nudge_Runs_Only_Where_Bard_Is_Used'Access,
         "stop-nudge is gated like session-start and counts per session");
   end Register_Tests;

end Synapse_Bard.Hooks.Tests;
