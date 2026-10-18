with Synapse.Core.Text_Lists;

package Synapse_Bard.Lines is

   --  The lines of Text without their line feed or carriage return. A final
   --  line feed does not start another line.
   function Split (Text : String) return Synapse.Core.Text_Lists.Vector;

end Synapse_Bard.Lines;
