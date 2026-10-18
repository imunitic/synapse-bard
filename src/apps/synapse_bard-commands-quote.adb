with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Manuscript;

package body Synapse_Bard.Commands.Quote is

   use Support;

   package Books renames Synapse_Bard.Manuscript;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
      Early : constant Exit_Options.Option :=
        Check_Usage (Env, Usage.Quote_Usage, Args, 5);
   begin
      if Early.Found then
         return Early.Value;
      end if;
      declare
         Number : constant String := Arg (Args, 4);
      begin
         if Number'Length = 0 or else Number'Length > 9
           or else (for some C of Number => C not in '0' .. '9')
         then
            Err_Text
              (Env,
               "synapse-bard quote: '" & Number & "' is not a line number"
               & LF & Usage.Quote_Usage);
            return 2;
         end if;
         if Natural'Value (Number) = 0 then
            Err_Text
              (Env,
               "synapse-bard quote: lines are numbered from 1" & LF);
            return 2;
         end if;
         declare
            Loaded : constant Books.Loaded.Result :=
              Load_Manuscript (Env, "quote", Arg (Args, 1));
         begin
            if not Books.Loaded.Is_Success (Loaded) then
               return 1;
            end if;
            if Books.Holds_Quote
                 (Books.Loaded.Value (Loaded), Arg (Args, 2), Arg (Args, 3),
                  Natural'Value (Number), Arg (Args, 5))
            then
               return 0;
            end if;
            Err_Text
              (Env,
               "synapse-bard quote: not found on line " & Number
               & " of chapter '" & Arg (Args, 3) & "' of book '"
               & Arg (Args, 2) & "'" & LF);
            return 1;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Quote;
