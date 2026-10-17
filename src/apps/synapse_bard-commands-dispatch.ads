--  Runs the command named by the first argument.

package Synapse_Bard.Commands.Dispatch is

   --  Args are the arguments after the program name. No arguments is a usage
   --  error; `-h` or `--help` prints the usage and succeeds; help needs no
   --  repository.
   function Run (Env : Environment; Args : Arguments) return Exit_Code;

end Synapse_Bard.Commands.Dispatch;
