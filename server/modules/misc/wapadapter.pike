// This is a roxen module. Copyright � 2000, Roxen IS.
//

inherit "module";

constant thread_safe = 1;
constant cvs_version = "$Id: wapadapter.pike,v 1.6 2000/11/03 05:00:39 nilsson Exp $";

constant module_type = MODULE_FIRST|MODULE_FILTER|MODULE_TAG;
constant module_name = "WAP Adapter";
constant module_doc  = "Improves supports flags and variables as well as "
  "doing a better job finding MIME types than the content type module for WAP clients. "
  "It also defines the tag &lt;wimg&gt; that converts the image to an apropriate format for the client.";

#include <module.h>

void create() {
  defvar("wap1", 0, "Support WAP 1.0", TYPE_FLAG,
	 "Set correct MIME-types for WAP 1.0 clients. Not useful if you do not convert "
	 "your pages to WML 1.0 when needed.");
}

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "cimg" }));
}

void first_try(RequestID id)
{
  if(!id->request_headers->accept) id->request_headers->accept="";

  if(has_value(id->request_headers->accept,"image/vnd.wap.wbmp") ||
     has_value(id->request_headers->accept,"image/x-wap.wbmp")) id->supports->wbmp0=1;

  if(id->supports["wap1.1"] || id->supports["wap1.0"]) return;

  if(has_value(id->request_headers->accept,"text/vnd.wap.wml") ||
     has_value(id->request_headers->accept,"application/vnd.wap.wml")) id->supports["wap1.1"]=1;
  if(has_value(id->request_headers->accept,"text/x-wap.wml")) id->supports["wap1.0"]=1;

  if(id->supports->unknown) {
    id->supports["wap1.1"]=1;
    id->supports->wbmp0=1;
  }
}

mixed filter(mixed result, RequestID id) {
  if(!query("wap1")) return result;
  if(!mappingp(result)) return result;
  if(result->type=="text/vnd.wap.wml" &&
     !id->supports["wap1.1"] &&
     id->supports["wap1.0"]) {
    result->type="text/x-wap.wml";
  }

  if(result->type=="image/vnd.wap.wbmp" &&
     !id->supports["wap1.1"] &&
     id->supports["wap1.0"]) {
    result->type="image/x-wap.wbmp";
  }

  return result;
}

array tag_wimg(string t, mapping m, RequestID id) {
  m->format="gif";
  if(id->supports->wbmp0 && !id->supports->gifinline)
    m->format="wbf";
  ({ 1, "cimg", m });
}
