#include <roxen.h>
//<locale-token project="config_interface"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("config_interface",X,Y)

mixed parse( RequestID id )
{
  string res="<br />";
  mapping v = id->variables;
  if(! id->misc->config_user->auth( "Edit Users" ) )
    return LOCALE("dy", "Permission denied");

  while( id->misc->orig ) id = id->misc->orig;

  if( v->delete_user && v->delete_user!="")
  {
    werror("\nGot %O\n",v->delete_user);
    id->misc->delete_old_config_user( v->delete_user );
    return "";
  }
  foreach( sort( id->misc->list_config_users() ), string uid )
  {
    object u = id->misc->get_config_user( uid );
    if( u == id->misc->config_user )
      res += ("<gbutton font='&usr.gbutton-font;' "
	      "dim='1' width='300' preparse='1'> " +
	      LOCALE("dE", "Delete") +" "+ u->real_name+" ("+uid+") "
	      "</gbutton><br />");
    else
      res += ("<dbutton gbutton-width='300' "
	      "gbutton-font='&usr.gbutton-font;' "
	      "gbutton-preparse='1' gbutton_title=' " +
	      LOCALE("dE", "Delete") +" "+ u->real_name+" ("+uid+")' "
	      "page='delete_user'>"
	      "<insert file='user_delete.pike?delete_user="
	      + Roxen.html_encode_string(uid) + 
	      "'></dbutton><br />");
  }
  return res;
}
