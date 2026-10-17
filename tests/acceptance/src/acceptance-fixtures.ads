with Ada.Strings.Unbounded;

with Synapse.Ports.Process_Runner;

--  A scratch git repository and the means of running the built program in it.

package Acceptance.Fixtures is

   subtype Result is Synapse.Ports.Process_Runner.Result;

   LF : constant Character := Character'Val (10);

   --  A new, empty directory under the temporary directory, named after Label.
   function Make_Directory (Label : String) return String;

   --  Makes Dir a git repository (`git init`).
   procedure Init_Git (Dir : String);

   --  A file at Dir/Rel, with its directories.
   procedure Put_File (Dir, Rel, Content : String);

   procedure Remove (Dir : String);

   --  Whether some directory above Dir holds `.git`.
   function Is_Enclosed (Dir : String) return Boolean;

   --  Runs the program under test in Dir with up to four arguments.
   function Run
     (Dir : String; A1 : String := ""; A2 : String := ""; A3 : String := "";
      A4  : String := "") return Result;

   --  Runs the hook binary (the program under test with `-hook` appended) in
   --  Dir with Stdin as its standard input, and `HOME`, `CLAUDE_PLUGIN_ROOT`
   --  and `SYNAPSE_BARD_CONTENT_ROOT` set to the given values for the call; an
   --  empty name of a variable leaves it unset. The environment of this
   --  process is put back afterwards.
   function Run_Hook
     (Dir : String; Hook : String; Stdin : String; Home : String := "";
      Plugin_Root : String := ""; Content_Root : String := "") return Result;

   function Out_Text (R : Result) return String is
     (Ada.Strings.Unbounded.To_String (R.Output));

   function Err_Text (R : Result) return String is
     (Ada.Strings.Unbounded.To_String (R.Errors));

   function Contains (Text, Part : String) return Boolean;

end Acceptance.Fixtures;
