with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse.Adapters.File_Bytes;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Hooks.Output;
with Synapse_Bard.Hooks.Payload;
with Synapse_Bard.Hooks.Session_Start;

package body Synapse_Bard.Hooks.Stop_Nudge is

   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   procedure Complain (Env : Environment; Text : String) is
   begin
      Env.Console.Write_Err ("synapse-bard-hook: " & Text & LF);
   end Complain;

   function Is_Digits (Text : String) return Boolean is
     (Text'Length > 0 and then (for all C of Text => C in '0' .. '9'));

   --  Text without the blanks, tabs and line ends around it.
   function Trimmed (Text : String) return String is
      First : Natural := Text'First;
      Last  : Integer := Text'Last;
   begin
      while First <= Last
        and then Text (First) in ' ' | Character'Val (9) | LF | Character'Val (13)
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then Text (Last) in ' ' | Character'Val (9) | LF | Character'Val (13)
      loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trimmed;

   --  The count in a counter file: 0 for a missing file, and 0 with a message
   --  for one that cannot be read or does not hold a number.
   function Read_Count (Env : Environment; Path : String) return Natural is
   begin
      declare
         Clean : constant String :=
           Trimmed (Synapse.Adapters.File_Bytes.Read (Path, 64));
      begin
         if Is_Digits (Clean) and then Clean'Length <= 9 then
            return Natural'Value (Clean);
         end if;
         Complain
           (Env,
            "corrupt stop-nudge counter, restarting from 0 (" & Path & ")");
         return 0;
      end;
   exception
      when Ada.IO_Exceptions.Name_Error =>
         return 0;  --  the ordinary first run
      when Synapse.Adapters.File_Bytes.Too_Large
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         Complain
           (Env,
            "unreadable stop-nudge counter, restarting from 0 (" & Path & ")");
         return 0;
   end Read_Count;

   procedure Write_Count (Env : Environment; Path : String; Value : Natural) is
   begin
      Synapse.Adapters.File_Bytes.Write (Path, Image (Value) & LF);
   exception
      when others =>
         Complain
           (Env,
            "could not write the stop-nudge counter, it may not fire on "
            & "schedule (" & Path & ")");
   end Write_Count;

   function Advance
     (Env : Environment; Home, Session : String) return Tick
   is
      State_Dir  : constant String := Home & "/.claude/state";
      Total_Path : constant String :=
        State_Dir & "/synapse-bard-stop-nudge-total-" & Session;
      Since_Path : constant String :=
        State_Dir & "/synapse-bard-stop-nudge-since-" & Session;
   begin
      begin
         Ada.Directories.Create_Path (State_Dir);
      exception
         when others =>
            null;
      end;
      declare
         Total : constant Natural := Read_Count (Env, Total_Path) + 1;
         Since : constant Natural := Read_Count (Env, Since_Path) + 1;
      begin
         Write_Count (Env, Total_Path, Total);
         if Since >= Interval then
            Write_Count (Env, Since_Path, 0);
            return
              (Text  =>
                 Synapse.Core.Optional_Text.Of_Value
                   (To_Unbounded_String
                      ("This session has grown substantial (" & Image (Total)
                       & " turns, re-armed at the " & Image (Interval)
                       & "-turn mark). Before continuing: did this session "
                       & "settle a plot/worldbuilding/continuity decision, "
                       & "surface research worth keeping, or reach a "
                       & "milestone worth persisting to the Writer's notes "
                       & "vault (_bard/vault/)? If so, write it up now (see """
                       & Vault_Note_Heading & """ in synapse-bard-claude.md, "
                       & "or use /synapse-bard-note) while full context is "
                       & "still available -- do not wait for a wrap-up step. "
                       & "If you already wrote or updated a note earlier this "
                       & "session, check whether anything since then is "
                       & "worth folding in too.")),
               Total => Total);
         end if;
         Write_Count (Env, Since_Path, Since);
         return (Text => Synapse.Core.Optional_Text.None, Total => Total);
      end;
   end Advance;

   procedure Run (Env : Environment) is
      Home : constant Session_Start.Maybe_Text := Env.Vars.Get ("HOME");
   begin
      if not Home.Found then
         return;
      end if;
      declare
         Input   : constant Payload.Payload := Payload.Read (Env);
         Cwd     : constant Payload.Maybe_Text := Payload.Str (Input, "cwd");
         Session : constant Payload.Maybe_Text :=
           Payload.Str (Input, "session_id");
         Found   : constant Commands.Roots.Roots_Options.Option :=
           Commands.Roots.Resolve
             (Session_Start.Absolute
                (To_String (Env.Start),
                 (if Cwd.Found then To_String (Cwd.Value) else ".")));
      begin
         if not Found.Found
           or else not Session_Start.Bard_Enabled (To_String (Found.Value.Repo))
         then
            return;
         end if;
         declare
            Result : constant Tick :=
              Advance
                (Env, To_String (Home.Value),
                 (if Session.Found then To_String (Session.Value)
                  else "default"));
         begin
            if Result.Text.Found then
               Hooks.Output.Emit_Context
                 (Env, "Stop", To_String (Result.Text.Value));
            end if;
         end;
      end;
   end Run;

end Synapse_Bard.Hooks.Stop_Nudge;
