// This is a roxen module. Copyright � 1996 - 1998, Idonex AB.
//
// Adds support for inline pike in documents.
//
// Example:
// <pike>
//  return "Hello world!\n";
// </pike>
 
constant cvs_version = "$Id: piketag.pike,v 2.1 1999/11/27 07:49:40 per Exp $";
constant thread_safe=1;

inherit "roxenlib";
inherit "module";
#include <module.h>;

constant module_type = MODULE_PARSER;
constant module_name = "Pike tag";
constant module_doc = 
#"This module adds a new tag, &lt;pike&gt;&lt;/pike&gt;. It makes it
possible to insert some pike code directly in the document.  <br><img
src=/image/err_2.gif align=left alt=\"\"> <br>NOTE: Enabling this
module is the same thing as letting your users run programs with the
same right as the server!  Example:<p><pre> &lt;pike&gt; return
\"Hello world!\\n\"; &lt;/pike&gt;\n</pre> <p>Arguments: Any, all
arguments are passed to the script in the mapping args. There are also
a few helper functions available, output(string fmt, mixed ... args)
is a fast way to add new data to a dynamic buffer, flush() returns the
contents of the buffer as a string.  A flush() is done automatically
if the script does not return any data, thus, another way to write the
hello world script is <tt>&lt;pike&gt;output(\"Hello %s\n\",
\"World\");&lt/pike&gt</tt><p> The request id is available as id.";

void create()
{
  defvar (
    "debugmode", "Log", "Error messages", TYPE_STRING_LIST | VAR_MORE,
    "How to report errors (e.g. backtraces generated by the Pike code):\n"
    "\n"
    "<p><ul>\n"
    "<li><i>Off</i> - Silent.\n"
    "<li><i>Log</i> - System debug log.\n"
    "<li><i>HTML comment</i> - Include in the generated page as an HTML comment.\n"
    "<li><i>HTML text</i> - Include in the generated page as normal text.\n"
    "</ul>\n",
    ({"Off", "Log", "HTML comment", "HTML text"}));

  defvar("program_cache_limit", 256, "Program cache limit", TYPE_INT|VAR_MORE,
	 "Maximum size of the cache for compiled programs.");
}

string reporterr (string header, string dump)
{
  if (QUERY (debugmode) == "Off") return "";

  report_error( header + dump + "\n" );
  switch (QUERY (debugmode)) 
  {
    case "HTML comment":
      return "\n<!-- " + html_encode_string(header + dump) + "\n-->\n";
    case "HTML text":
      return "\n<br><font color=red><b><pre>" + html_encode_string (header) +
	"</b></pre></font><pre>\n"+html_encode_string (dump) + "</pre><br>\n";
    default:
      return "";
  }
}

// Helper functions, to be used in the pike script.
class Helpers
{
  string data = "";
  void output(mixed ... args) 
  {
    if(!sizeof(args)) 
      return;
    if(sizeof(args) > 1) 
      data += sprintf(@args);
    else 
      data += args[0];
  }

  string flush() 
  {
    string r = data;
    data ="";
    return r;
  }

  constant seteuid=0;
  constant setegid=0;
  constant setuid=0;
  constant setgid=0;
  constant call_out=0;
  constant all_constants=0;
  constant Privs=0;
}

string functions(string page, int line)
{
  add_constant( "__magic_helpers", Helpers );
  return 
    "inherit __magic_helpers;\n"
    "#"+line+" \""+replace(page,"\"","\\\"")+"\"\n";
}

// Preamble
string pre(string what, object id)
{
  if(search(what, "parse(") != -1)
    return functions(id->not_query, id->misc->line);
  if(search(what, "return") != -1)
    return functions(id->not_query, id->misc->line) + 
    "string|int parse(RequestID id, mapping defines, object file, mapping args) { ";
  else
    return functions(id->not_query, id->misc->line) +
    "string|int parse(RequestID id, mapping defines, object file, mapping args) { return ";
}

// Will be added at the end...
string post(string what) 
{
  if(search(what, "parse(") != -1)
    return "";
  if (!strlen(what) || what[-1] != ';')
    return ";}";
  else
    return "}";
}

private static mapping(string:program) program_cache = ([]);

// Compile and run the contents of the tag (in s) as a pike
// program. 
string container_pike(string tag, mapping m, string s, RequestID request_id,
                      object file, mapping defs)
{
  program p;
  object o;
  string res;
  mixed err;
  if(m->help) return register_module()[2];

  request_id->misc->cacheable=0;

  object e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  if(err=catch 
  {
    s = pre(s,request_id)+s+post(s);
    p = program_cache[s];

    if (!p) 
    {
      // Not in the program cache.
      p = compile_string(s, "Pike-tag("+request_id->not_query+":"+
                         request_id->misc->line+")");
      if (sizeof(program_cache) > QUERY(program_cache_limit)) 
      {
	array a = indices(program_cache);
	int i;

	// Zap somewhere between 25 & 50% of the cache.
	for(i = QUERY(program_cache_limit)/2; i > 0; i--)
	  m_delete(program_cache, a[random(sizeof(a))]);
      }
      program_cache[s] = p;
    }
  })
  {
    master()->set_inhibit_compile_errors(0);
    return reporterr(sprintf("Error compiling <pike> tag in %s:\n"
			     "%s\n\n", request_id->not_query, s),
                     e->get());
  }
  master()->set_inhibit_compile_errors(0);
  
  if(err = catch{
    res = (o=p())->parse(request_id, defs, file, m);
  })
  {
    return (res || "") + (o && o->flush() || "") +
      reporterr ("Error in <pike> tag in " + request_id->not_query + ":\n",
		 (describe_backtrace (err) / "\n")[0..1] * "\n");
  }

  res = (res || "") + (o && o->flush() || "");

  if(o) 
    destruct(o);

  return res;
}
