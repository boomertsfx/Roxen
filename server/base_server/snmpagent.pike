/*
 * $Id: snmpagent.pike,v 1.4 2001/06/30 23:02:43 hop Exp $
 *
 * The Roxen SNMP agent
 * Copyright � 2001, Roxen IS.
 *
 * Author: Honza Petrous
 * January 2001


RFC 1156	base MIB (done marked by *):
		 system:
		   sysDescr *
		   sysObjectID *
		   sysUpTime *
		   sysL
		 snmp:
		   snmpInPkts *
		   snmpOutPkts *
RFC 2248	Network Services Monitoring MIB

Developer notes:

 Known issues:
	- every reload spawne a new thread, I guess that old ones are never
	  used then. [threads leak] // FIXME: solved by switching to the async i/o
 Todos:
    v1.0 todo:
	- cold/warm start trap generation
	- 'basic' Roxen working variables

    v1.1 todo:
	- trap handling

    v2.0 todo:
	- Roxen.module API for registering MIB subtree

    v3.0 todo:
	- SNMP v3 
	- security


 */

inherit "global_variables";
inherit Roxen;
#define roxen roxenp()



// FIXME: thread leaking is hided by moving to the async i/o model
//#define NO_THREADS !constant(thread_create)
#define NO_THREADS 1 

//#define SNMPAGENT_DEBUG 1
#ifdef SNMPAGENT_DEBUG
# define SNMPAGENT_MSG(X) report_notice("SNMPagent: "+X+"\n")
# define SNMPAGENT_MSGS(X, Y) report_notice("SNMPagent: "+X+"\n", @Y)
#else
# define SNMPAGENT_MSG(X)
# define SNMPAGENT_MSGS(X, Y)
#endif

#define SNMP_OP_GETREQUEST	0
#define SNMP_OP_GETNEXT		1
#define SNMP_OP_GETRESPONSE	2
#define SNMP_OP_SETREQUEST	3
#define SNMP_OP_TRAP		4

#define RISMIB_BASE			"1.3.6.1.4.1.8614"
#define RISMIB_BASE_WEBSERVER		RISMIB_BASE+".1.1"

#define RET_NEXTOID(oidnext) if(op == SNMP_OP_GETNEXT) rdata += ([attrname:({"oid", oidnext+".0"})])
//#define RET_VALUE(arr) if(op == SNMP_OP_GETREQUEST) rdata[attrname] += arr
#define RET_VALUE(arr) rdata[attrname] += arr
#define LOG_EVENT(txt, pkt) log_event(txt, pkt)

// base external feeders

string get_description() { return("Roxen Webserver SNMP agent v"+("$Revision: 1.4 $"/" ")[1]+" (devel. rel.)"); }
//! External function for MIB object 'system.sysDescr'

string get_sysoid() { return RISMIB_BASE_WEBSERVER; }
//! External function for MIB object 'system.sysOID'

int get_uptime() { return ((time(1) - roxen->start_time)*100); }
//! External function for MIB object 'system.sysUpTime'

string get_syscontact() { return query("snmp_syscontact"); }
//! External function for MIB object 'system.sysContact'

string get_sysname() { return query("snmp_sysname"); }
//! External function for MIB object 'system.sysName'

string get_syslocation() { return query("snmp_syslocation"); }
//! External function for MIB object 'system.sysLocation'

int get_sysservices() { return query("snmp_sysservices"); }
//! External function for MIB object 'system.sysServices'


class SNMPagent {
  private int enabled;

  // Global variables
  private object fd;		// opened UDP port
  private int inited;		// flag
  private int snmpinpkts;
  private int snmpoutpkts;
  private int snmpbadver;
  private int snmpbadcommnames;
  private int snmpbadcommuses;
  private int snmpenaauth;
  private mapping events;
  private mixed co;
  private object th;
  private static SNMPmib mib;

  int get_null() { return 0; }
  //! External function for MIB object returning nothing

  int get_snmpinpkts() { return(snmpinpkts); };
  int get_snmpoutpkts() { return(snmpoutpkts); };
  int get_snmpbadver() { return(snmpbadver); };
  int get_snmpbadcommnames() { return(snmpbadcommnames); };
  int get_snmpbadcommuses() { return(snmpbadcommuses); };
  int get_snmpenaauth() { return(snmpenaauth); };

class SNMPmib {
#define MIBTREE_BASE "1.3.6.1"

