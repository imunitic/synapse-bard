with Acceptance.Cli_Tests;

package body Test_Suites is

   Result : aliased AUnit.Test_Suites.Test_Suite;

   Cli : aliased Acceptance.Cli_Tests.Test_Case;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Cli'Access);
      return Result'Access;
   end Suite;

end Test_Suites;
