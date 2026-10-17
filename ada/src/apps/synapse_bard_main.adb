with Ada.Text_IO;

with Synapse.Core.UTF8;

procedure Synapse_Bard_Main is
   First_Byte : constant Natural := Synapse.Core.UTF8.Byte ("s", 1);
begin
   Ada.Text_IO.Put_Line ("synapse-bard" & First_Byte'Image);
end Synapse_Bard_Main;
