with AUnit.Assertions;

with Synapse.Core.UTF8;

package body Pin_Tests is

   use AUnit.Assertions;

   procedure Library_Unit_Is_Callable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Synapse.Core.UTF8.Byte ("a", 1) = Character'Pos ('a'),
         "Byte of a one-byte string is its code");
   end Library_Unit_Is_Callable;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Pin");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Library_Unit_Is_Callable'Access,
         "the pinned library's UTF8 unit is callable");
   end Register_Tests;

end Pin_Tests;
