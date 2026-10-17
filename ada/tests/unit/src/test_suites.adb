with Pin_Tests;

package body Test_Suites is

   Result : aliased AUnit.Test_Suites.Test_Suite;

   Pin_Test_Case : aliased Pin_Tests.Test_Case;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Pin_Test_Case'Access);
      return Result'Access;
   end Suite;

end Test_Suites;
