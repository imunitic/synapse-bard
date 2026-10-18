with Ada.Strings.Unbounded;

with Synapse.Core.Optional_Text;

--  The few questions about the file system that the manuscript, the templates
--  and the hooks all ask, answered without raising.

package Synapse_Bard.Files is

   --  Whether Path exists and is a folder (File: a regular file). A path that
   --  cannot be examined is neither.
   function Is_Directory (Path : String) return Boolean;
   function Is_File (Path : String) return Boolean;

   type Read_Status is (Read_Ok, Too_Large, Unreadable);

   --  The bytes of the file at Path when it is at most Limit bytes long. Text
   --  is empty unless Status is Read_Ok.
   procedure Read
     (Path   : String; Limit : Positive;
      Text   : out Ada.Strings.Unbounded.Unbounded_String;
      Status : out Read_Status);

   --  The same, as the text of the file: none when it cannot be read or is
   --  over Limit bytes.
   function Read_Text
     (Path : String; Limit : Positive) return Synapse.Core.Optional_Text.Option;

   --  Whether a part of Item, a path relative to the folder Base, is a
   --  symbolic link. Base itself is not examined.
   function Has_Link_Below (Base, Item : String) return Boolean;

end Synapse_Bard.Files;
