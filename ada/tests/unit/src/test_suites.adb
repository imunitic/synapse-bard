with Pin_Tests;
with Synapse_Bard.Frontmatter_Extractor.Tests;
with Synapse_Bard.Frontmatter_Fields.Tests;

package body Test_Suites is

   Result : aliased AUnit.Test_Suites.Test_Suite;

   Pin_Test_Case : aliased Pin_Tests.Test_Case;

   Frontmatter_Fields_Tests :
     aliased Synapse_Bard.Frontmatter_Fields.Tests.Test_Case;

   Frontmatter_Extractor_Tests :
     aliased Synapse_Bard.Frontmatter_Extractor.Tests.Test_Case;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Pin_Test_Case'Access);
      Result.Add_Test (Frontmatter_Fields_Tests'Access);
      Result.Add_Test (Frontmatter_Extractor_Tests'Access);
      return Result'Access;
   end Suite;

end Test_Suites;
