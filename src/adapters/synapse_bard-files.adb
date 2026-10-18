with Ada.Directories;
with Ada.IO_Exceptions;

with GNAT.OS_Lib;

with Synapse.Adapters.File_Bytes;

package body Synapse_Bard.Files is

   use type Ada.Directories.File_Kind;

   function Is_Kind
     (Path : String; Kind : Ada.Directories.File_Kind) return Boolean is
   begin
      return Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Kind;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         return False;
   end Is_Kind;

   function Is_Directory (Path : String) return Boolean is
     (Is_Kind (Path, Ada.Directories.Directory));

   function Is_File (Path : String) return Boolean is
     (Is_Kind (Path, Ada.Directories.Ordinary_File));

   procedure Read
     (Path   : String; Limit : Positive;
      Text   : out Ada.Strings.Unbounded.Unbounded_String;
      Status : out Read_Status) is
   begin
      Text := Ada.Strings.Unbounded.Null_Unbounded_String;
      Text :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Synapse.Adapters.File_Bytes.Read (Path, Limit));
      Status := Read_Ok;
   exception
      when Synapse.Adapters.File_Bytes.Too_Large =>
         Status := Too_Large;
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         Status := Unreadable;
   end Read;

   function Read_Text
     (Path : String; Limit : Positive) return Synapse.Core.Optional_Text.Option
   is
      Text   : Ada.Strings.Unbounded.Unbounded_String;
      Status : Read_Status;
   begin
      Read (Path, Limit, Text, Status);
      if Status = Read_Ok then
         return Synapse.Core.Optional_Text.Of_Value (Text);
      end if;
      return Synapse.Core.Optional_Text.None;
   end Read_Text;

   function Has_Link_Below (Base, Item : String) return Boolean is
      Start : Positive := Item'First;
   begin
      for I in Item'Range loop
         if Item (I) = '/' then
            if GNAT.OS_Lib.Is_Symbolic_Link
                 (Base & "/" & Item (Item'First .. I - 1))
            then
               return True;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return Start <= Item'Last
        and then GNAT.OS_Lib.Is_Symbolic_Link (Base & "/" & Item);
   end Has_Link_Below;

end Synapse_Bard.Files;
