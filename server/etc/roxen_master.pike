/*
 * Roxen master
 */
string cvs_version = "$Id: roxen_master.pike,v 1.58 1999/11/24 17:35:02 per Exp $";

/*
 * name = "Roxen Master";
 * doc = "Roxen's customized master.";
 */

class MyCodec
{
  program p;
  string nameof(mixed x)
  {
    if(p!=x)
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;

    switch(sprintf("%t",x))
    {
      case "program":
	if(p!=x)
	{
          mixed tmp;
	  if(tmp=search(master()->programs,x))
	    return tmp;

	  if((tmp=search(values(_static_modules), x))!=-1)
	    return "_static_modules."+(indices(_static_modules)[tmp]);
	}
	break;

      case "object":
	if(mixed tmp=search(master()->objects,x))
	{
	  if(tmp=search(master()->programs,tmp))
	  {
	    return tmp;
	  }
	}
	break;
    }

    return ([])[0];
  }

  function functionof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    werror("Failed to decode %s\n",x);
    return 0;
  }


  object objectof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(object tmp=(object)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
    
  }

  program programof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(sscanf(x,"_static_modules.%s",x))
    {
      return (program)_static_modules[x];
    }

    if(program tmp=(program)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
  }

  mixed encode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  mixed decode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  void create( program q )
  {
    p = q;
  }
}


object mm=(object)"/master";
inherit "/master";


mapping handled = ([]);

string make_ofilename( string from )
{
  return "precompiled/"+
         (hash(from)+""+
          hash(reverse(from))+""+
          hash(from[strlen(from)/2..]))
         +".o";
}

void dump_program( string pname, program what )
{
  string outfile = make_ofilename( pname );
  string data = encode_value( what, MyCodec( what ) );
  _static_modules.files()->Fd(outfile,"wct")->write(data);
} 

int loaded_at( program p )
{
  return load_time[ search( programs, p ) ];
} 

program low_findprog(string pname, string ext, object|void handler)
{
  program ret;
  array s;
  string fname=pname+ext;

  if( (s=master_file_stat( fname )) && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
      if( programs[fname] ) 
        return programs[fname];

    switch(ext)
    {
    case "":
    case ".pike":
      foreach( ({ make_ofilename( fname ), fname+".o" }), string ofile )
        if(array s2=master_file_stat( ofile ))
        {	
          if(s2[1]>0 && s2[3]>=s[3])
          {
            catch 
            {
              load_time[ fname ] = time();
              return programs[fname]=
                     decode_value(_static_modules.files()->
                                  Fd(ofile,"r")->read(),Codec());
            };
          }
        }
      
      if ( mixed e=catch { ret=compile_file(fname); } )
      {
	if(arrayp(e) && sizeof(e)==2 &&
	   arrayp(e[1]) && sizeof(e[1]) == sizeof(backtrace()))
	  e[1]=({});
	throw(e);
      }
      break;
#if constant(load_module)
    case ".so":
      ret=load_module(fname);
#endif
    }
    load_time[fname] = time();
    return programs[fname] = ret;
  }
  if( programs[ fname ] ) 
    return programs[ fname ];
  return UNDEFINED;
}

mapping resolv_cache = ([]);
mixed resolv(string a, string b)
{
  if( resolv_cache[a] )
    return resolv_cache[a]->value ? resolv_cache[a]->value : ([])[0];
  resolv_cache[a] = ([ "value":(::resolv(a,b)) ]);
  return resolv_cache[a]->value ? resolv_cache[a]->value : ([])[0];
}

int refresh( program p )
{
  string fname = program_name( p );
  /*
   * No need to do anything right now, low_findprog handles 
   * refresh automatically. 
   *
   * simply return 1 if a refresh will take place.
   *
   */
  array s;
  if( (s=master_file_stat( fname )) && s[1]>=0 )
    if( load_time[ fname ] > s[ 3 ] )
      return 0;
  return 1;
}

string program_name(program p)
{
  return search(programs, p);
}

string describe_backtrace(mixed trace, void|int linewidth)
{
  int e;
  string ret;
  linewidth=999999;

  if((arrayp(trace) && sizeof(trace)==2 && stringp(trace[0])) ||
     (objectp(trace) && trace->is_generic_error))
  {
    if (catch {
      ret = trace[0];
      trace = trace[1];
    }) {
      return "Error indexing backtrace!\n";
    }
  }else{
    ret="";
  }

  if(!arrayp(trace))
  {
    ret+="No backtrace.\n";
  }else{
    for(e = sizeof(trace)-1; e>=0; e--)
    {
      mixed tmp;
      string row;

      if (mixed err=catch 
      {
	tmp = trace[e];
	if(stringp(tmp))
	{
	  row=tmp;
	}
	else if(arrayp(tmp))
	{
	  string pos;
	  if(sizeof(tmp)>=2 && stringp(tmp[0]) && intp(tmp[1]))
	  {
	    pos=trim_file_name(tmp[0])+":"+tmp[1];
	  }else{
	    mixed desc="Unknown program";
	    if(sizeof(tmp)>=3 && functionp(tmp[2]))
	    {
	      catch {
		if(mixed tmp=function_object(tmp[2]))
		  if(tmp=object_program(tmp))
		    if(tmp=describe_program(tmp))
		      desc=tmp;
	      };
	    }
	    pos=desc;
	  }
	  
	  string data;
	  
	  if(sizeof(tmp)>=3)
	  {
	    if(functionp(tmp[2]))
	      data = function_name(tmp[2]);
	    else if (stringp(tmp[2])) {
	      data= tmp[2];
	    } else
	      data ="unknown function";
	    
	    data+="("+
	      stupid_describe_comma_list(tmp[3..], 99999999)+
	    ")";

	    if(sizeof(pos)+sizeof(data) < linewidth-4)
	    {
	      row=sprintf("%s: %s",pos,data);
	    }else{
	      row=sprintf("%s:\n%s",pos,sprintf("    %*-/s",linewidth-6,data));
	    }
	  }
	}
	else
	{
	  row="Destructed object";
	}
      }) {
	row += sprintf("Error indexing backtrace line %d (%O)!", e, err[1]);
      }
      ret += row + "\n";
    }
  }

  return ret;
}


void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }

  foreach( indices(programs), string f )
    load_time[ f ] = time();

  programs["/master"] = object_program(o);
  objects[ object_program(o) ] = o;
  /* Move the old efuns to the new object. */

  foreach(master_efuns, string e)
    add_constant(e, o[e]);
}
