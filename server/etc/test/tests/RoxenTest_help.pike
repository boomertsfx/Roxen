inherit "pike_test_common.pike";
inherit "rxmlhelp";

array(string) new = ({});
#include <module_constants.h>

int test_module_info(ModuleInfo mi)
{
  if (!(mi->last_checked && !mi->name) ||
      mi->NotAModule) return 0;
  return 1;
}

void run_tests( Configuration c )
{
  // Create a new server
  test( roxen.enable_configuration, "helptestserver" );

  c = test_generic( check_is_configuration,
		    roxen.find_configuration,
		    "helptestserver" );

  if( !c )  {
    report_error( "Failed to find test configuration\n");
    return;
  }
  test(DBManager.set_permission, "local", c, DBManager.WRITE);
  test(c->set, "URLs", ({ "http://*:17372" }) );
  test(c->start, 0);
  
  // Check that all modules compile.
  werror("Checking that all modules compile...\n");
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors(ec);
  roxen->clear_all_modules_cache();
  // Add all modules except wrapper modules and other funny stuff.
  roxenloader.push_compile_error_handler(ec);
  array modules = roxen->all_modules();
  roxenloader.pop_compile_error_handler();
  werror("Checking for errors.\n");
  test_equal("", ec->get);
  werror("Checking for warnings.\n");
  test_equal("", ec->get_warnings);

  object key = c->getvar("license")->get_key();
  sort(modules->sname, modules);
  foreach(modules, ModuleInfo m) {
    test_generic(check_true, test_module_info, m);
    if( (< "roxen_test", "config_tags", "update",
	   "compat", "configtablist", "flik", "lpctag",
	   "ximg", "userdb", "htmlparse", "directories2",
	   "fastdir" >)[m->sname] )
      continue;
    if (m->locked) {
      if (!key || !m->unlocked(key, c)) {
	werror("Locked module: %O lock: %O\n", m->name || m->sname, m->locked);
	continue;
      }
    }
    current_test++;
    new += ({ m->sname });
    test_generic( check_is_module, c->enable_module, m->sname );
  }

  // Wait for everything to settle down.
  sleep(5);
  test( c->disable_module, "ac_filesystem" );
  //test( c->disable_module, "auth" );
  sleep(5);

  // Make a list of all tags and PI:s
  array tags=map(indices(c->rxml_tag_set->get_tag_names()),
		 lambda(string tag) {
		   if(tag[..3]=="!--#" || !has_value(tag, "#"))
		     return tag;
		   return "";
		 } ) - ({ "" });
  tags += map(indices(c->rxml_tag_set->get_proc_instr_names()),
	      lambda(string tag) { return "?"+tag; } );

  RequestID id = roxen.InternalRequestID( );
  id->set_url( "http://localhost:80/" ); //  Will clear id->conf
  id->conf = c;

  foreach(tags, string tag)
    test_true(find_tag_doc, tag, id);

  foreach(new, string m)
    test( c->disable_module, m );

  test(c->stop);
  test( roxen.disable_configuration, "usertestconfig" );
}
