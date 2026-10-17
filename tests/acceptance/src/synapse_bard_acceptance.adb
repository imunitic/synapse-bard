with Ada.Command_Line;

with AUnit.Reporter.Text;
with AUnit.Run;

with Acceptance;
with Test_Suites;

--  The first argument is the program under test.

procedure Synapse_Bard_Acceptance is
   function Run is new AUnit.Run.Test_Runner_With_Status (Test_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   use type AUnit.Status;
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Acceptance.Set_Binary (Ada.Command_Line.Argument (1));
   if Run (Reporter) /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Synapse_Bard_Acceptance;
