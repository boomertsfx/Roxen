// This is a roxen module. Copyright � 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: html_wash.pike,v 1.8 2000/09/11 18:26:51 jhs Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "HTML washer";
constant module_doc  =
#"<p>This module provides a &lt;wash-html&gt; tag that is perhaps most
useful for turning user freetext input from a form into HTML
intelligently; perhaps turning sections separated by more than one
newline into &lt;p&gt;paragraphs&lt;/p&gt;, filtering out or
explicitly allowing some HTML tags in the input, or (HTML) quoting or
unquoting the data.</p>

<p>Usage example:</p>

<pre>&lt;form&gt;
 &lt;textarea name=input&gt;&amp;form.input;&lt;/textarea&gt;
 &lt;input type='submit'&gt;
&lt;form&gt;

&lt;wash-html link-dwim='yes'
 paragraphify='yes'&gt;&amp;form.input:none;&lt;/wash-html&gt;</pre>";
constant module_unique = 1;

class TagWashHtml
{
  inherit RXML.Tag;
  constant name = "wash-html";
  Regexp link_regexp;

  string paragraphify(string s)
  {
    // more than one newline is considered a new paragraph
    return
      "<p>"+
      ((replace(replace(s - "\r" - "\0", "\n\n", "\0"),
		"\0\n", "\0")/"\0") - ({ "\n", "" }))*"</p>\n<p>"
      +"</p>";
  }

  string unparagraphify(string s)
  {
    return replace(s,
		   ({ "</p>\n<p>", "</p><p>", "<p>", "</p>" }),
		   ({ "\n\n",      "\n\n",    "",    "" }) );
  }

  array parse_arg_array(string s)
  {
    if(!s)
      return ({ });

    return ((s - " ")/",") - ({ "" });
  }

  string safe_container(string tag, mapping m, string cont)
  {
    return replace(Roxen.make_tag(tag, m),
		   ({ "<",">" }), ({ "\0[","\0]" }) ) + cont+"\0[/"+tag+"\0]";
  }

  string safe_tag(string tag, mapping m, string close_tags)
  {
    if(close_tags)
      m["/"] = "/";

    return replace(Roxen.make_tag(tag, m), ({ "<",">" }), ({ "\0[","\0]" }) );
  }

  string filter_body(string s, array keep_tags, array keep_containers,
		     string close_tags)
  {
    s -= "\0";
    mapping allowed_tags =
      mkmapping(keep_tags, allocate(sizeof(keep_tags), safe_tag));

    mapping allowed_containers =
      mkmapping(keep_containers,
		allocate(sizeof(keep_containers), safe_container));

    return replace(
      parse_html(s, allowed_tags, allowed_containers, close_tags),
      ({ "<",    ">",    "&",     "\0[", "\0]" }),
      ({ "&lt;", "&gt;", "&amp;", "<",   ">" }));
  }

  string link_dwim(string s)
  {
    string fix_link(string l)
    {
      if(l[0..6] == "http://" || l[0..7] == "https://" || l[0..5] == "ftp://")
	return l;
      return "http://"+l;
    };

    Parser.HTML parser = Parser.HTML();

    parser->add_container("a", lambda(Parser.HTML p, mapping args)
			       { return ({ p->current() }); });
    parser->_set_data_callback(
      lambda(Parser.HTML p, string data)
      { return ({ link_regexp->
		  replace(data, lambda(string link)
				{
				  link = fix_link(link);
				  return "<a href='"+link+"'>"+
				    link+"</a>";
				}) }); });

    return parser->finish(s)->read();
  }

  string unlink_dwim(string s)
  {
    string tag_a(string tag, mapping arg, string cont)
    {
      if(sizeof(arg) == 1 && arg->href == cont)
	return cont;
    };

    return parse_html(s, ([ ]), ([ "a":tag_a ]) );
  }

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = content;

      if(args->unparagraphify)
	result = unparagraphify(result);

      if(args["unlink-dwim"])
	result = unlink_dwim(result);

      if(!args["keep-all"])
	result = filter_body(result,
			     parse_arg_array(args["keep-tags"]),
			     parse_arg_array(args["keep-containers"]),
			     args["close-tags"]);

      if(args->paragraphify)
	result = paragraphify(result);

      if(args["link-dwim"])
	result = link_dwim(result);

      if(args->quote)
	result = Roxen.html_encode_string(result);

      if(args->unquote)
	result = Roxen.html_decode_string(result);

      return 0;
    }
  }

  void create()
  {
    req_arg_types = ([ ]);
    opt_arg_types = ([ "keep-tags":RXML.t_text(RXML.PXml),
		       "keep-containers":RXML.t_text(RXML.PXml),
		       "quote":RXML.t_text(RXML.PXml),
		       "unquote":RXML.t_text(RXML.PXml),
		       "paragraphify":RXML.t_text(RXML.PXml),
                       "unparagraphify":RXML.t_text(RXML.PXml),
		       "keep-all":RXML.t_text(RXML.PXml) ]);

    link_regexp =
      Regexp("(((http)|(https)|(ftp))://([^ \t\n\r<]+)(\\.[^ \t\n\r<>\"]+)+)|"
	     "(((www)|(ftp))(\\.[^ \t\n\r<>\"]+)+)");
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"wash-html":#"<desc cont><short hide>

 </short>

</desc>

<attr name='keep-all' value=''>
 Keep all tags. Overrides the value of keep-tags and keep-containers.
</attr>

<attr name='keep-tags' value=''>
 Comma-separated array of empty element &lt;tags/&gt; not to filter out.
</attr>

<attr name='keep-containers' value=''>
 Comma-separated array of &lt;container&gt;...&lt/&gt; tags not to filter out.
</attr>

<attr name='link-dwim' value=''>
 Makes text that looks like a link, e g http://www.roxen.com/, into a link.
</attr>

<attr name='quote' value=''>
 After applying all transformations, HTML-quote the data.
</attr>

<attr name='unquote' value=''>
 After applying all other transformations, HTML-unquote the data.
</attr>

<attr name='paragraphify' value=''>

 If more than one newline exists between two text elements, this
 attribute automatically makes the next text element into a paragraph.

</attr>

<attr name='unparagraphify' value=''>
 Turn paragraph breaks into double newlines instead.
</attr>

<attr name='keep-all' value=''>
 Don't just keep the tags given by keep-tags and keep-containers, but
 rather leave all contained tags intact.
</attr>",

    ]);
#endif
