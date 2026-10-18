with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Manuscript;

package body Synapse_Bard.Commands.Quote is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Quote_Usage);
         return 2;
      end if;
      if Is_Help (Arg (Args, 1)) then
         Err_Text (Env, Usage.Quote_Usage);
         return 0;
      end if;
      if Count (Args) /= 5 then
         Err_Text (Env, Usage.Quote_Usage);
         return 2;
      end if;
      declare
         Number : constant String := Arg (Args, 4);
         Line   : Natural := 0;
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
         Line := Natural'Value (Number);
         if Line = 0 then
            Err_Text
              (Env,
               "synapse-bard quote: lines are numbered from 1" & LF);
            return 2;
         end if;
         declare
            Loaded : constant Synapse_Bard.Manuscript.Loaded.Result :=
              Synapse_Bard.Manuscript.Load (Resolve_Path (Env, Arg (Args, 1)));
         begin
            if not Synapse_Bard.Manuscript.Loaded.Is_Success (Loaded) then
               Err_Text
                 (Env,
                  "synapse-bard quote: "
                  & To_String (Synapse_Bard.Manuscript.Loaded.Error (Loaded))
                  & LF);
               return 1;
            end if;
            if Synapse_Bard.Manuscript.Holds_Quote
                 (Synapse_Bard.Manuscript.Loaded.Value (Loaded),
                  Arg (Args, 2), Arg (Args, 3), Line, Arg (Args, 5))
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
