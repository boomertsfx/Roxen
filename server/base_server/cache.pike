//string cvs_version = "$Id: cache.pike,v 1.31 1999/12/27 22:49:05 nilsson Exp $";

#define LOCALE	roxenp()->locale->get()->config_interface
#include <roxen.h>
#include <config.h>

constant svalsize = 4*4; // if pointers are 4 bytes..
int get_size(mixed x)
{
  if(mappingp(x))
    return svalsize + 64 + get_size(indices(x)) + get_size(values(x));
  else if(stringp(x))
    return strlen(x)+svalsize;
  else if(arrayp(x))
  {
    mixed f;
    int i;
    foreach(x, f)
      i += get_size(f);
    return svalsize + 4 + i;    // (base) + arraysize
  } else if(multisetp(x)) {
    mixed f;
    int i;
    foreach(indices(x), f)
      i += get_size(f);
    return svalsize + i;    // (base) + arraysize
  } else if(objectp(x) || functionp(x)) {
    return svalsize + 128; // (base) + object struct + some extra.
    // _Should_ consider size of global variables / refcount
  }
  return svalsize; // base
}


#define TIMESTAMP 0
#define DATA 1
#define TIMEOUT 2

#define ENTRY_SIZE 3

#define CACHE_TIME_OUT 300

#if DEBUG_LEVEL > 8
# ifndef CACHE_DEBUG
#  define CACHE_DEBUG
# endif
#endif

#ifdef CACHE_DEBUG
# define CACHE_WERR(X) werror("CACHE: "+X+"\n");
#else
# define CACHE_WERR(X)
#endif

mapping cache;
mapping hits=([]), all=([]);

#ifdef THREADS
Thread.Mutex cleaning_lock = Thread.Mutex();
#endif /* THREADS */

void cache_expire(string in)
{
  m_delete(cache, in);
}

mixed cache_lookup(string in, string what)
{
  CACHE_WERR(sprintf("cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
  all[in]++;
  if(cache[in] && cache[in][what])
  {
    CACHE_WERR("Hit");
    hits[in]++;
    cache[in][what][TIMESTAMP]=time(1);
    return cache[in][what][DATA];
  }
  CACHE_WERR("Miss");
  return 0;
}

string status()
{
  string res, a;
  res = "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
      #"<tr bgcolor=\"#f0f0ff\">
<td><cf-locale get=class_></td>
<td align=\"right\"><cf-locale get=entries></td>
<td align=\"right\"><cf-locale get=size></td>
<td align=\"right\"><cf-locale get=hits></td>
<td align=\"right\"><cf-locale get=misses></td>
<td align=\"right\"><cf-locale get=hitpct></td>
";
  array c, b;
  mapping ca = ([]), cb=([]), ch=([]), ct=([]);
  b=indices(cache);
  c=Array.map(values(cache), get_size);

  int i;

  for(i=0; i<sizeof(b); i++)
  {
    int s = sizeof(cache[b[i]]);
    int h = hits[b[i]];
    int t = all[b[i]];
    sscanf(b[i], "%s:", b[i]);
    b[i] = LOCALE->translate_cache_class( b[i] );
    ca[b[i]]+=c[i]; cb[b[i]]+=s; ch[b[i]]+=h; ct[b[i]]+=t;
  }
  b=indices(ca);
  c=values(ca);
  sort(c,b);
  int n, totale, totalm, totalh, mem, totalr;
  i=0;
  c=reverse(c);
  foreach(reverse(b), a)
  {
    if(ct[a])
    {
      res += ("<tr align=\"right\" bgcolor=\""+(n/3%2?"#f0f0ff":"white")+
	      "\"><td align=\"left\">"+a+"</td><td>"+cb[a]+"</td><td>" +
	      sprintf("%.1f", ((mem=c[i])/1024.0)) + "</td>");
      res += "<td>"+ch[a]+"</td><td>"+(ct[a]-ch[a])+"</td>";
      if(ct[a])
	res += "<td>"+(ch[a]*100)/ct[a]+"%</td>";
      else
	res += "<td>0%</td>";
      res += "</tr>";
      totale += cb[a];
      totalm += mem;
      totalh += ch[a];
      totalr += ct[a];
    }
    i++;
  }
  res += "<tr align=\"right\" bgcolor=\"lightblue\"><td align=\"left\">&nbsp;</td><td>"+
    totale+"</td><td>" + sprintf("%.1f", (totalm/1024.0)) + "</td>";
  res += "<td>"+totalh+"</td><td>"+(totalr-totalh)+"</td>";
  if(totalr)
    res += "<td>"+(totalh*100)/totalr+"%</td>";
  else
    res += "<td>0%</td>";
  res += "</tr>";
  return res + "</table>";
}

void cache_remove(string in, string what)
{
  CACHE_WERR(sprintf("cache_remove(\"%s\",\"%O\")", in, what));
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in])
      m_delete(cache[in], what);
}

mixed cache_set(string in, string what, mixed to, int|void tm)
{
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %O)",
		     in, what, to));
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  cache[in][what][TIMEOUT] = tm;
  cache[in][what][TIMESTAMP] = time(1);
  return to;
}

void cache_clear(string in)
{
  CACHE_WERR(sprintf("cache_clear(\"%s\")", in));
  if(cache[in])
    m_delete(cache,in);
}

void cache_clean()
{
  remove_call_out(cache_clean);
  call_out(cache_clean, CACHE_TIME_OUT);
  string a, b;
  int cache_time_out=CACHE_TIME_OUT;
  CACHE_WERR("cache_clean()");
  foreach(indices(cache), a)
  {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
    CACHE_WERR("  Class  " + a);
#endif
#endif
    foreach(indices(cache[a]), b)
    {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      CACHE_WERR("     " + b + " ");
#endif
#endif
#ifdef DEBUG
      if(!intp(cache[a][b][TIMESTAMP]))
	error("Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(cache[a][b][TIMESTAMP]+cache[a][b][TIMEOUT] <
	 (time(1) - (cache_time_out - get_size(cache[a][b][DATA])/100)))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	CACHE_WERR("DELETED");
#endif
#endif	
	m_delete(cache[a], b);
      }
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      else
	CACHE_WERR("Ok");
#endif
#endif	
      if(!sizeof(cache[a]))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	CACHE_WERR("   Class DELETED.");
#endif
#endif
	m_delete(cache, a);
      }
    }
  }
}

void create()
{
  CACHE_WERR("Now online.");
  cache=([  ]);
  add_constant( "cache", this_object() );
  add_constant( "Cache", this_object() );
  call_out(cache_clean, CACHE_TIME_OUT);
}