  private mapping(string:array) mibtable;

  public string|int oid_strip (string oid) { // note: this method must be public!
  //! Removes first four octets from OID string, as internal table works
  //! on such stripped OIDs.
    array arr = oid / ".";
    if (sizeof(arr) < 7)
      return 0;
    oid = arr[4..] * ".";
    return oid;
  }

  private int|string oid_check(string oid) {
  //! Checks existence of an managed object in the database
    if(!(oid = oid_strip(oid))) return 0;
    return zero_type(mibtable[oid]) ? 0 : oid;
  }

  int register(string oid, array data) {
  //! Low level method for registering a new managed object
    if(!(oid = oid_strip(oid))) return -1; // false => bad OID
    if(oid_check(oid))
      return 0; // false => the OID is already registered 
    mibtable += ([oid: data]); // FIXME: what about type checking of 'data' ?
    return 1; // ok (registered)
  }

  void create(string|void filename) {
  
    mibtable = ([
	// system
	"2.1.1": ({ 0, get_null, "2.1.1.1.0"}),
	// system.sysDescr
	"2.1.1.1.0": ({ "str",
		get_description,
		"2.1.1.2.0"}),
	// system.sysObjectID
	"2.1.1.2.0":
	  ({ "oid", get_sysoid, "2.1.1.3.0" }),
	// system.sysUpTime
	"2.1.1.3.0":
	  ({ "tick",  get_uptime, "2.1.1.4.0" }),
	// system.sysContact
	"2.1.1.4.0":
	  ({ "str", get_syscontact, "2.1.1.5.0" }),
	// system.sysName
	"2.1.1.5.0":
	  ({ "str", get_sysname, "2.1.1.6.0" }),
	// system.sysLocation
	"2.1.1.6.0":
	  ({ "str", get_syslocation, "2.1.1.7.0" }),
	// system.sysServices
	"2.1.1.7.0":
	  ({ "int", get_sysservices, 0 }),

	// snmp
	"2.1.11":
	  ({ 0, get_null, "2.1.11.1.0" }),
	// snmp.snmpInPkts
	"2.1.11.1.0":
	  ({ "count", get_snmpinpkts, "2.1.11.2.0" }),
	// snmp.snmpOutPkts
	"2.1.11.2.0":
	  ({ "count", get_snmpoutpkts, "2.1.11.3.0" }),
	// snmp.snmpBadVers
	"2.1.11.3.0":
	  ({ "count", get_snmpbadver, "2.1.11.4.0" }),
	// snmp.snmpInBadCommunityNames
	"2.1.11.4.0":
	  ({ "count", get_snmpbadcommnames, "2.1.11.5.0" }),
	// snmp.snmpInBadCommunityUses
	"2.1.11.5.0":
	  ({ "count", get_null, "2.1.11.6.0" }),
	// snmp.snmpInASNParseErrs
	"2.1.11.6.0":
	  ({ "count", get_null, "2.1.11.8.0" }),
	// 7 is not used
	// snmp.snmpInTooBigs
	"2.1.11.8.0":
	  ({ "count", get_null, "2.1.11.9.0" }),
	// snmp.snmpInNoSuchNames
	"2.1.11.9.0":
	  ({ "count", get_null, "2.1.11.10.0" }),
	// snmp.snmpInBadValues
	"2.1.11.10.0":
	  ({ "count", get_null, "2.1.11.11.0" }),
	// snmp.snmpInReadOnlys
	"2.1.11.11.0":
	  ({ "count", get_null, "2.1.11.12.0" }),
	// snmp.snmpInGenErrs
	"2.1.11.12.0":
	  ({ "count", get_null, "2.1.11.13.0" }),
	// snmp.snmpInTotalReqVars
	"2.1.11.13.0":
	  ({ "count", get_null, "2.1.11.14.0" }),
	// snmp.snmpInTotalSetVars
	"2.1.11.14.0":
	  ({ "count", get_null, "2.1.11.15.0" }),
	// snmp.snmpInGetRequests
	"2.1.11.15.0":
	  ({ "count", get_null, "2.1.11.16.0" }),
	// snmp.snmpInGetNexts
	"2.1.11.16.0":
	  ({ "count", get_null, "2.1.11.17.0" }),
	// snmp.snmpInSetRequests
	"2.1.11.17.0":
	  ({ "count", get_null, "2.1.11.18.0" }),
	// snmp.snmpInGetResponses
	"2.1.11.18.0":
	  ({ "count", get_null, "2.1.11.19.0" }),
	// snmp.snmpInTraps
	"2.1.11.19.0":
	  ({ "count", get_null, "2.1.11.20.0" }),
	// snmp.snmpOutTooBigs
	"2.1.11.20.0":
	  ({ "count", get_null, "2.1.11.21.0" }),
	// snmp.snmpOutNoSuchNames
	"2.1.11.21.0":
	  ({ "count", get_null, "2.1.11.22.0" }),
	// snmp.snmpOutBadValues
	"2.1.11.22.0":
	  ({ "count", get_null, "2.1.11.24.0" }),
	// 23 is not used
	// snmp.snmpOutGenErrs
	"2.1.11.24.0":
	  ({ "count", get_null, "2.1.11.25.0" }),
	// snmp.snmpOutGetRequests
	"2.1.11.25.0":
	  ({ "count", get_null, "2.1.11.26.0" }),
	// snmp.snmpOutGetNexts
	"2.1.11.26.0":
	  ({ "count", get_null, "2.1.11.27.0" }),
	// snmp.snmpOutSetRequests
	"2.1.11.27.0":
	  ({ "count", get_null, "2.1.11.28.0" }),
	// snmp.snmpOutGetResponses
	"2.1.11.28.0":
	  ({ "count", get_null, "2.1.11.29.0" }),
	// snmp.snmpOutTraps
	"2.1.11.29.0":
	  ({ "count", get_null, "2.1.11.30.0" }),
	// snmp.snmpEnableAuthenTraps
	"2.1.11.30.0":
	  ({ "int", get_snmpenaauth, 0 }),

	// enterprises.roxenIS.webserver
	"4.1.8614.1.1":
	  ({ 0, get_null, "4.1.8614.1.1.999.0" }),
	// HACK!!
	"4.1.8614.1.1.999.0":
	  ({ 0, get_null, 0 })
	
	]);

#if 0
    // external definitions from the file
    if (stringp(filename)) {

    }
#endif

  } // create

