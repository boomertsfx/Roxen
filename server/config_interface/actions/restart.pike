/*
 * $Id: restart.pike,v 1.12 2001/08/17 19:46:19 per Exp $
 */

#include <config_interface.h>
#include <roxen.h>

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _DEF_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

LocaleString name= LOCALE(34, "Restart or shutdown");
constant doc = "";


mixed parse( RequestID id )
{
  switch( id->variables->what )
  {
  case "restart":
     if( config_perm( "Restart" ) )
     {
       roxen->restart(0.5);
       return
"<input type=hidden name=action value=restart.pike>"
"<font color='&usr.warncolor;'><h1>"+LOCALE(197,"Restart")+"</h1></font>"+
 LOCALE(233, "Roxen will restart automatically.")+
"\n\n<p><i>"+
LOCALE(234, "You might see the old process for a while in the process table "
       "when doing 'ps' or running 'top'. This is normal. Roxen waits for a "
       "while for all connections to finish, the process will go away after "
       "at most 15 minutes.")+ "</i></p>";
     }
     return LOCALE(226,"Permission denied");

   case "shutdown":
     if( config_perm( "Shutdown" ) )
     {
       roxen->shutdown(0.5);
       return
"<font color='&usr.warncolor;'><h1>"+LOCALE(198,"Shutdown")+"</h1></font>"+
LOCALE(235,"Roxen will <b>not</b> restart automatically.")+
"\n\n<p><i>"+
LOCALE(234, "You might see the old process for a while in the process table "
       "when doing 'ps' or running 'top'. This is normal. Roxen waits for a "
       "while for all connections to finish, the process will go away after "
       "at most 15 minutes.")+ "</i></p>";
     }
     return LOCALE(226,"Permission denied");

  default:
    return Roxen.http_string_answer(
#"<blockquote><br />

 <cf-perm perm='Restart'>
   <gbutton href='?what=restart&action=restart.pike&class=maintenance' 
            width=300 icon_src=&usr.err-2;> "+
       LOCALE(197,"Restart")+#" </gbutton>
 </cf-perm>

<cf-perm not perm='Restart'>
  <gbutton dim width=300 icon_src=&usr.err-2;> "+
       LOCALE(197,"Restart")+#" </gbutton>
</cf-perm>

<cf-perm perm='Shutdown'>
  <gbutton href='?what=shutdown&action=restart.pike&class=maintenance' 
           width=300  icon_src=&usr.err-3;> "+
       LOCALE(198,"Shutdown")+#" </gbutton>
</cf-perm>

<cf-perm not perm='Shutdown'>
  <gbutton dim width=300 icon_src=&usr.err-3;> "+
       LOCALE(198,"Shutdown")+#" </gbutton>
</cf-perm>

</blockquote>

<p><cf-cancel href='?class=&form.class;'/></p>" );
     }
}
