// This is a roxen module. Copyright � 1997 - 2000, Roxen IS.

#include <module.h>
inherit "modules/filesystems/filesystem";

constant cvs_version= "$Id: incoming.pike,v 1.13 2001/01/13 18:15:34 nilsson Exp $";


constant module_name = "Incoming filesystem";
constant module_doc = 
#"This file system is used only for uploads, the files that are uploaded 
can either not be downloaded, or they will be scrambled during the download. 
This is considered a nice way to treat people who try to
use your FTP site for warez distribution.";

static class decaying_file {

  inherit Stdio.File;

  static int rate, left;
  static function other_read_callback;
  static int crot;


  constant rotten_bits = "muahaha!(%/?\"&?�/&?(/?_,-.,_:;Ѭ��";


  static string decay(string data)
  {
    if(sizeof(data)<=left) {
      left -= sizeof(data);
      return data;
    }
    string newdata = "";
    while(sizeof(data)>left) {
      newdata += data[..left-1];
      newdata += rotten_bits[crot..crot];
      data = data[left+1..];
      left = rate;
      if(++crot >= sizeof(rotten_bits))
	crot = 0;
    }
    left -= sizeof(data);
    return newdata + data;
  }


  string read(mixed ... args)
  {
    string r = ::read(@args);
    if(stringp(r))
      r = decay(r);
    return r;
  }

  static mixed my_read_callback(mixed id, string data)
  {
    if(stringp(data))
      data = decay(data);
    return other_read_callback(id, data);
  }

  void set_read_callback(function read_callback)
  {
    if(read_callback) {
      other_read_callback = read_callback;
      ::set_read_callback(my_read_callback);
    } else
      ::set_read_callback(read_callback);
  }

  void set_nonblocking(function ... args)
  {
    if(sizeof(args) && args[0]) {
      other_read_callback = args[0];
      ::set_nonblocking(my_read_callback, @args[1..]);
    } else
      ::set_nonblocking(@args);
  }

  int query_fd()
  {
    return -1;
  }

  void create(object f, int s, int r)
  {
    assign(f);
    rate = r-1;
    if(rate<0)
      rate=0;
    left = s;
    crot = 0;
  }
}


void create()
{
  ::create();

  defvar("bitrot", 0,
	 "Scrambled downloads: Return files with bitrot", TYPE_FLAG,
	 "If this function is enabled, downloads <i>are</i> allowed, "
	 "but the files will be scrambled.");

  defvar("bitrot_header", 2376,
	 "Scrambled downloads: Unscrambled header length",TYPE_INT,
	 "Number of bytes to be sent without any bitrot at all.", 0,
	 lambda(){ return !query("bitrot"); });

  defvar("bitrot_percent", 3,
	 "Scrambled downloads: Percent of bits to rot", TYPE_INT,
	 "Selects the percentage of the file that will receive bitrot", 0,
	 lambda(){ return !query("bitrot"); });
}

static mixed not_allowed( object id )
{
  id->misc->moreheads = (id->misc->moreheads||([]))|(["Allow":"PUT"]);
  return http_low_answer (
    405, "<h1>" + id->method + " method not allowed in incoming filesystem.</h1>\n");
}


#define FILE_SIZE(X) (stat_cache?_file_size((X),id):Stdio.file_size(X))


static mixed lose_file( string f, object id )
{
  object o;
  int size = FILE_SIZE( f = path + f );
  if(size < 0)
    return (size==-2? -1:0);

  o = open( f, "r" );

  if(!o)
    return 0;

  id->realfile = f;
  accesses++;

  return decaying_file( o, query("bitrot_header"), 100/query("bitrot_percent") );
}

mixed find_file( string f, object id )
{
  switch(id->method) {
  case "GET":
  case "HEAD":
  case "POST":
    if(query("bitrot") && query("bitrot_percent")>0)
      return lose_file( f, id );
    else
      return not_allowed( id );

  case "PUT":
    if(FILE_SIZE( path + f ) >= 0) {
      id->misc->error_code = 409;
      return 0;
    }
    return ::find_file( f, id );

  case "DELETE":
  default:
    return not_allowed( id );
  }

  report_error("Not reached..\n");
  return 0;
}
