with Ada.Strings.Fixed;

with Synapse.Core.Hashing;
with Synapse.Core.UTF8;

package body Synapse_Bard.Grounding is

   use Ada.Strings.Unbounded;

   LF  : constant Character := Character'Val (10);
   TAB : constant Character := Character'Val (9);

   function Image_Of (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   ---------------------------------------------------------------------------
   --  Roster file
   ---------------------------------------------------------------------------

   function Parse_Roster (Text : String) return Parsed.Result is
      Result : Roster;
      Number : Natural := 0;
      Start  : Positive := Text'First;

      --  Reads one line, Start .. Stop, into the roster or says why not.
      function Add_Line (Line : String) return String is
         Columns : Synapse.Core.Text_Lists.Vector;
         From    : Positive := Line'First;
         Item    : Entity;
      begin
         for I in Line'First .. Line'Last + 1 loop
            if I > Line'Last or else Line (I) = TAB then
               Columns.Append (To_Unbounded_String (Line (From .. I - 1)));
               From := I + 1;
            end if;
         end loop;
         if Natural (Columns.Length) < 2 then
            return "needs a name and a kind";
         end if;
         for Column of Columns loop
            if To_String (Column)'Length = 0 then
               return "has an empty column";
            end if;
         end loop;
         Item.Name := Columns (1);
         Item.Kind := Columns (2);
         for I in 3 .. Natural (Columns.Length) loop
            Item.Aliases.Append (Columns (I));
         end loop;
         for Earlier of Result loop
            if Earlier.Name = Item.Name then
               return "repeats the name '" & To_String (Item.Name) & "'";
            end if;
         end loop;
         Result.Append (Item);
         return "";
      end Add_Line;
   begin
      for I in Text'First .. Text'Last + 1 loop
         if I > Text'Last or else Text (I) = LF then
            Number := Number + 1;
            declare
               Stop : constant Natural :=
                 (if I > Start and then Text (I - 1) = Character'Val (13)
                  then I - 2
                  else I - 1);
               Line : constant String := Text (Start .. Stop);
            begin
               if Line'Length > 0 then
                  declare
                     Why : constant String := Add_Line (Line);
                  begin
                     if Why /= "" then
                        return Parsed.Failure
                          (To_Unbounded_String
                             ("roster line " & Image_Of (Number) & ": "
                              & Why));
                     end if;
                  end;
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;
      return Parsed.Success (Result);
   end Parse_Roster;

   ---------------------------------------------------------------------------
   --  Whole-word matching
   ---------------------------------------------------------------------------

   --  Whether a code point is part of a word. Letters of every script are;
   --  the punctuation and symbols below are not. Bytes that are not UTF-8 are
   --  treated as letters.
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

   function Word_At (Line : String; Pos : Positive) return Boolean is
      Code  : Natural;
      Width : Positive;
   begin
      Synapse.Core.UTF8.Decode_Lenient (Line, Pos, Code, Width);
      return Is_Word (Code);
   end Word_At;

   --  Whether Term, at Line (First .. Last), is a whole word there.
   function Is_Whole_Word
     (Line : String; First, Last : Positive) return Boolean is
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

   function Holds (Line, Term : String) return Boolean is
      From : Positive := Line'First;
      Found : Natural;
   begin
      loop
         exit when Term'Length = 0 or else From > Line'Last;
         Found := Ada.Strings.Fixed.Index (Line, Term, From);
         exit when Found = 0;
         if Is_Whole_Word (Line, Found, Found + Term'Length - 1) then
            return True;
         end if;
         From := Found + 1;
      end loop;
      return False;
   end Holds;

   ---------------------------------------------------------------------------
   --  Grounding
   ---------------------------------------------------------------------------

   type Pair is record
      Term   : Unbounded_String;
      Entity : Unbounded_String;
   end record;

   function "<" (Left, Right : Pair) return Boolean is
     (Left.Term < Right.Term
      or else (Left.Term = Right.Term and then Left.Entity < Right.Entity));

   package Pair_Vectors is new Ada.Containers.Vectors (Positive, Pair);
   package Pair_Sorting is new Pair_Vectors.Generic_Sorting;

   function Ground
     (Books : Manuscript.Series; Entities : Roster)
      return Reference_Vectors.Vector
   is
      Pairs  : Pair_Vectors.Vector;
      Result : Reference_Vectors.Vector;
   begin
      for Item of Entities loop
         Pairs.Append (Pair'(Term => Item.Name, Entity => Item.Name));
         for Alias of Item.Aliases loop
            Pairs.Append (Pair'(Term => Alias, Entity => Item.Name));
         end loop;
      end loop;
      Pair_Sorting.Sort (Pairs);

      declare
         Wanted : Pair_Vectors.Vector;
      begin
         for P of Pairs loop
            if Wanted.Is_Empty or else Wanted.Last_Element /= P then
               Wanted.Append (P);
            end if;
         end loop;

         for P of Wanted loop
            for B of Books loop
               for C of B.Chapters loop
                  declare
                     Lines : constant Synapse.Core.Text_Lists.Vector :=
                       Manuscript.Chapter_Lines (C);
                  begin
                     for N in 1 .. Natural (Lines.Length) loop
                        declare
                           Text : constant String := To_String (Lines (N));
                        begin
                           if Holds (Text, To_String (P.Term)) then
                              Result.Append
                                (Reference'
                                   (Term    => P.Term,
                                    Entity  => P.Entity,
                                    Book    => B.Title,
                                    Chapter => C.Name,
                                    File    => C.File,
                                    Line    => C.First + N - 1,
                                    Digest  =>
                                      To_Unbounded_String
                                        (Synapse.Core.Hashing.Sha256_Hex
                                           (Text))));
                           end if;
                        end;
                     end loop;
                  end;
               end loop;
            end loop;
         end loop;
      end;
      return Result;
   end Ground;

   --  A name or title as one column: tabs and line breaks become spaces.
   function Column (Item : Unbounded_String) return String is
      Text : String := To_String (Item);
   begin
      for C of Text loop
         if C in TAB | LF | Character'Val (13) then
            C := ' ';
         end if;
      end loop;
      return Text;
   end Column;

   function Image (References : Reference_Vectors.Vector) return String is
      Result : Unbounded_String;
   begin
      for R of References loop
         Append
           (Result,
            Column (R.Term) & TAB & Column (R.Entity) & TAB & Column (R.Book)
            & TAB & Column (R.Chapter) & TAB & Column (R.File) & TAB
            & Image_Of (R.Line) & TAB & To_String (R.Digest) & LF);
      end loop;
      return To_String (Result);
   end Image;

end Synapse_Bard.Grounding;
