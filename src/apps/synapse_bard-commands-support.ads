with Synapse.Core.Optional_Text;
with Synapse.Core.Options;

with Synapse_Bard.Manuscript;
with Synapse_Bard.Syntax;

--  What the subcommands share.

package Synapse_Bard.Commands.Support is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   LF  : constant Character := Synapse_Bard.Syntax.LF;
   TAB : constant Character := Synapse_Bard.Syntax.TAB;

   function Is_Help (Arg : String) return Boolean is
     (Arg = "-h" or else Arg = "--help");

   --  Argument N (from 1) of Args.
   function Arg (Args : Arguments; N : Positive) return String;

   function Count (Args : Arguments) return Natural;

   package Exit_Options is new Synapse.Core.Options (Exit_Code);

   --  The common start of a command that takes exactly Wanted arguments, the
   --  first being a help flag when it is the only one: the exit code to leave
   --  with after printing Usage on standard error, or none when the arguments
   --  are as expected.
   function Check_Usage
     (Env : Environment; Usage : String; Args : Arguments; Wanted : Natural)
      return Exit_Options.Option;

   --  The manuscript under Root, as Manuscript.Load reads it, saying on
   --  standard error why not when it is refused.
   function Load_Manuscript
     (Env : Environment; Command, Root : String)
      return Synapse_Bard.Manuscript.Loaded.Result;

   procedure Out_Text (Env : Environment; Text : String);

   --  Diagnostics and usage text.
   procedure Err_Text (Env : Environment; Text : String);

   --  A wikilink target with a literal `.md` resolves like one without.
   function Strip_Md_Suffix (Text : String) return String;

   --  Path as an absolute path: itself when it already is one, else under the
   --  directory the command was started in.
   function Resolve_Path (Env : Environment; Path : String) return String;

   --  The package's content root, where the files it ships live:
   --  $SYNAPSE_BARD_CONTENT_ROOT; none when it is not set.
   function Content_Root (Env : Environment) return Maybe_Text;

   --  $SYNAPSE_BARD_WORK_DIR, where the book-to-bible steps keep what they
   --  produce; none when it is unset or empty.
   function Work_Dir (Env : Environment) return Maybe_Text;

   --  The text of a file of at most 1 MiB; none when it cannot be read.
   function Read_Source (Path : String) return Maybe_Text;

end Synapse_Bard.Commands.Support;
