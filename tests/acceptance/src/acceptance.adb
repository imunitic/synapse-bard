with Ada.Strings.Unbounded;

package body Acceptance is

   Under_Test : Ada.Strings.Unbounded.Unbounded_String;

   procedure Set_Binary (Path : String) is
   begin
      Under_Test := Ada.Strings.Unbounded.To_Unbounded_String (Path);
   end Set_Binary;

   function Binary return String is
     (Ada.Strings.Unbounded.To_String (Under_Test));

end Acceptance;
