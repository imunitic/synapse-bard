--  The acceptance suite of synapse-bard: the built program, run as a
--  subprocess in scratch repositories, and what it writes to each stream and
--  returns.

package Acceptance is

   --  The program under test, as the path the suite was started with.
   procedure Set_Binary (Path : String);

   function Binary return String;

end Acceptance;
