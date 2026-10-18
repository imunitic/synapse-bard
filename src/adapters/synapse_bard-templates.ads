with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Results;

--  The template set an operation reads: the entity kinds that exist and the
--  file that defines each. A template is a `{kind}_template.md` file, and the
--  set is the bible's own `_templates/`.
--
--  A bible with none can be given the default set the package ships under
--  `templates/` in its content root, as a copy it then owns.

package Synapse_Bard.Templates is

   Suffix : constant String := "_template.md";

   type Template is record
      Kind : Ada.Strings.Unbounded.Unbounded_String;
      Path : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Template_Vectors is new Ada.Containers.Vectors (Positive, Template);

   package Resolved is new
     Synapse.Core.Results
       (Template_Vectors.Vector, Ada.Strings.Unbounded.Unbounded_String);

   --  The templates of the bible's `_templates/`, ordered by kind, or why
   --  there is none.
   function Resolve (Repo_Root : String) return Resolved.Result;

   package Installed is new
     Synapse.Core.Results
       (Template_Vectors.Vector, Ada.Strings.Unbounded.Unbounded_String);

   --  Copies the default set under Content_Root into the bible's
   --  `_templates/` and returns the copies. Refused when the bible already has
   --  a template, so an existing file is never overwritten, and when the
   --  package ships no default set. Content_Root is empty when there is none.
   function Install (Repo_Root, Content_Root : String) return Installed.Result;

end Synapse_Bard.Templates;
