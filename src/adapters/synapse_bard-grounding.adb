with Synapse.Core.Decimal_Image;
with Synapse.Core.Hashing;

with Synapse_Bard.Lines;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Grounding is

   use Ada.Strings.Unbounded;
   use Synapse.Core.Decimal_Image;
   use Synapse_Bard.Syntax;

   ---------------------------------------------------------------------------
   --  Roster file
   ---------------------------------------------------------------------------

   function Parse_Roster (Text : String) return Parsed.Result is
      Result : Roster;
      Rows   : constant Synapse.Core.Text_Lists.Vector :=
        Synapse_Bard.Lines.Split (Text);

      --  Reads one row into the roster or says why not.
      function Add_Row (Row : String) return String is
         Columns : Synapse.Core.Text_Lists.Vector;
         From    : Positive := Row'First;
         Item    : Entity;
      begin
         for I in Row'First .. Row'Last + 1 loop
            if I > Row'Last or else Row (I) = TAB then
               Columns.Append (To_Unbounded_String (Row (From .. I - 1)));
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
      end Add_Row;
   begin
      for Number in 1 .. Natural (Rows.Length) loop
         declare
            Row : constant String := To_String (Rows (Number));
         begin
            if Row'Length > 0 then
               declare
                  Why : constant String := Add_Row (Row);
               begin
                  if Why /= "" then
                     return Parsed.Failure
                       (To_Unbounded_String
                          ("roster line " & Image (Number) & ": " & Why));
                  end if;
               end;
            end if;
         end;
      end loop;
      return Parsed.Success (Result);
   end Parse_Roster;

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

   package Found_Vectors is new
     Ada.Containers.Vectors (Positive, Reference_Vectors.Vector,
                             Reference_Vectors."=");

   function Ground
     (Books : Manuscript.Series; Entities : Roster)
      return Reference_Vectors.Vector
   is
      Pairs  : Pair_Vectors.Vector;
      Wanted : Pair_Vectors.Vector;
      Result : Reference_Vectors.Vector;
   begin
      for Item of Entities loop
         Pairs.Append (Pair'(Term => Item.Name, Entity => Item.Name));
         for Alias of Item.Aliases loop
            Pairs.Append (Pair'(Term => Alias, Entity => Item.Name));
         end loop;
      end loop;
      Pair_Sorting.Sort (Pairs);
      for P of Pairs loop
         if Wanted.Is_Empty or else Wanted.Last_Element /= P then
            Wanted.Append (P);
         end if;
      end loop;

      declare
         --  What each wanted pair is found on, in reading order.
         Found : Found_Vectors.Vector :=
           Found_Vectors.To_Vector
             (Reference_Vectors.Empty_Vector, Wanted.Length);
      begin
         for B of Books loop
            for C of B.Chapters loop
               declare
                  Text : constant Synapse.Core.Text_Lists.Vector :=
                    Manuscript.Chapter_Lines (C);
               begin
                  for N in 1 .. Natural (Text.Length) loop
                     declare
                        Line   : constant String := To_String (Text (N));
                        Digest : Unbounded_String;
                     begin
                        for W in 1 .. Natural (Wanted.Length) loop
                           if Holds_Word (Line, To_String (Wanted (W).Term))
                           then
                              if Length (Digest) = 0 then
                                 Digest :=
                                   To_Unbounded_String
                                     (Synapse.Core.Hashing.Sha256_Hex (Line));
                              end if;
                              Found.Reference (W).Append
                                (Reference'
                                   (Term    => Wanted (W).Term,
                                    Entity  => Wanted (W).Entity,
                                    Book    => B.Title,
                                    Chapter => C.Name,
                                    File    => C.File,
                                    Line    => C.First + N - 1,
                                    Digest  => Digest));
                           end if;
                        end loop;
                     end;
                  end loop;
               end;
            end loop;
         end loop;
         for Per_Pair of Found loop
            Result.Append_Vector (Per_Pair);
         end loop;
      end;
      return Result;
   end Ground;

   --  A name or title as one column: tabs and line breaks become spaces.
   function Column (Item : Unbounded_String) return String is
      Text : String := To_String (Item);
   begin
      for C of Text loop
         if C in TAB | LF | CR then
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
            & Image (R.Line) & TAB & To_String (R.Digest) & LF);
      end loop;
      return To_String (Result);
   end Image;

end Synapse_Bard.Grounding;