  array `[](string oid) {
  //! Returns array
    if (!oid_check(oid)) {
      return 0;
    }
    oid = oid_strip(oid);
    return (({mibtable[oid][0], mibtable[oid][1](), mibtable[oid][2]}));
  }

  string|int oid_guess_next(string oid) {
  //! Tries to guess next OID. Usable to situation when GET_NEXT op
  //! contains OID without .0

    if(oid_check(oid+".0"))
      return oid+".1";
    return 0;
  }

} // SNMPmib

  void create() {
    //disable();
  }

  int enable() {
  //! Enable SNMPagent processing.

    mib = SNMPmib();
    if (!status())
      start();
    enabled = 1;
    return (enabled);
  }

  int disable() {
  //! Disable SNMPagent processing.
    if(status())
      stop();
    enabled = 0;
    return (!enabled);
  }

  int status() {
    return enabled;
  }

  private void log_event(string txt, mapping pkt) {

    SNMPAGENT_MSG(sprintf("event: %O", txt));
    if(zero_type(events[txt]))
      events[txt] += ([ pkt->ip : ([ pkt->community: 1]) ]) ;
    else if(zero_type(events[txt][pkt->ip]))
      events[txt][pkt->ip] += ([ pkt->community: 1]);
    else
      events[txt][pkt->ip][pkt->community]++;
  }

  private int chk_access(string level /*, string attrname*/, mapping pkt) {
  //! Check access aginst snmp_community array.

    return
      (search(query("snmp_community"), pkt->community+":"+level) > -1) ||
      (search(query("snmp_community"), pkt->community+":"+"rw") > -1);
  }


  private void process_query(mapping data) {
  //! The main code of SNMPagent.

    mapping pdata, rdata = ([]);
    int msgid, op, errnum = 0, setflg = 0;
    string attrname, comm;
    array val;

    snmpinpkts++;
    pdata = fd->decode_asn1_msg(data);

    SNMPAGENT_MSG(sprintf("Got parsed: %O", pdata));

    if(!mappingp(pdata)) {
      SNMPAGENT_MSG("SNMP message can not be decoded. Silently ommited.");
      return;
    }

    msgid = indices(pdata)[0];
    comm = pdata[msgid]->community || "";
    op = pdata[msgid]->op;

    // test for correct community string
    if(!chk_access("ro", pdata[msgid])) {
      snmpbadcommnames++;
      errnum = 5 /*SNMP_ERR_GENERR*/;
      attrname = indices(pdata[msgid]->attribute[0])[0];
      LOG_EVENT("Bad community name", pdata[msgid]);
    } else
    foreach(pdata[msgid]->attribute, mapping attrs) {
      mixed attrval = values(attrs)[0];
      attrname = indices(attrs)[0];

      if(!mib)
	SNMPAGENT_MSG(" MIB table isn't loaded!\n");
      val = mib[attrname];
      if (!val && op == SNMP_OP_GETNEXT) { // FIXME: move guessing to the MIB object
	val = mib[attrname+".0"];
	if(arrayp(val))
	  val[2] = mib->oid_strip(attrname)+".0";
      }
      if (val)
	switch(op) {

	  case SNMP_OP_GETREQUEST:
	    if (val[0])
	      rdata[attrname] += val[0..1];
	    break;

	  case SNMP_OP_GETNEXT:
	    if (val[2]) {
	      string noid = MIBTREE_BASE+"."+val[2];
	      val = mib[noid];
	      if (val && val[0])
	        rdata[noid] += val[0..1];
	    }
	    break;

	  case SNMP_OP_SETREQUEST:

	    switch (attrname) {
	      case RISMIB_BASE_WEBSERVER+".1.0":
	        // HACK! For testing purpose only!
	        // Server restart = 1; server shutdown = 2
	        if(chk_access("rw", pdata[msgid])) {
		  setflg = 1;
		  rdata[attrname] += ({ "int", attrval });
	          rdata["1.3.6.1.2.1.1.3.0"] += ({"tick", get_uptime() });
		  if(attrval == 1 || attrval == 2) {
		    report_warning("SNMPagent: Initiated " + ((attrval==1)?"restart":"shutdown") + " from snmp://" + pdata[msgid]->community + "@" + pdata[msgid]->ip + "/\n");
	  	    if (attrval == 1) roxen->restart(0.5);
	  	    if (attrval == 2) roxen->shutdown(0.5);
		  }
	        } else
	          snmpbadcommuses++;
	        break;
	      case MIBTREE_BASE+".2.1.11.30.0":
	        // The standard-based (RFC1213) method of disabling auth. traps
	        if(chk_access("rw", pdata[msgid])) {
		  setflg = 1;
		  rdata[attrname] += ({ "int", attrval });
	          rdata["1.3.6.1.2.1.1.3.0"] += ({"tick", get_uptime() });
		  if(attrval == 0 || attrval == 1) {
		    report_warning("SNMPagent: Requested " + attrval?"en":"dis" + "abling of auth. traps from snmp://" + pdata[msgid]->community + "@" + pdata[msgid]->ip + "/\n");
	  	    // here will be ena/disabling of such traps
		  }
	        } else
	          snmpbadcommuses++;
	        break;

	    } //switch
	  break;
        } //switch
        else
	  SNMPAGENT_MSG(sprintf(" unknown or unsupported OID: %O:%O", attrname, attrval));
      

/*
	// www group 1.3.6.1.2.1.65.1
	// www.wwwService 1.3.6.1.2.1.65.1.1
	// www.wwwServiceTable 1.3.6.1.2.1.65.1.1.1
	// www.wwwServiceEntry 1.3.6.1.2.1.65.1.1.1.1 ...
	break;
*/

    } //foreach

    if(op == SNMP_OP_SETREQUEST && !setflg && !errnum) {
      LOG_EVENT("Set not allowed", pdata[msgid]);
    }

    //SNMPAGENT_MSG(sprintf("Answer: %O", rdata));
    snmpoutpkts++;
    if(!sizeof(rdata)) {
      if (!errnum) LOG_EVENT("No such name", pdata[msgid]);
      fd->get_response(([attrname:({"oid", attrname})]), pdata, errnum || 2 /*SNMP_NOSUCHNAME*/);
    } else
      fd->get_response(rdata, pdata);
  }

  private void real_start() {
  //! Opens the SNMP port. Then waits for the requests. 

    mixed err;
    mapping data;
    array hp = query("snmp_hostport")/":";
    int p = (sizeof(hp)>1) ? (int)hp[1] : 161; // FIXME: SNMPAGENT_DEFAULT_PORT


    fd = Protocols.SNMP.protocol(0, hp[0], p||161);
    if(arrayp(err))
      RXML.run_error("SNMPagent: can't open UDP port " + hp[0]+":"+(string)(p||161)+"[" + err[0] + "].");
    SNMPAGENT_MSG(sprintf("SNMP UDP port %s:%d binded successfully.", hp[0], p||161));

#ifdef COLDSTART_TRAP // Not working, yet
    // Cold start TRAP
    if (sizeof(query("snmp_traphost"))) {
      mapping rdata;
      rdata = ([attrname:({"oid", "1.3.6.1.4.1.0.1.1"})]);
      rdata += ([attrname:({"ipaddr", "127.0.0.1" }) ]);   // FIXME
      rdata += ([attrname:({"int", 1 }) ]); // generic trap = warmStart
      rdata += ([attrname:({"int", 0 }) ]); // specific trap = none
      rdata += ([attrname:({"tick", (time(1) - roxen->start_time)*1000 }) ]); // uptime
    }
#endif

    enabled = 1;
#if NO_THREADS
    // set callbacks
    fd->set_nonblocking(process_query);
#else
    // wait for connection
    //while(1) process_query(fd->read());
    while(enabled)
      if(!arrayp(err=catch(data=fd->read())))
        process_query(data);
#endif

  }

  private void start() {

    events = ([]);
    if(!inited) {
      inited++;
      SNMPAGENT_MSG("Initializing...");
      //fd = Stdio.UDP(); //Port();

#if NO_THREADS
      //SNMPAGENT_MSG("Threads don't detected. Async I/O used intstead.");
      co = call_out( real_start, 1 );
#else
      //SNMPAGENT_MSG("Threads detected. One thread will be created for agent processing.");
      th = thread_create( real_start );
#endif
    }
  }

  void stop() {

    SNMPAGENT_MSG("Shutting down...");
    fd->set_read_callback(0);
    catch(fd->set_blocking());
    catch(fd->close());
#if NO_THREADS
    remove_call_out(co);
#else
    th = 0;
#endif
    destruct(fd); // avoid fd leaking; FIXME: some cyclic dependencies in SNMP pmod.
    fd = 0;
    inited = 0;
    SNMPAGENT_MSG("Shutdown complete.");
  }

/*
  string status2() {
    string rv = "";

    rv =  "<h2>SNMP access table</h2>\n";
#if 0 //SNMP_STATS
      rv += "<table>\n";
      rv += "<tr ><th>From</th><th>To</th><th>Size</th></tr>\n";
      foreach(mails, mapping m)
        rv += "<tr ><td>"+(m->from||"[N/A]")+"</td><td>"+(m->to||"[default]")+"</td><td>"+m->length+"</td></tr>\n";
      rv += "</table>\n";
#else
      rv += "<pre>" + sprintf("%O<br />\n", events) + "</pre>\n";
#endif
    return rv;
  }
*/

  int add_virtserv(int vs) {
report_debug(sprintf("snmpagent:DEB: add: %O->%O\n",vs,roxen->configurations[vs]->name));

    return(1);
  }

  int del_virtserv(int vs) {
report_debug(sprintf("snmpagent:DEB: del: %O->%O\n",vs,roxen->configurations[vs]->name));

    return(1);
  }

} // end of SNMPagent object

SNMPagent snmpagent;
//! Global SNMPagent object
