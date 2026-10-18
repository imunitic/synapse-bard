with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.Fake_Console;
with Synapse.Adapters.Fake_Variables;
with Synapse.Adapters.File_Bytes;
with Synapse.Core.Text_Lists;

with Synapse_Bard.Commands.Dispatch;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Commands.Verify;
with Synapse_Bard.Graph_Store;
with Synapse_Bard.Vault_Index_Template;

package body Synapse_Bard.Commands.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   ---------------------------------------------------------------------------
   --  Running a command
   ---------------------------------------------------------------------------

   type Result is record
      Code     : Exit_Code;
      Out_Text : Unbounded_String;
      Err_Text : Unbounded_String;
   end record;

   function Run
     (Dir : String; A1 : String := ""; A2 : String := ""; A3 : String := "";
      A4  : String := ""; A5 : String := ""; A6 : String := "";
      Work : String := ""; Content : String := "") return Result
   is
      Console : aliased Synapse.Adapters.Fake_Console.Fake;
      Vars    : aliased Synapse.Adapters.Fake_Variables.Fake_Variables;
      Env     : constant Environment :=
        (Console => Console'Access, Vars => Vars'Access,
         Start   => To_Unbounded_String (Dir));
      Words   : constant array (1 .. 6) of Unbounded_String :=
        [To_Unbounded_String (A1), To_Unbounded_String (A2),
         To_Unbounded_String (A3), To_Unbounded_String (A4),
         To_Unbounded_String (A5), To_Unbounded_String (A6)];
      Args    : Arguments;
      Code    : Exit_Code;
   begin
      if Work /= "" then
         Vars.Set ("SYNAPSE_BARD_WORK_DIR", Work);
      end if;
      if Content /= "" then
         Vars.Set ("SYNAPSE_BARD_CONTENT_ROOT", Content);
      end if;
      for A of Words loop
         if A /= "" then
            Args.Append (A);
         end if;
      end loop;
      Code := Dispatch.Run (Env, Args);
      return
        (Code     => Code,
         Out_Text => To_Unbounded_String (Console.Out_Text),
         Err_Text => To_Unbounded_String (Console.Err_Text));
   end Run;

   procedure Expect
     (R : Result; Code : Exit_Code; Output, Errors : String; What : String) is
   begin
      Assert (R.Code = Code, What & ": exit code" & R.Code'Image);
      Assert
        (To_String (R.Out_Text) = Output,
         What & ": standard output was <" & To_String (R.Out_Text) & ">");
      Assert
        (To_String (R.Err_Text) = Errors,
         What & ": standard error was <" & To_String (R.Err_Text) & ">");
   end Expect;

   function Has (Text : Unbounded_String; Part : String) return Boolean is
      S : constant String := To_String (Text);
   begin
      return
        (for some I in S'First .. S'Last - Part'Length + 1 =>
           S (I .. I + Part'Length - 1) = Part);
   end Has;

   ---------------------------------------------------------------------------
   --  Fixtures
   ---------------------------------------------------------------------------

   procedure Put_File (Root, Rel, Content : String) is
      Path : constant String := Root & "/" & Rel;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put_File;

   --  A repository with a small made-up bible, not yet synced.
   function Make_Repo (Label : String) return String is
      Dir : constant String := Scratch_Dirs.Make (Label);
   begin
      Ada.Directories.Create_Path (Dir & "/.git");
      Put_File
        (Dir, "parts/widget-one.md",
         L ("---") & L ("template: part") & L ("name: ""Widget One""")
         & L ("ally: ""[[gadget-two]]""") & L ("kinds: [""friend""]")
         & L ("images:") & L ("  - path: ""parts/one.png""") & L ("---") & LF
         & L ("Mentions [[gadget-two|Gadget]] and the secret flange."));
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
        (Dir, "items/refused.md",
         L ("---") & L ("name: Refused") & L ("note: |") & L ("  block")
         & L ("---"));
      Put_File
        (Dir, "_templates/part_template.md",
         L ("---") & L ("# --- Identity ---") & L ("name: """"")
         & L ("template: ""part""") & L ("ally: """"") & L ("---"));
      Put_File
        (Dir, "_templates/blank_template.md", L ("no frontmatter here"));
      return Dir;
   end Make_Repo;

   --  The same repository after a `sync`.
   function Make_Synced (Label : String) return String is
      Dir : constant String := Make_Repo (Label);
      R   : constant Result := Run (Dir, "sync");
   begin
      Assert (R.Code = 0, "fixture sync");
      return Dir;
   end Make_Synced;

   ---------------------------------------------------------------------------
   --  Dispatch
   ---------------------------------------------------------------------------

   procedure Dispatch_Usage_And_Help
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("cmd-dispatch");
   begin
      Expect (Run (Dir), 2, "", Usage.Main_Usage, "no arguments");
      Expect (Run (Dir, "--help"), 0, "", Usage.Main_Usage, "--help");
      Expect (Run (Dir, "-h"), 0, "", Usage.Main_Usage, "-h");
      Expect
        (Run (Dir, "bogus"), 2, "",
         L ("synapse-bard: unknown command 'bogus'") & Usage.Main_Usage,
         "unknown command");
      Expect
        (Run (Dir, "query", "--help"), 0, "", Usage.Query_Usage,
         "help needs no repository");
      --  The temporary directory can itself sit inside a repository.
      if not Roots.Resolve (Dir).Found then
         Expect
           (Run (Dir, "verify"), 1, "",
            L ("synapse-bard: not inside a git repository"),
            "outside a repository");
      end if;
      Scratch_Dirs.Remove (Dir);
   end Dispatch_Usage_And_Help;

   procedure Repository_Is_Found_From_A_Subdirectory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Synced ("cmd-subdir");
   begin
      Expect
        (Run (Dir & "/parts", "field", "gadget-two", "name"), 0,
         L ("name: ""Gadget Two"""), "", "from a subdirectory");
      Scratch_Dirs.Remove (Dir);
   end Repository_Is_Found_From_A_Subdirectory;

   ---------------------------------------------------------------------------
   --  field and fields
   ---------------------------------------------------------------------------

   procedure Field_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Synced ("cmd-field");
   begin
      Expect
        (Run (Dir, "field", "widget-one", "images"), 0,
         L ("images:") & L ("  - path: ""parts/one.png"""), "",
         "a nested block");
      Expect
        (Run (Dir, "field", "gadget-two", "name"), 0,
         L ("name: ""Gadget Two"""), "", "a scalar");
      Expect
        (Run (Dir, "field", "nope", "name"), 1, "", L ("nope: not found"),
         "unknown node");
      Expect
        (Run (Dir, "field", "gadget-two", "missing"), 1, "",
         L ("gadget-two: no root-level field 'missing'"), "unknown key");
      Expect (Run (Dir, "field"), 2, "", Usage.Field_Usage, "no node");
      Expect
        (Run (Dir, "field", "gadget-two"), 2, "", Usage.Field_Usage, "no key");
      Expect (Run (Dir, "field", "--help"), 0, "", Usage.Field_Usage, "help");
      Ada.Directories.Delete_File (Dir & "/parts/gadget-two.md");
      Expect
        (Run (Dir, "field", "gadget-two", "name"), 1, "",
         L ("gadget-two: source file unreadable (parts/gadget-two.md)"),
         "a source that is gone");
      Scratch_Dirs.Remove (Dir);
   end Field_Command;

   procedure Fields_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Make_Synced ("cmd-fields");
      Template : constant String := L ("name") & L ("template") & L ("ally");
   begin
      Expect (Run (Dir, "fields", "widget-one"), 0, Template, "", "by node");
      Expect
        (Run (Dir, "fields", "--template", "part"), 0, Template, "",
         "by template name");
      Expect
        (Run (Dir, "fields", "nope"), 1, "", L ("nope: not found"),
         "unknown node");
      Expect
        (Run (Dir, "fields", "--template", "missing"), 1, "",
         L ("synapse-bard fields: no template file for 'missing' (" & Dir
            & "/_templates/missing_template.md)"),
         "a template that is not there");
      Expect
        (Run (Dir, "fields", "--template", "blank"), 1, "",
         L ("synapse-bard fields: 'blank_template.md' has no frontmatter"),
         "a template without frontmatter");
      Put_File
        (Dir, "parts/gadget-two.md",
         L ("---") & L ("name: Gadget") & L ("note: |") & L ("  block")
         & L ("---"));
      Expect
        (Run (Dir, "fields", "gadget-two"), 1, "",
         L ("gadget-two: unsupported (block_scalar)"), "a refused entity");
      Expect
        (Run (Dir, "fields", "--template"), 2, "",
         L ("synapse-bard fields: --template needs a name") & Usage.Fields_Usage,
         "--template without a name");
      Expect
        (Run (Dir, "fields", "widget-one", "extra"), 2, "",
         L ("synapse-bard fields: unexpected argument 'extra'")
         & Usage.Fields_Usage,
         "an extra argument");
      Expect (Run (Dir, "fields"), 2, "", Usage.Fields_Usage, "no arguments");
      Scratch_Dirs.Remove (Dir);
   end Fields_Command;

   ---------------------------------------------------------------------------
   --  query
   ---------------------------------------------------------------------------

   procedure Query_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Synced ("cmd-query");
   begin
      Expect
        (Run (Dir, "query", "widget-one"), 0,
         L ("Widget One (part)") & L ("  ally -> gadget-two"), "",
         "outbound");
      Expect
        (Run (Dir, "query", "widget-one", "--inbound"), 0,
         L ("widget-one <- sprocket (owner)"), "", "inbound");
      Expect
        (Run (Dir, "query", "sprocket", "--inbound"), 0,
         L ("sprocket: no inbound references found"), "", "nothing inbound");
      Expect
        (Run (Dir, "query", "nope"), 1, "", L ("nope: not found"), "unknown");
      Expect
        (Run (Dir, "query", "nope", "--inbound"), 1, "",
         L ("nope: not found"), "unknown, inbound");
      Put_File
        (Dir, "parts/gadget-two.md",
         L ("---") & L ("name: Gadget") & L ("note: |") & L ("  block")
         & L ("---"));
      Expect
        (Run (Dir, "query", "gadget-two"), 1, "",
         L ("gadget-two: unsupported (block_scalar)"), "a refused entity");
      Expect
        (Run (Dir, "query", "widget-one", "--bogus"), 2, "",
         L ("synapse-bard query: unknown option '--bogus'")
         & Usage.Query_Usage,
         "an unknown option");
      Expect (Run (Dir, "query"), 2, "", Usage.Query_Usage, "no node");
      Scratch_Dirs.Remove (Dir);
   end Query_Command;

   ---------------------------------------------------------------------------
   --  search
   ---------------------------------------------------------------------------

   procedure Search_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Synced ("cmd-search");
   begin
      Expect
        (Run (Dir, "search", "brass"), 0,
         L ("gadget-two (1)  workshop: ""The Brass Workshop"""), "",
         "full text ignores case");
      Expect
        (Run (Dir, "search", "flange"), 0, L ("no matches for 'flange'"), "",
         "the prose is never searched");
      Expect
        (Run (Dir, "search", "workshop: x"), 0,
         L ("no matches for 'workshop: x'"), "",
         "a colon in a plain query is plain text");
      Expect
        (Run (Dir, "search", "--field", "workshop:the brass workshop"), 0,
         L ("gadget-two (1)  workshop: ""The Brass Workshop"""), "",
         "--field ignores the case of the value");
      Expect
        (Run (Dir, "search", "--field", "Workshop:the brass workshop"), 0,
         L ("no matches for 'Workshop:the brass workshop'"), "",
         "--field does not ignore the case of the key");
      Expect (Run (Dir, "search"), 2, "", Usage.Search_Usage, "no query");
      Expect
        (Run (Dir, "search", "--field"), 2, "",
         L ("synapse-bard search: --field needs a key:value argument")
         & Usage.Search_Usage,
         "--field alone");
      Expect
        (Run (Dir, "search", "--field", "nocolon"), 2, "",
         L ("synapse-bard search: --field needs key:value, got 'nocolon'")
         & Usage.Search_Usage,
         "--field without a colon");
      Expect
        (Run (Dir, "search", "--field", "key:"), 2, "",
         L ("synapse-bard search: --field needs key:value, got 'key:'")
         & Usage.Search_Usage,
         "--field with an empty value");
      Expect
        (Run (Dir, "search", "a", "b"), 2, "",
         L ("synapse-bard search: unexpected argument 'b'")
         & Usage.Search_Usage,
         "an extra argument");
      Scratch_Dirs.Remove (Dir);
   end Search_Command;

   ---------------------------------------------------------------------------
   --  vault-search and vault-links
   ---------------------------------------------------------------------------

   procedure Vault_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Repo ("cmd-vault");
   begin
      Put_File
        (Dir, "_bard/vault/popular.md", L ("# Popular") & L ("the brass cog"));
      Put_File
        (Dir, "_bard/vault/lonely.md", L ("# Lonely") & L ("the brass cog"));
      Put_File (Dir, "_bard/vault/a.md", L ("links to [[popular]]"));
      Put_File (Dir, "_bard/vault/b.md", L ("links to [[popular|P]] again"));
      Expect
        (Run (Dir, "vault-search", "brass cog"), 0,
         L ("popular.md (2)  the brass cog")
         & L ("lonely.md (0)  the brass cog"),
         "", "ranked by backlinks");
      Expect
        (Run (Dir, "vault-search", "zzz"), 0, L ("no matches for 'zzz'"), "",
         "no match");
      Expect
        (Run (Dir, "vault-links", "popular"), 0,
         L ("popular <- a.md") & L ("popular <- b.md"), "", "linking notes");
      Expect
        (Run (Dir, "vault-links", "lonely"), 0,
         L ("lonely: no inbound links found"), "", "no links");
      Expect
        (Run (Dir, "vault-links", "nope"), 1, "",
         L ("nope: no note by this name in _bard/vault/"), "unknown note");
      Expect
        (Run (Dir, "vault-search"), 2, "", Usage.Vault_Search_Usage,
         "vault-search without a query");
      Expect
        (Run (Dir, "vault-links", "a", "b"), 2, "",
         L ("synapse-bard vault-links: unexpected argument 'b'")
         & Usage.Vault_Links_Usage,
         "an extra argument");
      Scratch_Dirs.Remove (Dir);
   end Vault_Commands;

   ---------------------------------------------------------------------------
   --  verify
   ---------------------------------------------------------------------------

   --  A repository with the entities given, synced into a graph store.
   procedure Report_Of
     (Label : String; Notes : Synapse.Core.Text_Lists.Vector;
      Report : out Verify.Report; Dir : out Unbounded_String;
      Allowed : Synapse.Core.Text_Lists.Vector :=
        Synapse.Core.Text_Lists.Vectors.Empty_Vector)
   is
      Root  : constant String := Scratch_Dirs.Make (Label);
      Store : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (Root & "/_bard/graph");
   begin
      Ada.Directories.Create_Path (Root & "/.git");
      for I in 1 .. Natural (Notes.Length) / 2 loop
         Put_File
           (Root, To_String (Notes (2 * I - 1)), To_String (Notes (2 * I)));
      end loop;
      declare
         R : constant Result := Run (Root, "sync");
      begin
         Assert (R.Code = 0, "fixture sync");
      end;
      Report := Verify.Compute_Report (Root, Allowed, Store);
      Dir := To_Unbounded_String (Root);
   end Report_Of;

   --  Pairs of a path and its text, for up to three notes.
   function Notes_Of
     (A, B : String; C : String := ""; D : String := ""; E : String := "";
      F    : String := "") return Synapse.Core.Text_Lists.Vector
   is
      Items  : constant array (1 .. 6) of Unbounded_String :=
        [To_Unbounded_String (A), To_Unbounded_String (B),
         To_Unbounded_String (C), To_Unbounded_String (D),
         To_Unbounded_String (E), To_Unbounded_String (F)];
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for Item of Items loop
         if Item /= "" then
            Result.Append (Item);
         end if;
      end loop;
      return Result;
   end Notes_Of;

   procedure Verify_Dangling_Frontmatter_Ref
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      R   : Verify.Report;
      Dir : Unbounded_String;
   begin
      Report_Of
        ("cmd-verify-fm",
         Notes_Of
           ("parts/a.md",
            L ("---") & L ("name: A") & L ("template: part")
            & L ("ally: ""[[missing-entity]]""") & L ("---") & LF
            & L ("Prose body.")),
         R, Dir);
      Assert (Natural (R.Frontmatter_Misses.Length) = 1, "one dangling ref");
      Assert
        (To_String (R.Frontmatter_Misses (1).Target) = "missing-entity",
         "its target");
      Assert
        (To_String (R.Frontmatter_Misses (1).File) = "parts/a.md", "its file");
      Assert (R.Prose_Misses.Is_Empty, "no prose findings");
      Assert (R.Kind_Misses.Is_Empty, "no kinds findings");
      Assert (Verify.Total_Findings (R) = 1, "one finding");
      Scratch_Dirs.Remove (To_String (Dir));
   end Verify_Dangling_Frontmatter_Ref;

   procedure Verify_Dangling_Prose_Link
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      R   : Verify.Report;
      Dir : Unbounded_String;
   begin
      Report_Of
        ("cmd-verify-prose",
         Notes_Of
           ("parts/a.md",
            L ("---") & L ("name: A") & L ("template: part") & L ("---") & LF
            & L ("Sees [[missing-entity]] in the distance.")),
         R, Dir);
      Assert (R.Frontmatter_Misses.Is_Empty, "no frontmatter findings");
      Assert (Natural (R.Prose_Misses.Length) = 1, "one dangling prose link");
      Assert
        (To_String (R.Prose_Misses (1).Target) = "missing-entity", "target");
      Assert (R.Kind_Misses.Is_Empty, "no kinds findings");
      Scratch_Dirs.Remove (To_String (Dir));
   end Verify_Dangling_Prose_Link;

   procedure Verify_Unknown_Kinds_Value
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      R       : Verify.Report;
      Dir     : Unbounded_String;
      Allowed : Synapse.Core.Text_Lists.Vector;
      Notes   : constant Synapse.Core.Text_Lists.Vector :=
        Notes_Of
          ("parts/a.md",
           L ("---") & L ("name: A") & L ("template: part")
           & L ("kinds: [""friend"", ""bogus""]") & L ("---") & LF
           & L ("Prose."));
   begin
      Report_Of ("cmd-verify-nokinds", Notes, R, Dir);
      Assert (R.Kind_Misses.Is_Empty, "with no allowed values: not checked");
      Scratch_Dirs.Remove (To_String (Dir));
      Allowed.Append (To_Unbounded_String ("friend"));
      Report_Of ("cmd-verify-kinds", Notes, R, Dir, Allowed);
      Assert (Natural (R.Kind_Misses.Length) = 1, "one unknown value");
      Assert (To_String (R.Kind_Misses (1).Target) = "bogus", "the value");
      Assert (To_String (R.Kind_Misses (1).Field) = "kinds", "the label");
      Scratch_Dirs.Remove (To_String (Dir));
   end Verify_Unknown_Kinds_Value;

   procedure Verify_Allowed_Kinds_Come_From_The_Template_Set
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("cmd-verify-allowed");

      function Joined (Items : Synapse.Core.Text_Lists.Vector) return String is
         Result : Unbounded_String;
      begin
         for Item of Items loop
            Append (Result, To_String (Item) & ",");
         end loop;
         return To_String (Result);
      end Joined;
   begin
      Assert (Verify.Allowed_Kinds (Dir).Is_Empty, "no set at all");
      Put_File (Dir, "_templates/part_template.md", L ("---") & L ("---"));
      Assert (Verify.Allowed_Kinds (Dir).Is_Empty, "no kinds template");
      Put_File
        (Dir, "_templates/kinds_template.md",
         L ("---") & L ("kinds:") & L ("  - ""rival""") & L ("  - mentor")
         & L ("---"));
      Assert
        (Joined (Verify.Allowed_Kinds (Dir)) = "rival,mentor,",
         "the bible's kinds template, block list");
      Put_File
        (Dir, "_templates/kinds_template.md",
         L ("---") & L ("kinds: [friend, ""ally""]") & L ("---"));
      Assert
        (Joined (Verify.Allowed_Kinds (Dir)) = "friend,ally,", "flow list");
      Put_File
        (Dir, "_templates/kinds_template.md", L ("---") & L ("kinds:")
         & L ("---"));
      Assert
        (Verify.Allowed_Kinds (Dir).Is_Empty,
         "a kinds template listing nothing allows nothing to check");
      Scratch_Dirs.Remove (Dir);
   end Verify_Allowed_Kinds_Come_From_The_Template_Set;

   procedure Verify_Finds_Nothing_In_A_Resolving_Fixture
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      R   : Verify.Report;
      Dir : Unbounded_String;
   begin
      Report_Of
        ("cmd-verify-ok",
         Notes_Of
           ("parts/a.md",
            L ("---") & L ("name: A") & L ("template: part")
            & L ("kinds: [""friend""]") & L ("ally: ""[[b]]""") & L ("---")
            & LF & L ("Mentions [[b|B]] warmly."),
            "parts/b.md",
            L ("---") & L ("name: B") & L ("template: part") & L ("---") & LF
            & L ("Prose only, no links.")),
         R, Dir);
      Assert (Verify.Total_Findings (R) = 0, "zero findings");
      Scratch_Dirs.Remove (To_String (Dir));
   end Verify_Finds_Nothing_In_A_Resolving_Fixture;

   procedure Verify_Tally_Counts_Distinct_Entities
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      R   : Verify.Report;
      Dir : Unbounded_String;
   begin
      Report_Of
        ("cmd-verify-tally",
         Notes_Of
           ("parts/a.md",
            L ("---") & L ("name: A") & L ("template: part") & L ("---") & LF
            & L ("Sees [[c|C]] then [[c]] again, twice in one file."),
            "parts/b.md",
            L ("---") & L ("name: B") & L ("template: part") & L ("---") & LF
            & L ("Also mentions [[c|C]]."),
            "parts/c.md",
            L ("---") & L ("name: C") & L ("template: part") & L ("---") & LF
            & L ("Nothing here.")),
         R, Dir);
      Assert (Verify.Total_Findings (R) = 0, "zero findings");
      Assert (Natural (R.Mentions.Length) = 1, "one tallied target");
      Assert (To_String (R.Mentions (1).Target) = "c", "its name");
      Assert (R.Mentions (1).Count = 2, "two entities, not three mentions");
      Scratch_Dirs.Remove (To_String (Dir));
   end Verify_Tally_Counts_Distinct_Entities;

   procedure Verify_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir : constant String := Make_Synced ("cmd-verify");
   begin
      Expect
        (Run (Dir, "verify"), 0,
         L ("broken frontmatter links: 0") & L ("broken prose links: 0")
         & L ("kinds values: not checked (no kinds template)") & LF
         & L ("mention counts:") & L ("gadget-two: 1"),
         "", "no kinds template: values are not checked");
      Put_File
        (Dir, "_templates/kinds_template.md",
         L ("---") & L ("kinds: [""friend"", ""ally""]") & L ("---"));
      Expect
        (Run (Dir, "verify"), 0,
         L ("broken frontmatter links: 0") & L ("broken prose links: 0")
         & L ("unknown kinds values: 0") & LF & L ("mention counts:")
         & L ("gadget-two: 1"),
         "", "a clean bible");
      Put_File
        (Dir, "parts/gadget-two.md",
         L ("---") & L ("template: part") & L ("name: ""Gadget Two""")
         & L ("ally: ""[[ghost]]""") & L ("kinds: [""bogus""]") & L ("---")
         & LF & L ("See [[phantom]]."));
      declare
         R : constant Result := Run (Dir, "verify");
      begin
         Assert (R.Code = 1, "findings give exit code 1");
         Assert (Has (R.Out_Text, "broken frontmatter links: 1"), "fm count");
         Assert (Has (R.Out_Text, "broken prose links: 1"), "prose count");
         Assert (Has (R.Out_Text, "unknown kinds values: 1"), "kinds count");
         Assert
           (Has (R.Out_Text,
                 "parts/gadget-two.md:ally -> ghost (unresolved)"),
            "a frontmatter finding");
         Assert
           (Has (R.Out_Text,
                 "parts/gadget-two.md:prose -> phantom (unresolved)"),
            "a prose finding");
         Assert
           (Has (R.Out_Text, "parts/gadget-two.md:kinds -> bogus (unresolved)"),
            "a kinds finding");
      end;
      Expect
        (Run (Dir, "verify", "x"), 2, "",
         L ("synapse-bard verify: unexpected argument 'x'")
         & Usage.Verify_Usage,
         "an argument");
      Scratch_Dirs.Remove (Dir);
   end Verify_Command;

   ---------------------------------------------------------------------------
   --  sync
   ---------------------------------------------------------------------------

   procedure Sync_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir   : constant String := Make_Repo ("cmd-sync");
      First : constant Result := Run (Dir, "sync");
   begin
      Assert (First.Code = 0, "first sync");
      Assert
        (Has (First.Out_Text,
              L ("skipped (block_scalar): items/refused.md")),
         "the report line");
      Assert
        (Has (First.Out_Text,
              LF & L ("ingested: 3") & L ("skipped (unsupported): 1")
              & L ("collisions: 0") & L ("clusters: 2")
              & L ("removed (no longer in source): 0")
              & L ("seeded " & Dir & "/_bard/vault/Index.md (first use)")),
         "the summary and the seeded index");
      Assert
        (Ada.Directories.Exists (Dir & "/_bard/graph/Parts.md")
         and then Ada.Directories.Exists (Dir & "/_bard/graph/Items.md"),
         "one node per cluster");
      Assert
        (Synapse.Adapters.File_Bytes.Read
           (Dir & "/_bard/vault/Index.md", 2**20) =
           Synapse_Bard.Vault_Index_Template.Text,
         "the starter index");

      declare
         Second : constant Result := Run (Dir, "sync");
      begin
         Assert (not Has (Second.Out_Text, "seeded"), "seeded only once");
         Assert (Has (Second.Out_Text, "removed (no longer in source): 0"),
                 "nothing removed");
      end;
      Expect
        (Run (Dir, "sync", "--check"), 0,
         L ("_bard/graph/ matches source -- no drift"), "", "no drift");

      --  An edit changes a cluster's members; a stale node is dropped.
      Put_File
        (Dir, "parts/extra.md",
         L ("---") & L ("name: Extra") & L ("template: part") & L ("---"));
      Synapse.Adapters.File_Bytes.Write
        (Dir & "/_bard/graph/Old.md", "stale");
      declare
         Checked : constant Result := Run (Dir, "sync", "--check");
      begin
         Assert (Checked.Code = 1, "drift gives exit code 1");
         Assert (Has (Checked.Out_Text, "drift: Parts.md" & LF), "dirty node");
         Assert
           (Has (Checked.Out_Text, "would remove: Old.md" & LF), "stale node");
         Assert
           (Has (Checked.Out_Text,
                 LF & "2 cluster(s) out of date -- run `synapse-bard sync`"
                 & LF),
            "the summary");
      end;
      Assert
        (Ada.Directories.Exists (Dir & "/_bard/graph/Old.md"),
         "--check writes nothing");

      declare
         Third : constant Result := Run (Dir, "sync");
      begin
         Assert (Has (Third.Out_Text, "removed (no longer in source): 1"),
                 "the stale node is removed");
      end;
      Assert
        (not Ada.Directories.Exists (Dir & "/_bard/graph/Old.md"), "gone");

      --  A hand-written tail under the end marker survives a re-run.
      declare
         Path : constant String := Dir & "/_bard/graph/Items.md";
         Text : constant String :=
           Synapse.Adapters.File_Bytes.Read (Path, 2**20);
      begin
         Synapse.Adapters.File_Bytes.Write
           (Path, Text & LF & L ("## Notes") & L ("Keep me."));
         declare
            Again : constant Result := Run (Dir, "sync");
         begin
            Assert (Again.Code = 0, "sync with a tail");
         end;
         Assert
           (Has
              (To_Unbounded_String
                 (Synapse.Adapters.File_Bytes.Read (Path, 2**20)),
               L ("## Notes") & L ("Keep me.")),
            "the tail is kept");
      end;

      Expect
        (Run (Dir, "sync", "x"), 2, "",
         L ("synapse-bard sync: unexpected argument 'x'") & Usage.Sync_Usage,
         "an unknown argument");
      Expect
        (Run (Dir, "sync", "--check", "x"), 2, "",
         L ("synapse-bard sync: unexpected argument 'x'") & Usage.Sync_Usage,
         "an extra argument");
      Scratch_Dirs.Remove (Dir);
   end Sync_Command;

   --  The starter index is the template the package ships.
   procedure Starter_Index_Equals_The_Shipped_Template
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Relative : constant String := "packages/synapse-bard/Index.md.template";
      Dir      : Unbounded_String :=
        To_Unbounded_String (Ada.Directories.Current_Directory);
   begin
      loop
         exit when Ada.Directories.Exists (To_String (Dir) & "/" & Relative);
         declare
            Parent : constant String :=
              Ada.Directories.Containing_Directory (To_String (Dir));
         begin
            Assert (Parent /= To_String (Dir), "the shipped template is found");
            Dir := To_Unbounded_String (Parent);
         end;
      end loop;
      Assert
        (Synapse.Adapters.File_Bytes.Read (To_String (Dir) & "/" & Relative, 2**20)
         = Synapse_Bard.Vault_Index_Template.Text,
         "byte-identical to Index.md.template");
   end Starter_Index_Equals_The_Shipped_Template;

   ---------------------------------------------------------------------------
   --  Registration
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   --  Book to bible
   ---------------------------------------------------------------------------

   TAB : constant String := [Character'Val (9)];

   --  A manuscript root holding one folder book of two chapters.
   function Make_Manuscript (Label : String) return String is
      Dir : constant String := Scratch_Dirs.Make (Label);
   begin
      Put_File (Dir, "index.md", L ("1. the_long_road/"));
      Put_File
        (Dir, "the_long_road/index.md",
         L ("1. Departure.md") & L ("2. Arrival.md"));
      Put_File
        (Dir, "the_long_road/Departure.md",
         L ("Aidan left at dawn.") & L ("Nobody saw him go."));
      Put_File
        (Dir, "the_long_road/Arrival.md", L ("Aidan reached Ashfall."));
      return Dir;
   end Make_Manuscript;

   procedure Manuscript_Command
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Manuscript ("cmd-manuscript");
   begin
      Expect (Run (Dir, "manuscript"), 2, "", Usage.Manuscript_Usage,
              "no root");
      Expect (Run (Dir, "manuscript", "--help"), 0, "",
              Usage.Manuscript_Usage, "--help");
      Expect
        (Run (Dir, "manuscript", "."), 0,
         "The long road" & TAB & "Departure" & TAB & Dir
         & "/the_long_road/Departure.md" & TAB & "1" & TAB & "2" & LF
         & "The long road" & TAB & "Arrival" & TAB & Dir
         & "/the_long_road/Arrival.md" & TAB & "1" & TAB & "1" & LF, "",
         "a relative root is under the start directory");
      Put_File (Dir, "index.md", L ("1. missing/"));
      declare
         R : constant Result := Run (Dir, "manuscript", Dir);
      begin
         Assert (R.Code = 1, "a missing book is refused");
         Assert (Has (R.Err_Text, "'missing' does not exist"), "the reason");
      end;
      Scratch_Dirs.Remove (Dir);
   end Manuscript_Command;

   procedure Ground_Command
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir  : constant String := Make_Manuscript ("cmd-ground");
      Work : constant String := Dir & "/work";
   begin
      Put_File
        (Dir, "roster.tsv",
         L ("Aidan Dayne" & TAB & "character" & TAB & "Aidan")
         & L ("Ashfall" & TAB & "place"));
      Expect (Run (Dir, "ground"), 2, "", Usage.Ground_Usage, "no arguments");
      declare
         R : constant Result := Run (Dir, "ground", Dir, Dir & "/roster.tsv");
      begin
         Assert (R.Code = 1, "no work directory is refused");
         Assert (Has (R.Err_Text, "SYNAPSE_BARD_WORK_DIR is not set"),
                 "says why");
      end;
      declare
         R : constant Result :=
           Run (Dir, "ground", Dir, "roster.tsv", Work => Work);
      begin
         Assert (R.Code = 0, "ground succeeds: " & To_String (R.Err_Text));
         Assert
           (To_String (R.Out_Text) =
              "Wrote " & Work & "/_refs.tsv (3 references)" & LF,
            "reports the file: " & To_String (R.Out_Text));
      end;
      declare
         Index : constant Support.Maybe_Text :=
           Support.Read_Source (Work & "/_refs.tsv");
      begin
         Assert (Index.Found, "the index file exists");
         Assert
           (Has (Index.Value, "Aidan" & TAB & "Aidan Dayne" & TAB
                 & "The long road" & TAB & "Departure"),
            "an alias row, entity first column two");
         Assert
           (Has (Index.Value, "Ashfall" & TAB & "Ashfall" & TAB
                 & "The long road" & TAB & "Arrival"),
            "a name row");
      end;
      Put_File (Dir, "roster.tsv", "Lonely" & LF);
      declare
         R : constant Result :=
           Run (Dir, "ground", Dir, "roster.tsv", Work => Work);
      begin
         Assert (R.Code = 1, "a bad roster is refused");
         Assert (Has (R.Err_Text, "roster line 1"), "names the line");
      end;
      Scratch_Dirs.Remove (Dir);
   end Ground_Command;

   procedure Quote_Command
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Make_Manuscript ("cmd-quote");
   begin
      Expect (Run (Dir, "quote"), 2, "", Usage.Quote_Usage, "no arguments");
      Expect
        (Run (Dir, "quote", ".", "The long road", "Departure", "2",
              "Nobody saw him"), 0, "", "", "a quote on its line");
      declare
         R : constant Result :=
           Run (Dir, "quote", ".", "The long road", "Departure", "1",
                "Nobody saw him");
      begin
         Assert (R.Code = 1, "a quote on another line");
         Assert (Has (R.Err_Text, "not found on line 1"), "says so");
      end;
      Assert
        (Run (Dir, "quote", ".", "The long road", "Departure", "two",
              "x").Code = 2, "a line that is not a number");
      Assert
        (Run (Dir, "quote", ".", "The long road", "Departure", "0",
              "x").Code = 2, "line numbers start at 1");
      Scratch_Dirs.Remove (Dir);
   end Quote_Command;

   procedure Templates_Command
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir     : constant String := Make_Repo ("cmd-templates");
      Content : constant String := Scratch_Dirs.Make ("cmd-templates-content");
   begin
      Put_File (Content, "templates/widget_template.md", L ("---") & L ("w"));
      Put_File (Content, "templates/gadget_template.md", L ("---") & L ("g"));
      Expect (Run (Dir, "templates", "extra"), 2, "", Usage.Templates_Usage,
              "an unknown argument");
      Expect
        (Run (Dir, "templates", Content => Content), 0,
         "blank" & TAB & Dir & "/_templates/blank_template.md" & LF
         & "part" & TAB & Dir & "/_templates/part_template.md" & LF,
         "", "the bible's own templates, by kind");
      declare
         R : constant Result :=
           Run (Dir, "templates", "--install", Content => Content);
      begin
         Assert (R.Code = 1, "nothing is installed over existing templates");
         Assert (Has (R.Err_Text, "already holds templates"), "says why");
      end;
      Ada.Directories.Delete_Tree (Dir & "/_templates");
      Put_File (Dir, "_templates/notes.md", L ("not a template"));
      declare
         R : constant Result := Run (Dir, "templates", Content => Content);
      begin
         Assert (R.Code = 1, "a bible with no template has no set");
         Assert (Has (R.Err_Text, "no template set"), "says why");
      end;
      Expect
        (Run (Dir, "templates", "--install", Content => Content), 0,
         "installed " & Dir & "/_templates/gadget_template.md" & LF
         & "installed " & Dir & "/_templates/widget_template.md" & LF,
         "", "the default set is copied in");
      declare
         Copy : constant Support.Maybe_Text :=
           Support.Read_Source (Dir & "/_templates/gadget_template.md");
      begin
         Assert
           (Copy.Found and then To_String (Copy.Value) = L ("---") & L ("g"),
            "a copy has the shipped content");
      end;
      Assert
        (Support.Read_Source (Dir & "/_templates/notes.md").Found,
         "an unrelated file is untouched");
      Assert
        (Run (Dir, "templates", "--install", Content => Content).Code = 1,
         "a second install is refused");
      Ada.Directories.Delete_Tree (Dir & "/_templates");
      declare
         R : constant Result := Run (Dir, "templates", "--install");
      begin
         Assert (R.Code = 1, "no shipped set, nothing to install");
         Assert (Has (R.Err_Text, "ships no default template set"), "says why");
      end;
      Scratch_Dirs.Remove (Dir);
      Scratch_Dirs.Remove (Content);
   end Templates_Command;

   procedure Mode_Command
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Full  : constant String := Make_Repo ("cmd-mode-report");
      Empty : constant String := Scratch_Dirs.Make ("cmd-mode-generate");
   begin
      Expect (Run (Full, "mode"), 0, L ("report"), "",
              "a bible with entity files");
      Expect (Run (Full, "mode", "extra"), 2, "", Usage.Mode_Usage,
              "an argument");
      Ada.Directories.Create_Path (Empty & "/.git");
      Put_File (Empty, "_templates/part_template.md", L ("---") & L ("---"));
      Expect (Run (Empty, "mode"), 0, L ("generate"), "",
              "templates are not entity files");
      Put_File
        (Empty, "people/aidan.md",
         L ("---") & L ("template: part") & L ("name: Aidan") & L ("---"));
      Expect (Run (Empty, "mode"), 0, L ("report"), "",
              "one entity file is enough");
      Scratch_Dirs.Remove (Full);
      Scratch_Dirs.Remove (Empty);
   end Mode_Command;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Commands");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Dispatch_Usage_And_Help'Access,
         "usage, help, unknown commands and no repository");
      Register_Routine
        (T, Repository_Is_Found_From_A_Subdirectory'Access,
         "the repository is found from a subdirectory");
      Register_Routine (T, Field_Command'Access, "field");
      Register_Routine (T, Fields_Command'Access, "fields");
      Register_Routine (T, Query_Command'Access, "query");
      Register_Routine (T, Search_Command'Access, "search");
      Register_Routine (T, Vault_Commands'Access, "vault-search and vault-links");
      Register_Routine
        (T, Verify_Dangling_Frontmatter_Ref'Access,
         "verify reports a dangling frontmatter ref");
      Register_Routine
        (T, Verify_Dangling_Prose_Link'Access,
         "verify reports a dangling prose-body wikilink");
      Register_Routine
        (T, Verify_Unknown_Kinds_Value'Access,
         "verify reports an unknown kinds value");
      Register_Routine
        (T, Verify_Allowed_Kinds_Come_From_The_Template_Set'Access,
         "verify takes its allowed kinds from the bible's kinds template");
      Register_Routine
        (T, Verify_Finds_Nothing_In_A_Resolving_Fixture'Access,
         "verify finds nothing in a fully resolving fixture");
      Register_Routine
        (T, Verify_Tally_Counts_Distinct_Entities'Access,
         "verify's mention tally counts distinct entities, not occurrences");
      Register_Routine (T, Verify_Command'Access, "verify");
      Register_Routine (T, Sync_Command'Access, "sync");
      Register_Routine (T, Manuscript_Command'Access, "manuscript");
      Register_Routine (T, Ground_Command'Access, "ground");
      Register_Routine (T, Quote_Command'Access, "quote");
      Register_Routine (T, Templates_Command'Access, "templates");
      Register_Routine (T, Mode_Command'Access, "mode");
      Register_Routine
        (T, Starter_Index_Equals_The_Shipped_Template'Access,
         "the starter index is the shipped template");
   end Register_Tests;

end Synapse_Bard.Commands.Tests;
