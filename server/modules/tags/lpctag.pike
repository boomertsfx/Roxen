// This is a roxen module. (c) Informationsvävarna AB 1996.
//
// Adds support for inline pike in documents.
//
// Example:
// <pike>
//  return "Hello world!\n";
// </pike>
 
inherit "module";
string cvs_version = "$Id: lpctag.pike,v 1.3 1996/11/27 13:48:18 per Exp $";
#include <module.h>;

array register_module()
{
  return ({ MODULE_PARSER,
	    "Pike tag", 
	    "This module adds a new tag, <pike></pike>. It makes it possible."
	    " to insert some pike code directly in the document.",
	    ({}), 1 });
}


// Helper functions, to be used in the pike script.
// output(string fmt, mixed ... args) is a fast way to add new
// data to a dynamic buffer, flush() returns the contents of the
// buffer as a string.  A flush() is done automatically if the
// "script" does not return any data, thus, another way to write the
// hello world script is <pike>output("Hello %s\n", "World");</pike>
inline private nomask string functions()
{
  return 
    "inherit \"roxenlib\";\n"
    "\n"
    "object parser = roxen->current_configuration->parse_module;\n"
    "int __accessed(string file, int|void add) {\n"
    "  return parser->query_num(file, add);\n"
    "}\n\n"
    "array data = ({});\n\n"
    "void output(mixed ... args) {\n"
    "if(sizeof(args) > 1) data += ({ sprintf(@args) }); else data += args;\n"
    "}\n\n"
    "string flush() {\n"
    "  string r;\n"
    "  r=data*\"\";\n"
    "  data = ({});\n"
    "  return r;\n"
    "}\n"
    "#0 \"piketag\"\n"
    ;
    
}

// Preamble
private nomask inline string pre(string what)
{
  if(search(what, "parse(") != -1)
    return functions();
  if(search(what, "return") != -1)
    return functions() + 
    "string parse(object id, mapping defines, object file, mapping args) { ";
  else
    return functions() +
    "string parse(object id, mapping defines, object file, mapping args) { return ";
}

// Will be added at the end...
private nomask inline string post(string what) 
{
  if (what[-1] != ";")
    return ";}";
  else
    return "}";
}

// Compile and run the contents of the tag (in s) as a pike
// program. 
string tag_pike(string tag, mapping m, string s, object request_id,
		object file, mapping defs)
{
  program p;
  object o;
  string tmp;
  string res;
  mixed err;
string cvs_version = "$Id: lpctag.pike,v 1.3 1996/11/27 13:48:18 per Exp $";
#if efun(set_max_eval_time)
  if(err = catch {
    set_max_eval_time(2);
string cvs_version = "$Id: lpctag.pike,v 1.3 1996/11/27 13:48:18 per Exp $";
#endif
    _master->set_inhibit_compile_errors(1);
    if(err=catch {
      s=pre(s)+s+post(s);
      p = compile_string(s, "Pike-tag");
    })
    {
      perror(err[0]-"\n"+" while compiling "+request_id->not_query+"\n");
      res = "<h1><font color=red size=7><i>"+err[0]+"</i></font></h1>";
    }

    if(strlen(tmp=_master->errors)) 
    {
      _master->set_inhibit_compile_errors(0);
      res=("<pre>"+tmp+"</pre>"+
	   "<pre>"+s+"</pre>");
    }
    _master->set_inhibit_compile_errors(0);
    if(err = catch{
      res = (o=p())->parse(request_id, defs, file, m);
    })
    {
      perror(err[0]-"\n"+" in "+request_id->not_query+"\n");
      res = (o->flush()||"")+"<h1><font color=red size=7><i>"+err[0]+"</i></font></h1>";
    }
string cvs_version = "$Id: lpctag.pike,v 1.3 1996/11/27 13:48:18 per Exp $";
#if efun(set_max_eval_time)
    remove_max_eval_time(); // Remove the limit.
  })
  {
    perror(err[0]+" for "+request_id->not_query+"\n");
    if(!res)
      res = (o->flush()||"")+"<h1><font color=darkred size=7><i>"+err[0]+"</i></font></h1>";
    else
      res += "<h1>"+err[0]+"</h1>";
    remove_max_eval_time(); // Remove the limit.
  }
string cvs_version = "$Id: lpctag.pike,v 1.3 1996/11/27 13:48:18 per Exp $";
#endif
  if(o) destruct(o);

  if(!stringp(res))
    res="";

  return res;
}



mapping query_tag_callers() { return ([]); }

mapping query_container_callers()
{
  return ([ "lpc":tag_pike,  "pike":tag_pike, "ulpc":tag_pike, ]);
}
