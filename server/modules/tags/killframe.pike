/* This is a roxen module. (c) Informationsvävarna AB 1997.
 *
 * Adds some java script that will prevent others from putting
 * your page in a frame.
 * 
 * Will also remove occuranses of "index.html" at the end of the URL.
 * 
 * made by Peter Bortas <peter@infovav.se> Januari -97
 *
 * Thanks to 
 */

constant cvs_version = "$Id: killframe.pike,v 1.11 1997/11/14 01:00:02 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

void create() { }

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Killframe tag",
      ("Makes pages frameproof."
       "<br>This module defines a tag,"
       "<pre>"
       "&lt;killframe&gt;: Adds some java script that will prevent others\n"
       "             from putting your page in a frame.\n\n"
       /*       "             Will also strip any occurences of the string\n"
		"             'index.html' from the end of the URL." */
       "</pre>"
       ), ({}), 1,
    });
}

string newstyle_tag_killframe( string tag, mapping m, object id )
{
  /* Links to index.html are ugly. */
  string my_url = id->conf->query("MyWorldLocation") + id->raw_url[1..];
  int l=strlen(my_url);

  if( my_url[l-11..] == "/index.html" )
    my_url = my_url[..l-11];
  
  if (id->supports->javascript)
    return("<script language=javascript>\n"
	   "<!--\n"
	   //	   "   if (self != top) top.location = self.location\n"
	   "   if (\""+ my_url +"\" != top.location) top.location = \""
	   + my_url +"\"\n"
	   "//-->"
	   "</script>\n");
  return "";  
}

/* I liked this better, but it caused securityexceptions on newer browsers */
string tag_killframe( string tag, mapping m, object id )
{
  /* Links to index.html are ugly. */
  string my_url = id->conf->query("MyWorldLocation") + id->raw_url[1..];
  int l=strlen(my_url);

  if( my_url[l-11..] == "/index.html" )
    my_url = my_url[..l-11];
  
  if (id->supports->javascript)
    return("<script language=javascript>\n"
	   "<!--\n"
	   "   if(top.location != \""+ my_url  +"\")\n"
	   "     top.location = \""+ my_url  +"\";\n"
	   "//-->"
	   "</script>\n");
  return "";
}

mapping query_tag_callers()
{
  return ([ "killframe" : tag_killframe ]);
}
