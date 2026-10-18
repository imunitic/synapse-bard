with Synapse.Core.UTF8;

package body Synapse_Bard.Syntax with SPARK_Mode is

   function Trim (Item : String) return String is
      First : Integer := Item'First;
      Last  : Integer := Item'Last;
   begin
      while First <= Last and then Item (First) = ' ' loop
         pragma Loop_Invariant (First in Item'First .. Last);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      while Last >= First and then Item (Last) = ' ' loop
         pragma Loop_Invariant (Last in First - 1 .. Item'Last);
         pragma Loop_Variant (Decreases => Last);
         Last := Last - 1;
      end loop;
      return Item (First .. Last);
   end Trim;

   --  Whether Item (First .. Last) is `.` or `..`.
   function Is_Dot_Part (Item : String; First, Last : Integer) return Boolean
   with Pre => First >= Item'First and then Last <= Item'Last
   is
   begin
      return First <= Last and then Last - First <= 1
        and then (for all I in First .. Last => Item (I) = '.');
   end Is_Dot_Part;

   function Stays_Inside (Item : String) return Boolean is
   begin
      if Item'Length = 0 or else Item (Item'First) = '/' then
         return False;
      end if;
      declare
         Start : Integer := Item'First;
      begin
         for I in Item'Range loop
            pragma Loop_Invariant (Start in Item'First .. I);
            if Item (I) = '/' then
               if Is_Dot_Part (Item, Start, I - 1) then
                  return False;
               end if;
               Start := I + 1;
            end if;
         end loop;
         return not Is_Dot_Part (Item, Start, Item'Last);
      end;
   end Stays_Inside;

   function Is_Heading (Line : String; Level : Positive) return Boolean is
   begin
      if Line'Length <= Level then
         return False;
      end if;
      for I in Line'First .. Line'First + Level - 1 loop
         if Line (I) /= '#' then
            return False;
         end if;
      end loop;
      return Line (Line'First + Level) = ' ';
   end Is_Heading;

   function Heading_Text (Line : String; Level : Positive) return String is
   begin
      if Is_Heading (Line, Level) then
         return Trim (Line (Line'First + Level + 1 .. Line'Last));
      end if;
      return "";
   end Heading_Text;

   function Item_Start (Line : String) return Natural is
      Digits_End : Integer := Line'First - 1;
   begin
      while Digits_End < Line'Last
        and then Line (Digits_End + 1) in '0' .. '9'
      loop
         pragma Loop_Invariant (Digits_End in Line'First - 1 .. Line'Last);
         pragma Loop_Variant (Increases => Digits_End);
         Digits_End := Digits_End + 1;
      end loop;
      if Digits_End = Line'First - 1
        or else Digits_End + 2 > Line'Last
        or else Line (Digits_End + 1) not in '.' | ')'
        or else Line (Digits_End + 2) /= ' '
      then
         return 0;
      end if;
      return Digits_End + 3;
   end Item_Start;

   function Unslugify (Name : String) return String is
      Last : constant Integer :=
        (if Name'Length >= 3 and then Name (Name'Last - 2 .. Name'Last) = ".md"
         then Name'Last - 3
         else Name'Last);
      Result : String := Name (Name'First .. Last);
      Has_Separator : Boolean := False;
      Has_Space     : Boolean := False;
   begin
      for I in Result'Range loop
         if Result (I) in '_' | '-' then
            Has_Separator := True;
         elsif Result (I) = ' ' then
            Has_Space := True;
         end if;
      end loop;
      if not Has_Separator or else Has_Space then
         return Result;
      end if;
      for I in Result'Range loop
         if Result (I) in '_' | '-' then
            Result (I) := ' ';
         end if;
      end loop;
      if Result'Length > 0 and then Result (Result'First) in 'a' .. 'z' then
         Result (Result'First) :=
           Character'Val
             (Character'Pos (Result (Result'First))
              - Character'Pos ('a') + Character'Pos ('A'));
      end if;
      return Result;
   end Unslugify;

   function Is_Word (Code : Natural) return Boolean is
   begin
      if Code < 16#80# then
         return Code in Character'Pos ('0') .. Character'Pos ('9')
           | Character'Pos ('A') .. Character'Pos ('Z')
           | Character'Pos ('a') .. Character'Pos ('z')
           | Character'Pos ('_');
      elsif Code in 16#A0# .. 16#BF# then
         return Code in 16#AA# | 16#B5# | 16#BA#;
      elsif Code in 16#D7# | 16#F7# then
         return False;
      end if;
      return Code not in
        16#2000# .. 16#206F# | 16#2E00# .. 16#2E7F# | 16#3000# .. 16#303F#
        | 16#FE50# .. 16#FE6F# | 16#FF01# .. 16#FF0F# | 16#FF1A# .. 16#FF20#;
   end Is_Word;

   --  Whether the atom of Line at Pos is part of a word. Bytes that are not
   --  UTF-8 count as letters.
   function Word_At (Line : String; Pos : Positive) return Boolean with
     Pre => Line'Last < Positive'Last and then Pos in Line'Range
   is
      Code  : Natural;
      Width : Positive;
   begin
      pragma Warnings
        (GNATprove, Off, """Width"" is set by*",
         Reason => "only the code point is needed");
      Synapse.Core.UTF8.Decode_Lenient (Line, Pos, Code, Width);
      pragma Warnings (GNATprove, On, """Width"" is set by*");
      return Is_Word (Code);
   end Word_At;

   --  Whether Line (First .. Last) is bounded by something that is not part of
   --  a word on both sides.
   function Is_Whole_Word
     (Line : String; First, Last : Positive) return Boolean
   with
     Pre => Line'Last < Positive'Last and then First in Line'Range
            and then Last in First .. Line'Last
   is
   begin
      if First > Line'First
        and then Word_At
          (Line,
           Synapse.Core.UTF8.Previous_Start (Line, Line'First, First))
      then
         return False;
      end if;
      return Last = Line'Last or else not Word_At (Line, Last + 1);
   end Is_Whole_Word;

   function Holds_Word (Line, Term : String) return Boolean is
   begin
      if Term'Length = 0 or else Term'Length > Line'Length then
         return False;
      end if;
      for From in Line'First .. Line'Last - Term'Length + 1 loop
         if Line (From .. From + Term'Length - 1) = Term
           and then Is_Whole_Word (Line, From, From + Term'Length - 1)
         then
            return True;
         end if;
      end loop;
      return False;
   end Holds_Word;

end Synapse_Bard.Syntax;
