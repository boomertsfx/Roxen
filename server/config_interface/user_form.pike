// $Id: user_form.pike,v 1.7 2002/06/15 18:31:11 nilsson Exp $

#include <config_interface.h>

mapping parse( RequestID id )
{
  string res="";

  RequestID nid = id;

  while( nid->misc->orig && !nid->my_fd )
    nid = nid->misc->orig;

  if( !nid->misc->config_user->auth( "Edit Users" ) )
    return Roxen.http_string_answer("Permission denied",
				    "text/html");

  foreach( sort( roxen.list_admin_users() ), string uid )
  {
    object u  = roxen.find_admin_user( uid );
    res += "<table width='100%'><tr><td bgcolor='"+config_setting2("bgcolor")+
           "'><font size='+2'>&nbsp;&nbsp;<b>"+uid+"</b></font></td></tr></table>";
    res += u->form( nid );
  }

  do
  {
    id->variables = nid->variables;
    id = id->misc->orig;
  } while( id );

  return Roxen.http_string_answer(res, "text/html");
}
