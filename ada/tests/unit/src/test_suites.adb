with Pin_Tests;
with Synapse_Bard.Cluster.Tests;
with Synapse_Bard.Commands.Tests;
with Synapse_Bard.Frontmatter_Extractor.Tests;
with Synapse_Bard.Graph_Store.Tests;
with Synapse_Bard.Sync_Plan.Tests;
with Synapse_Bard.Vault_Store.Tests;
with Synapse_Bard.Frontmatter_Fields.Tests;

package body Test_Suites is

   Result : aliased AUnit.Test_Suites.Test_Suite;

   Pin_Test_Case : aliased Pin_Tests.Test_Case;

   Frontmatter_Fields_Tests :
     aliased Synapse_Bard.Frontmatter_Fields.Tests.Test_Case;

   Frontmatter_Extractor_Tests :
     aliased Synapse_Bard.Frontmatter_Extractor.Tests.Test_Case;

   Graph_Store_Tests : aliased Synapse_Bard.Graph_Store.Tests.Test_Case;

   Cluster_Tests : aliased Synapse_Bard.Cluster.Tests.Test_Case;

   Vault_Store_Tests : aliased Synapse_Bard.Vault_Store.Tests.Test_Case;

   Sync_Plan_Tests : aliased Synapse_Bard.Sync_Plan.Tests.Test_Case;

   Commands_Tests : aliased Synapse_Bard.Commands.Tests.Test_Case;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Pin_Test_Case'Access);
      Result.Add_Test (Frontmatter_Fields_Tests'Access);
      Result.Add_Test (Frontmatter_Extractor_Tests'Access);
      Result.Add_Test (Graph_Store_Tests'Access);
      Result.Add_Test (Cluster_Tests'Access);
      Result.Add_Test (Vault_Store_Tests'Access);
      Result.Add_Test (Sync_Plan_Tests'Access);
      Result.Add_Test (Commands_Tests'Access);
      return Result'Access;
   end Suite;

end Test_Suites;
