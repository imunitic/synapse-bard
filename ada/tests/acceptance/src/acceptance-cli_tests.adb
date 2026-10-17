with AUnit.Assertions;

with Acceptance.Fixtures;

package body Acceptance.Cli_Tests is

   use AUnit.Assertions;
   use Acceptance.Fixtures;

   function L (Text : String) return String is (Text & LF);

   --  A made-up bible: a cluster of two parts that link to each other and one
   --  of items, in a fresh git repository.
   function Make_Bible (Label : String) return String is
      Dir : constant String := Make_Directory (Label);
   begin
      Init_Git (Dir);
      Put_File
        (Dir, "parts/widget-one.md",
         L ("---") & L ("template: part") & L ("name: ""Widget One""")
         & L ("ally: ""[[gadget-two]]""") & L ("kinds: [""friend""]")
         & L ("---") & LF & L ("Mentions [[gadget-two|Gadget]] in prose."));
      Put_File
        (Dir, "parts/gadget-two.md",
         L ("---") & L ("template: part") & L ("name: ""Gadget Two""")
         & L ("workshop: ""The Brass Workshop""") & L ("---") & LF
         & L ("Plain prose."));
      Put_File
        (Dir, "items/sprocket.md",
         L ("---") & L ("template: item") & L ("name: Sprocket")
         & L ("owner: ""[[widget-one]]""") & L ("---"));
      Put_File
        (Dir, "_templates/part_template.md",
         L ("---") & L ("name: """"") & L ("template: ""part""")
         & L ("ally: """"") & L ("---"));
      return Dir;
   end Make_Bible;

   procedure Check
     (R : Result; Code : Integer; Output_Part, Error_Part : String;
      What : String) is
   begin
      Assert
        (R.Exit_Code = Code,
         What & ": exit code" & R.Exit_Code'Image & ", errors <"
         & Err_Text (R) & ">");
      Assert
        (Contains (Out_Text (R), Output_Part),
         What & ": standard output was <" & Out_Text (R) & ">");
      Assert
        (Contains (Err_Text (R), Error_Part),
         What & ": standard error was <" & Err_Text (R) & ">");
   end Check;

   procedure Help_And_Usage_Errors
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Directory ("usage");
   begin
      Check (Run (Dir, "--help"), 0, "", "usage: synapse-bard <command>", "help");
      Assert (Out_Text (Run (Dir, "--help")) = "", "help is on standard error");
      Check (Run (Dir), 2, "", "usage: synapse-bard <command>", "no command");
      Check
        (Run (Dir, "bogus"), 2, "",
         "synapse-bard: unknown command 'bogus'", "unknown command");
      Check
        (Run (Dir, "field", "--help"), 0, "",
         "usage: synapse-bard field <node> <key>", "subcommand help");
      Check
        (Run (Dir, "query"), 2, "", "usage: synapse-bard query", "no node");
      Check
        (Run (Dir, "search", "--field", "nocolon"), 2, "",
         "--field needs key:value, got 'nocolon'", "bad --field");
      if not Is_Enclosed (Dir) then
         Check
           (Run (Dir, "verify"), 1, "",
            "synapse-bard: not inside a git repository", "no repository");
      end if;
      Remove (Dir);
   end Help_And_Usage_Errors;

   procedure Sync_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Bible ("sync");
   begin
      Check
        (Run (Dir, "sync", "--check"), 1, "drift: Items.md",
         "", "drift before the first sync");
      Check
        (Run (Dir, "sync"), 0,
         "ingested: 3" & LF & "skipped (unsupported): 0" & LF
         & "collisions: 0" & LF & "clusters: 2" & LF
         & "removed (no longer in source): 0" & LF & "seeded ",
         "", "first sync");
      Check
        (Run (Dir, "sync"), 0, "ingested: 3", "", "second sync");
      Assert
        (not Contains (Out_Text (Run (Dir, "sync")), "seeded"),
         "the vault index is seeded once");
      Check
        (Run (Dir, "sync", "--check"), 0,
         "_bard/graph/ matches source -- no drift", "", "no drift");
      Put_File
        (Dir, "parts/extra.md",
         L ("---") & L ("name: Extra") & L ("template: part") & L ("---"));
      Check
        (Run (Dir, "sync", "--check"), 1, "drift: Parts.md",
         "", "drift after an edit");
      Check
        (Run (Dir, "sync"), 0, "ingested: 4", "", "sync after the edit");
      Check
        (Run (Dir, "sync", "--check"), 0, "no drift", "", "in step again");
      Remove (Dir);
   end Sync_Lifecycle;

   procedure Reading_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Bible ("read");
      Synced : constant Result := Run (Dir, "sync");
   begin
      Assert (Synced.Exit_Code = 0, "fixture sync");
      Check
        (Run (Dir, "query", "widget-one"), 0,
         "Widget One (part)" & LF & "  ally -> gadget-two" & LF, "", "query");
      Check
        (Run (Dir, "query", "widget-one", "--inbound"), 0,
         "widget-one <- sprocket (owner)", "", "query --inbound");
      Check (Run (Dir, "query", "nope"), 1, "", "nope: not found", "unknown");
      Check
        (Run (Dir, "field", "gadget-two", "name"), 0,
         "name: ""Gadget Two""" & LF, "", "field");
      Check
        (Run (Dir, "fields", "widget-one"), 0,
         "name" & LF & "template" & LF & "ally" & LF, "", "fields");
      Check
        (Run (Dir, "search", "brass"), 0,
         "gadget-two (1)  workshop: ""The Brass Workshop""", "", "search");
      Check
        (Run (Dir, "search", "--field", "template:part"), 0,
         "widget-one (1)  template: part", "", "search --field");
      Check
        (Run (Dir, "verify"), 0, "broken frontmatter links: 0", "", "verify");
      Put_File
        (Dir, "parts/gadget-two.md",
         L ("---") & L ("template: part") & L ("name: ""Gadget Two""")
         & L ("ally: ""[[ghost]]""") & L ("---"));
      Check
        (Run (Dir, "verify"), 1,
         "parts/gadget-two.md:ally -> ghost (unresolved)", "",
         "verify with a finding");
      Remove (Dir);
   end Reading_Commands;

   procedure Runs_From_A_Subdirectory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir    : constant String := Make_Bible ("subdir");
      Synced : constant Result := Run (Dir, "sync");
   begin
      Assert (Synced.Exit_Code = 0, "fixture sync");
      Check
        (Run (Dir & "/parts", "field", "gadget-two", "name"), 0,
         "name: ""Gadget Two""", "", "from a subdirectory of the repository");
      Remove (Dir);
   end Runs_From_A_Subdirectory;

   procedure Vault_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Bible ("vault");
   begin
      Put_File
        (Dir, "_bard/vault/popular.md", L ("# Popular") & L ("the brass cog"));
      Put_File
        (Dir, "_bard/vault/lonely.md", L ("# Lonely") & L ("the brass cog"));
      Put_File (Dir, "_bard/vault/a.md", L ("links to [[popular]]"));
      Check
        (Run (Dir, "vault-search", "brass cog"), 0,
         "popular.md (1)  the brass cog" & LF & "lonely.md (0)  the brass cog",
         "", "vault-search");
      Check
        (Run (Dir, "vault-links", "popular"), 0, "popular <- a.md", "",
         "vault-links");
      Check
        (Run (Dir, "vault-links", "nope"), 1, "",
         "nope: no note by this name in _bard/vault/", "unknown note");
      Remove (Dir);
   end Vault_Commands;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("synapse-bard");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Help_And_Usage_Errors'Access,
         "help, usage errors and no repository");
      Register_Routine
        (T, Sync_Lifecycle'Access,
         "sync, sync again, --check before and after an edit");
      Register_Routine
        (T, Reading_Commands'Access,
         "query, field, fields, search and verify on a synced bible");
      Register_Routine
        (T, Runs_From_A_Subdirectory'Access,
         "a command run from a subdirectory finds the repository");
      Register_Routine
        (T, Vault_Commands'Access, "vault-search and vault-links");
   end Register_Tests;

end Acceptance.Cli_Tests;
