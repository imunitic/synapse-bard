with Synapse.Core.Optional_Text;

--  What the subcommands share.

package Synapse_Bard.Commands.Support is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   LF : constant Character := Character'Val (10);

   function Is_Help (Arg : String) return Boolean is
     (Arg = "-h" or else Arg = "--help");

   --  Argument N (from 1) of Args.
   function Arg (Args : Arguments; N : Positive) return String;

   function Count (Args : Arguments) return Natural;

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
