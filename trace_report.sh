#!/bin/sh
#
# trace_report
#
# Creates a report ($1.lst) of a specific Oracle trace dump file.
#
# INSTRUCTIONS:
#
# trace_report is a Unix shell script, which when executed with a trace
# file name as its only parameter, will create a report of the trace file,
# somewhat similar to a normal tkprof report, but much more detailed with
# lots of embedded analysis.
#
# If the trace file was created by using event 10046 level 4, 8, 12 or
# DBMS_SUPPORT, wait and/or bind statistics will be included in the output
# report.
#
# To analyze the generated output file, start at the bottom and work your
# way back towards the top:
#
# 1) Examine the GRAND TOTAL SECS on the last 2 lines.  If the times are
#    very short, you can stop working with this trace file, as it does not
#    take a excessively long period of time to execute.
#
# 2) Examine the ORACLE TIMING ANALYSIS section right above the grand totals.
#    This shows where all of the time was spent while running the traced SQL.
#    This section may cause you to investigate system tuning events and/or
#    latches, if that is where the majority of the time is being spent.
#    (If the ORACLE TIMING ANALYSIS section is missing, this indicates that
#    all operations were completed in less than .01 seconds).
#
# 3) If most of the time was spent in events related to the actual SQL being
#    traced, then examine the SUMMARY OF TOTAL CPU TIME, ELAPSED TIME, WAITS,
#    AND I/O PER CURSOR (SORTED BY DESCENDING ELAPSED TIME) section.  This
#    sorts the individual cursors, in descending order of their total
#    contribution of elapsed time to the total time for the entire trace.
#    Usually, one or two of the cursors are disproportinately large, showing
#    that the majority of time is spent during one of those cursors.  For
#    each cursor ID (listed in the first column), go back and look at the
#    detail for that cursor, as listed earlier in the report.  The rest of
#    the report lists each of the cursors, in ascending order of cursor ID.
#    (A quick way to locate a specific cursor is to search for a pound sign
#    (#) followed by the cursor ID number.  For example, if Cursor ID 12 is
#    the one taking the most time, then search for "#12" to locate the
#    detail for that specific cursor.
#
# 4) For each cursor ID, the trace file will include the actual SQL executed
#    for that cursor, any bind values that were passed, and counts and times
#    for all parses, executes, and fetches.  This lets you see how much work
#    that cursor performed, and how much time that took.
#
#    For disk I/O operations, an average time to read one block, in
#    milliseconds, is printed.
#
#    A summary list of any wait events is given, showing the length of time per
#    wait, along with any relevant data file number and block number.  As of
#    Oracle 10gR2, if present, wait event summaries are also further summarized
#    by each unique object ID.
#
#    For disk I/O operations, a disk read time histogram report is printed.
#    This shows the number of reads and blocks, for different time buckets.
#    This easily lets you see if the disk I/O is being performed quickly or
#    slowly, and where most of the disk I/O time is being spent.
#
#    Assuming the cursor is closed, the rows source operations and row counts
#    will also be listed.
#
#    As of Oracle 9iR2, if present, segment-level statistics are also listed in
#    the report, so you can measure the counts and times for each individual
#    segment.  
#
# The above analysis enables you to easily, quickly, and accurately pinpoint
# the cause of any excessive time spent while executing a SQL statement (or
# PL/SQL package, procedure, or function).
#
# This script is very efficient - It can processes approximately 5.5 to 10 meg
# of trace file data per minute (depending on the number of cursors and the
# number of wait events in the trace file).  (It has been tested with up to a
# 540 MB trace dump file).
#
# NOTES:
#
# Bug 3009359 in Oracle 9.2.0.3 and 9.2.0.4: Setting SQL_TRACE to TRUE (or
# using the 10046 event) causes excessive CPU utilization when row source
# statistics are collected.  Caused by the fix for Oracle bug 2228280 in
# 9.2.0.3.  Fixed in 9.2.0.5, 10.1.0.2.
#
# The TIMED_STATISTICS init.ora parameter should be set to TRUE.  Without
# this, all of the critically important timing data will be omitted from the
# resulting trace file.  (This is a dynamic parameter, which can be set via
# ALTER SESSION or ALTER SYSTEM).
#
# The MAX_DUMP_FILE_SIZE parameter limits the maximum size of a trace dump
# file.  As database intensive operations can generate up to 1meg of trace
# data per second, this parameter must set be high enough, so that the trace
# file is not truncated.  (This is also a dynamic parameter, which can be set
# via ALTER SESSION or ALTER SYSTEM).
#
# To perform an actual trace, after ensuring that the preceding two init.ora
# parameters have been set, issue the following command for the session that
# is to be traced:
#
#	ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';
#
# Then, execute the SQL (or package, procedure, or function) to be traced.
#
# When the SQL finishes, stop the trace by issuing the following command (or
# terminate the SQL session):
#
#	ALTER SESSION SET EVENTS '10046 trace name context off';
#
# The resulting trace file will be found in the 'user_dump_dest' directory.
# Typically, it's the last file in that directory (when sorted by date).
# This is the input file name to be used with this script.
#
# Note:  If a session has an open 10046 trace file, you can force it to be
#        closed by typing:
#		sqlplus "/ as sysdba"
#		oradebug setospid <pid>
#			(where <pid> is the operating system PID of the process
#			 which has the open trace file)
#		oradebug close_trace
#
# Parameters:
# $1 = Oracle Trace Dump File to to analyzed.
# $2 = (optional) Specify any value to enable debug mode.
#
# This script has been tested on the following Oracle and O/S versions:
#
#	Oracle 8.1.5, 8.1.7.4, 9.2.0.4, 9.2.0.5, 9.2.0.6, 10.1.0.2, 10.2.0.1,
#	11.1.0.6, 11.1.0.7
#
#	AIX 5.2
#	HP-UX 11.11, 11.23
#	Linux 2.6.12, 2.6.16, 2.6.18.8-0.7, 2.6.21, 2.6.24-19
#	Solaris 9
#
#	(This script should be O/S-independent.  Its only dependency is
#	 the version of awk or nawk that is being used.  Different O/S
#	 implementations may limit your process address space to a
#	 different amount.  If there is insufficient process memory
#	 available, this script may run much slower than on other O/S
#	 platforms.  Ensure that your 'ulimit' parameters are as high
#	 as possible.)
#
# Copyright (c) 2006, 2007, 2008, 2009 by Brian Lomasky, DBA Solutions, Inc.
#
# The latest version of trace_report can always be found on the web site:
# http://www.dbasolutionsinc.com
#
# The author can be contacted at: lomasky@dbasolutionsinc.com
#
# <<<<<<<<<< MODIFICATION HISTORY >>>>>>>>>>
# 02/09/09	Brian Lomasky	Include module and action detail and subtotals.
#				  Add missing cursor total.  Do not round
#				  cursor wait event totals.
# 12/10/08	Brian Lomasky	Handle 11.1.0.7 trace file format (CLOSE #n,
#				  plh).
# 10/15/08	Brian Lomasky	Reformat "n more wait events..." lines to not
#				  wrap.  Change Disk Read Histogram heading and
#				  calculation to use ms/reads instead of
#				  ms/block.
# 07/16/08	Brian Lomasky	Skip dupl header warning when finding a hint.
# 06/02/08	Brian Lomasky	Fix error when ordering rowsource STAT lines.
# 04/29/08	Brian Lomasky	Skip "us" after time parameter in STAT line.
# 11/14/07	Brian Lomasky	Print same GRAND TOTAL SECS:, even if zero secs.
#				  Change "Cursor ID" in report to "ID".
#				  Accum waits with no following cursor to the
#				  previous matching cursor.  Add warning and
#				  ignore timing gaps when trace file header is
#				  duplicated.  Adjust grand total secs if
#				  multiple headers found.
# 10/23/07	Brian Lomasky	Fix for missing heading for wait time by cursor
#				  totals.  Reformat segment-level statistics
#				  detail line.
# 10/12/07	Brian Lomasky	Handle 11.1.0.6 Client ID, SQL ID, Segment stats
#				  cost, size, and cardinality.
# 08/08/07	Brian Lomasky	Handle all null bind values.
# 07/04/07	Brian Lomasky	Print total number of bind values found in the
#				  trace file.  Include any null bind values.
#				  Wrap long bind values.
# 12/07/06	Brian Lomasky	Handle onlined undo segments.  Rename timing gap
#				  variables for debugging.
# 12/06/06	Brian Lomasky	Fix File Number/Block Number calculation.  Add
#				  total wait events by cursor totals.  Include
#				  cursor ID 0.
# 11/16/06	Brian Lomasky	Include Partition Start and Partition End stats.
#				  Fix line percentage calculation.
#				  Print text if TRACE DUMP CONTINUES IN FILE or
#				  TRACE DUMP CONTINUED FROM FILE found.
# 09/27/06	Brian Lomasky	Include SQL hash values.  Handle RPC CALL,
#				  RPC BIND, RPC EXEC for Oracle Forms clients.
#				  Cleanup /tmp files.  Limit cursor debug to
#				  every 10 cursors.  Include automatic DOS->Unix
#				  file conversion.  Fix bind value extraction.
# 09/19/06	Brian Lomasky	Handle embedded "no oacdef" for bind variables.
# 08/02/06	Brian Lomasky	Fix max cursor number debug info.  Fixed line
#				  counter.
# 07/20/06	Brian Lomasky	Optimize performance for pending wait lookups
#				  and large directories.  Enhance debugging.
# 07/10/06	Brian Lomasky	Certify for AIX 5.2.
# 06/22/06	Brian Lomasky	Include summary of block revisits by file numb.
# 05/18/06	Brian Lomasky	Include oradebug info in comments.
# 04/17/06	Brian Lomasky	Workaround for HP-UX awk restriction of more
#				  than 199 columns:  Replace embedded spaces
#				  around any "." and before any ",".
# 03/20/06	Brian Lomasky	Include summary of block revisits, explanation
#				  of why scattered read blocks may be less than
#				  db_file_multiblock_read_count.  Include 10.2
#				  object numbers.  Certify for Oracle versions
#				  8.1.5, 8.1.7.4, 9.2.0.5, 10.1.0.2.  Embedded
#				  instructions.
# 03/15/06	Brian Lomasky	Skip any embedded memory dumps.  Skip any
#				  wrapped bind values.  Handle new format of
#				  10.2 wait event parameters.
# 03/05/06	Brian Lomasky	Modify WAIT parameter parsing.  Convert
#				  microsecond times to centiseconds to
#				  avoid 32-bit limitations and scientific
#				  notation conversion.
# 03/03/06	Brian Lomasky	Added grand total debug info.  Fixed unwanted
#				  scientific notation format for large total
#				  elapsed times.  Rewrite grand totals.
#				  Certified for Linux 2.6.12.
# 02/07/06	Brian Lomasky	Document TRACE DUMP CONTINUES IN FILE text.
#				  Ensure parsing values are treated as numerics.
# 10/26/05	Brian Lomasky	Change heading for Disk Read Histogram Summary
#				  to indicate read time in secs is for blocks.
#				  Skip XCTEND and STAT if no hash value found.
# 08/31/05	Brian Lomasky	Support 10.2 modified bind syntax.
# 08/15/05	Brian Lomasky	Read /etc/profile instead of /etc/passwd, in
#				  case /etc/passwd is read-protected.
# 07/19/05	Brian Lomasky	Print additional status messages.
# 07/12/05	Brian Lomasky	Handle appended trace files.
# 06/13/05	Brian Lomasky	Summarize significant wait events.
# 06/05/05	Brian Lomasky	Accum wait events by P3 param.  Include
#				  disk read histogram throughput.  Fix bug
#				  for skipped wait times < 1ms.  Add max and
#				  avg ms per wait event.  Add wait event hist.
# 06/01/05	Brian Lomasky	Fix total lines counter.  Print only one
#				  truncate warning.  Handle 10.1 ACTION NAME, 
#				  MODULE NAME, SERVICE NAME, QUERY, bind
#				  peeking, optimizer parameters, Column usage
#				  monitoring, QUERY BLOCK SIGNAGE,
#				  BASE STATISTICAL INFORMATION, COLUMN, Size,
#				  Histogram, SINGLE TABLE ACCESS PATH, STAT
#				  pr= and pw= values, "Oracle Database" header.
#				  Skip non-10046 trace files.  Include any PQO
#				  waits in Oracle Timing Events.  Include count
#				  of waits and avg ms per wait to subtotals.
# 03/12/05	Brian Lomasky	Fix wait order bug, bind order bug, double-
#				  counted recursive totals.  Add unaccounted-for
#				  time, timing gap errors, gap processing,
#				  bind variable reporting format, timing
#				  summary.
# 02/08/05	Brian Lomasky	Added subtotals and percents to grand total.
#				  Handle bind variables with embedded blanks.
#				  Print 2 lines for very long bind values.
# 01/25/05	Brian Lomasky	Include unaccounted for waits or errors (in the
#				  event a trace was started in the middle of a
#				  session).  Include avg time to read a block.
#				  Include read time histogram summary per
#				  cursor.
# 08/10/04	Brian Lomasky	Added warning about truncated dump file.
# 08/02/04	Brian Lomasky	Added additional debug mode info.  Ignore error
#				  time, since it may be more than 2gig.  Fix
#				  for no recursive depth for cursor zero.
# 06/01/04	Brian Lomasky	Fix next error within do_parse.  Add missing
#				  percent and comma in elapsed time total.
# 01/30/04	Brian Lomasky	Include cursor 0.  Added debug mode.  Skip
#				  lines which have a non-existent cursor,
#				  except for cursor #0 (to handle a partial
#				  trace file).
# 11/23/03	Brian Lomasky	Change filtering and format of wait events.
# 11/20/03	Brian Lomasky	Handle embedded tilde in object name.  Handle
#				  out of order bind values.  Fix error in grand
#				  total time calc.  Fix too long awk command.
#				  Omit SQL*Net message from client from grand
#				  total non-idle wait events.
# 10/29/03	Brian Lomasky	Include Oracle 9.2 segment-level statistics.
# 06/24/03	Brian Lomasky	Include parse error values.  Handle zero hv.
#				  Accum duplicate waits into one line.  Skip
#				  waits for cursor 0.
# 06/11/03	Brian Lomasky	Include bind values.  Skip waits for 0 time.
#				  Add descending sort by elapsed fetch times.
# 04/02/03	Brian Lomasky	Add sub total by wait events per cursor.
# 03/17/03	Brian Lomasky	Optimize speed.  Calc proper divisor for Oracle
#				  9.0+ timings.  Use nawk instead of awk, if
#				  available.  Add grand total elapsed times.
#				  Add sorted elapsed time summary.  Include
#				  non-idle wait event detail and summary, latch
#				  detail, enqueue detail.  Handle truncated
#				  trace files.  Check for gap.  Check for
#				  unexpected lines.
# 07/12/01	Brian Lomasky	Original
#
# Note: If the input trace file contains:
#	*** TRACE DUMP CONTINUES IN FILE /file ***
#	*** TRACE DUMP CONTINUED FROM FILE /file ***
# this usually means that an "ALTER SESSION SET TRACEFILE_IDENTIFIER = 'xxx';"
# command was issued.  The file names listed reference the prior and/or next
# file which contains the contents of the trace.
#
# This is also caused by using MTS shared servers.  As the traces are performed
# by the server processes, you can get a piece of the trace in each of the
# background processes which execute your SQL.  To create a valid file for
# trace_report to process, you should combine the multiple pieces into a single
# trace file, or use the trcsess utility (as of Oracle 10.1).
#
# If the same file is listed in "TRACE DUMP CONTINUES IN FILE" and "TRACE DUMP
# CONTINUED FROM FILE", this is usually caused by trying to set a
# tracefile_identifier while using MTS.  Since setting a tracefile_identifier
# does not work under MTS, it is possible that these messages are due to
# someone attempting to set a tracefile identifier, and Oracle calling the
# "TRACE DUMP CONTINUES IN FILE" and "TRACE DUMP CONTINUED FROM FILE" routines
# without actually changing the filename.
#
if [ $# -eq 0 ]
then
	echo "Error - You must specify the trace dump file as a parameter" \
		"- Aborting..."
	exit 2
fi
if [ ! -r $1 ]
then
	echo "Error - Can't find file: $1 - Aborting..."
	exit 2
fi
grep 'PARSING IN CURSOR' $1 > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "Error - File $1 is not from a 10046 trace - Skipping..."
	exit 2
fi

if [ $# -eq 2 ]
then
	debug=1
else
	debug=0
fi
#
# See if nawk should be used instead of awk
#
(nawk '{ print ; exit }' /etc/profile) > /dev/null 2>&1
if [ ${?} -eq 0 ]
then
	cmd=nawk
else
	cmd=awk
fi
# Execute whoami in a subshell so as not to display a "not found" error message
( whoami ) > /dev/null 2>&1
if [ $? -eq 0 ]
then
	tmpf="/tmp/`whoami`$$"
else
	( /usr/ucb/whoami ) > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		tmpf="/tmp/`/usr/ucb/whoami`$$"
	else
		if [ -z "$LOGNAME" ]
		then
			tmpf="/tmp/`logname`$$"
		else
			tmpf="/tmp/${LOGNAME}$$"
		fi
	fi
fi
outf=`basename $1 .trc`.lst
cat /dev/null > $outf
rm -Rf $tmpf
mkdir $tmpf
mkdir $tmpf/errors
mkdir $tmpf/module
mkdir $tmpf/action
mkdir $tmpf/parse
mkdir $tmpf/parse/0
mkdir $tmpf/parse/1
mkdir $tmpf/parse/2
mkdir $tmpf/parse/3
mkdir $tmpf/parse/4
mkdir $tmpf/parse/5
mkdir $tmpf/parse/6
mkdir $tmpf/parse/7
mkdir $tmpf/parse/8
mkdir $tmpf/parse/9
mkdir $tmpf/binds
mkdir $tmpf/rpcbinds
mkdir $tmpf/rpccpu
mkdir $tmpf/params
mkdir $tmpf/sqls
mkdir $tmpf/sqls/0
mkdir $tmpf/sqls/1
mkdir $tmpf/sqls/2
mkdir $tmpf/sqls/3
mkdir $tmpf/sqls/4
mkdir $tmpf/sqls/5
mkdir $tmpf/sqls/6
mkdir $tmpf/sqls/7
mkdir $tmpf/sqls/8
mkdir $tmpf/sqls/9
mkdir $tmpf/stats
mkdir $tmpf/stats/0
mkdir $tmpf/stats/1
mkdir $tmpf/stats/2
mkdir $tmpf/stats/3
mkdir $tmpf/stats/4
mkdir $tmpf/stats/5
mkdir $tmpf/stats/6
mkdir $tmpf/stats/7
mkdir $tmpf/stats/8
mkdir $tmpf/stats/9
mkdir $tmpf/waits
mkdir $tmpf/waits/0
mkdir $tmpf/waits/1
mkdir $tmpf/waits/2
mkdir $tmpf/waits/3
mkdir $tmpf/waits/4
mkdir $tmpf/waits/5
mkdir $tmpf/waits/6
mkdir $tmpf/waits/7
mkdir $tmpf/waits/8
mkdir $tmpf/waits/9
mkdir $tmpf/waitblocks
mkdir $tmpf/waitsopend
mkdir $tmpf/waitsopend/0
mkdir $tmpf/waitsopend/1
mkdir $tmpf/waitsopend/2
mkdir $tmpf/waitsopend/3
mkdir $tmpf/waitsopend/4
mkdir $tmpf/waitsopend/5
mkdir $tmpf/waitsopend/6
mkdir $tmpf/waitsopend/7
mkdir $tmpf/waitsopend/8
mkdir $tmpf/waitsopend/9
cat /dev/null > $tmpf/cmdtypes
cat /dev/null > $tmpf/cursors
cat /dev/null > $tmpf/init
cat /dev/null > $tmpf/eof
cat /dev/null > $tmpf/elap
cat /dev/null > $tmpf/fetch
cat /dev/null > $tmpf/duplheader
cat /dev/null > $tmpf/modules
cat /dev/null > $tmpf/actions
echo 0 > $tmpf/truncated
cat /dev/null > $tmpf/waitsela
cat /dev/null > $tmpf/waits/t
cat /dev/null > $tmpf/waits/totcur
cat /dev/null > $tmpf/waits/totmod
cat /dev/null > $tmpf/waits/totact
mkdir $tmpf/xctend
cat <<EOF > trace_report.awk
BEGIN {
	abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	module = " "
	action = " "
	all_cursors = 0
	all_wait_tot = 0
	parsing = 0
	binds = 0
	header = 0
	offset_time = 0
	rpc_binds = 0
	peeked = "    "
	oacdef = 0
	found9999 = 0
	hv = 0
	stored_zero = 0
	abort_me = 0
	gap_time = 0
	gap_cnt = 0
	prev_time = 0
	parameters = 0
	printed_head = 0
	skip_to_equal = 0
	skip_dump = 0
	skip_to_nonquo = 0
	unacc_total = 0
	unacc_cnt = 0
	rpc_call = 0
	rpcndx = 0
	rpc_zero = ""
	cpu_timing_parse = 0
	cpu_timing_exec = 0
	cpu_timing_rpcexec = 0
	cpu_timing_fetch = 0
	cpu_timing_unmap = 0
	cpu_timing_sort = 0
	cpu_timing_close = 0
	cpu_timing_parse_cnt = 0
	cpu_timing_exec_cnt = 0
	cpu_timing_rpcexec_cnt = 0
	cpu_timing_fetch_cnt = 0
	cpu_timing_unmap_cnt = 0
	cpu_timing_sort_cnt = 0
	cpu_timing_close_cnt = 0
	multi_line_value = 0
	maxlastcur = 0
	ncur = 0
	next_line_bind_value = 0
	npend = 0
	prevdep = 999
	reccpu = 0
	recela = 0
	hash_ndx = 0
	divisor = 1				# Centiseconds
	uid = ""
	oct = ""
	dmi[1] = 31
	dmi[2] = 31
	dmi[3] = 30
	dmi[4] = 31
	dmi[5] = 31
	dmi[6] = 30
	dmi[7] = 31
	dmi[8] = 31
	dmi[9] = 30
	dmi[10] = 31
	dmi[11] = 30
	dmi[12] = 31
	first_time = 0
	prev_tim = 0
	last_tim = 0
	pct = 0
	print_trunc = 0
} function ymdhms(oratim) {
	nyy = yy + 0
	nmm = mm + 0
	ndd = dd + 0
	nhh = hh + 0
	nmi = mi + 0
	nss = ss + int((oratim - first_time) / 100)
	while (nss > 59) {
		nss = nss - 60
		nmi = nmi + 1
	}
	while (nmi > 59) {
		nmi = nmi - 60
		nhh = nhh + 1
	}
	while (nhh > 23) {
		nhh = nhh - 24
		ndd = ndd + 1
	}
	if (nmm == 2) {
		if (nyy == 4 * int(nyy / 4)) {
			if (nyy == 100 * int(nyy / 100)) {
				if (nyy == 400 * int(nyy / 400)) {
					dmi[2] = 29
				} else {
					dmi[2] = 28
				}
			} else {
				dmi[2] = 29
			}
		} else {
			dmi[2] = 28
		}
	}
	while (ndd > dmi[nmm]) {
		ndd = ndd - dmi[nmm]
		nmm = nmm + 1
	}
	while (nmm > 12) {
		nmm = nmm - 12
		nyy = nyy + 1
	}
	return sprintf("%2.2d/%2.2d/%2.2d %2.2d:%2.2d:%2.2d", \\
		nmm, ndd, nyy, nhh, nmi, nss)
} function find_cursor() {
	lcur = curno + 1
	if (lcur > maxlastcur) {
		for (i=maxlastcur+1;i<=lcur;i++) lastcur[i] = 0
		maxlastcur = lcur
	}
	# lastcur stores hash value array index for each cursor number (offset
	# by 1 to handle cursor number 0)
	xx = lastcur[lcur]
	# print "  Line " NR ": Cursor " curno " hash index is " xx \\
	#	" hash=" hv
	if (xx == 0) {
		if (curno == 0 && ncur == 0) {
			++ncur
			hashvals[ncur] = 0
			curnos[ncur] = 0
			octs[ncur] = "0"
			sqlids[ncur] = "."
			uids[ncur] = "x"
			deps[ncur] = 0
			gap_tims[ncur] = 0
			fil = tmpf "/cursors"
			if (debug != 0) print "  Storing cursor #0 in array " \\
				ncur
			print "   0 0 0 x x 0 0 0 x 0 ." >> fil
			close(fil)
			hv = 0
			oct = "0"
			uid = "x"
			cpu = 0
			elapsed = 0
			disk = 0
			query = 0
			current = 0
			rows = 0
			misses = 0
			op_goal = 0
			sqlid = "."
			tim = 0
			stored_zero = 1
		} else {
			#
			# Init array elements for "unaccounted for" time
			#
			hashvals[9999] = 1
			curnos[9999] = 0
			octs[9999] = "0"
			sqlids[9999] = "."
			uids[9999] = "x"
			deps[9999] = 0
			gap_tims[9999] = 0
			if (found9999 == 0) {
				fil = tmpf "/cursors"
				if (debug != 0) print "  Storing cursor #9999"
				print "9999 0 1 x x 0 0 0 x 0 ." >> fil
				close(fil)
				found9999 = 1
			}
			hv = 1
			oct = "0"
			uid = "x"
			xx = 9999
			lastcur[lcur] = 9999
		#	print "**** Bad data in file? - No matching cursor" \\
		#		" for " curno " on line " NR " ****"
		#	print "**** on line " \$0
		}
	} else {
		hv = hashvals[xx]
		oct = octs[xx]
		sqlid = sqlids[xx]
		uid = uids[xx]
		gap_tim = gap_tims[xx]
	}
	return xx
} function check_lins() {
	lins = lins + 1
	if (10 * lins > totlins) {
		if (debug != 0) print "  lins=" lins " totlins=" totlins
		pct = pct + 10
		print "Processed " pct "% of all trace file data..."
		lins = 1
	}
} function move_curno_waits() {
	# Move prior waits to this cursor (since WAITS usually occur before any
	# PARSING/PARSE/EXEC/FETCH/CLOSE operation)
	if (debug != 0) {
		if (all_cursors == 0) {
			print "  Move pending waits for curno " curno
		} else {
			print "  Move pending waits for all cursors"
		}
	}
	wait_sub_total = 0
	x = 0
	while (x < npend) {
		++x
		if (pends[x] == curno || all_cursors == 1) {
			if (debug != 0) print "    Move pending wait " x "/" \\
				npend
			# If processing any waits with no following cursor:
			if (all_cursors == 1) {
				# Locate last matching cursor number
				xxx = ncur
				while (xxx > 1 && curnos[xxx] != pends[x]) {
					--xxx
				}
				if (curnos[xxx] == pends[x]) {
					hv = hashvals[xxx]
					if (debug != 0) print "    Found" \\
						" pending wait for curno " \\
						pends[x]
				} else {
					print "*** Skipping non-matching" \\
						" cursor " pends[x]
					continue
				}
			}
			if (pends[x] == 0) hv = "0"
			fil = tmpf "/waits/" substr(hv,1,1) "/" hv
			curfil = tmpf "/waits/pend" pends[x]
			while (getline < curfil > 0) {
				print \$0 >> fil
				elem = split(\$0, arr, "~")
				wait_sub_total = wait_sub_total + arr[5]
				if (debug != 0) {
					print "    Accum wait event " arr[1] \\
						" Time: " arr[5] " hv=" hv \\
						" NR=" NR
				}
			}
			close(fil)
			close(curfil)
			system("rm -f " tmpf "/waits/pend" pends[x])
			if (debug != 0) print "    Subtotal waits = " \\
				wait_sub_total
			fil = tmpf "/waitsopend/" substr(hv,1,1) "/" hv
			curfil = tmpf "/waits/objpend" pends[x]
			while (getline < curfil > 0) {
				print \$0 >> fil
			}
			close(fil)
			close(curfil)
			system("rm -f " tmpf "/waits/objpend" pends[x])
			if (all_cursors == 0) {
				if (x < npend) pends[x] = pends[npend]
				delete pends[npend]
				npend = npend - 1
				x = npend
			} else {
				if (debug != 0) {
					print "    Store ela for" \\
						" wait without following" \\
						" cursor: " wait_sub_total \\
						" for curno " pends[x]
					print "    Gap time was " gap_time
				}
				# Not sure if this is accurate:
				gap_time = gap_time - wait_sub_total
				fil = tmpf "/waitsela"
				print wait_sub_total >> fil
				close(fil)
			}
		}
	}
} function do_parse() {
	# Check for null bind value
	if (next_line_bind_value == 1) {
		next_line_bind_value = 0
		if (binds == 1) {
			if (oacdef == 0) {
				fil = tmpf "/binds/" cur
				printf "%4s %11d    %-44s %10d\n", \\
					peeked, varno + 1, "<null>", NR >> fil
				close(fil)
				# Incr number of binds
				++bindvars[cur]
			}
		}
	}
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	binds = 0
	rpc_binds = 0
	peeked = "    "
	dep = 0
	oacdef = 0
	multi_line_value = 0
	pound = index(\$2, "#")
	colon = index(\$2, ":")
	curno = substr(\$2, pound + 1, colon - pound - 1)
	if (curno == 0 || ncur != 0) {
		cur = find_cursor()
		if (cur > 0) {
			op = \$1
			if (\$1 == "PARSE") op = "1"
			if (\$1 == "EXEC") op = "2"
			if (\$1 == "FETCH") op = "3"
			if (\$1 == "UNMAP") op = "4"
			if (\$1 == "SORT UNMAP") op = "5"
			if (\$1 == "CLOSE") op = "6"
			if (op == \$1) {
				print "Unexpected parameter for parse (" \$1 \\
					") found on line " NR
			} else {
				if (debug != 0) print "   Storing " \$1 \\
					" for curno " curno " in " cur \\
					", NR=" NR
				cpu = 0
				elapsed = 0
				disk = 0
				query = 0
				current = 0
				rows = 0
				misses = 0
				op_goal = 0
				plh = 0
				sqlid = "."
				tim = 0
				type = 0
				two = substr(\$2, index(\$2, ":") + 1)
				a = split(two, arr, ",")
				for (x=1;x<=a;x++) {
					equals = index(arr[x], "=")
					key = substr(arr[x], 1, equals - 1)
					if (key == "c") {
						if (divisor == 1) {
							# Already in
							# centiseconds
							cpu = substr(arr[x], \\
								equals + 1)
						} else {
							# Convert microseconds
							# to centiseconds
							l = length(arr[x])
							if (l - equals > 4) {
								cpu = substr(\\
								  arr[x], \\
								  equals + 1, \\
								  (l - \\
								  equals) \\
								  - 4) "." \\
								  substr(\\
								  arr[x], \\
								  (l - \\
								  equals) - 1)
							} else {
								# Less than .01
								# sec
								cpu = "0." \\
								  substr(\\
								  substr(\\
								  arr[x], 1, \\
								  2) "00000" \\
								  substr(\\
								  arr[x], 3), \\
								  (l - \\
								  equals) + 4)
							}
						}
						continue
					}
					# A database call e is approx equal to
					# its total CPU time plus the sum of
					# its wait event times
					if (key == "e") {
						if (divisor == 1) {
							elapsed = substr(\\
								arr[x], \\
								equals + 1)
						} else {
							l = length(arr[x])
							if (l - equals > 4) {
								elapsed = \\
								  substr(\\
								  arr[x], \\
								  equals + 1, \\
								  (l - \\
								  equals) \\
								  - 4) "." \\
								  substr(\\
								  arr[x], \\
								  (l - \\
								  equals) - 1)
							} else {
								elapsed = \\
								  "0." \\
								  substr(\\
								  substr(\\
								  arr[x], 1, \\
								  2) "00000" \\
								  substr(\\
								  arr[x], 3), \\
								  (l - \\
								  equals) + 4)
							}
						}
						if (index(elapsed, "+") != 0) {
							print "ERROR:" \\
								" SCIENTIFIC" \\
								" NOTATION" \\
								" FOR " elapsed
						}
						continue
					}
					if (key == "p") {
						disk = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "cr") {
						query = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "cu") {
						current = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "mis") {
						misses = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "r") {
						rows = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "dep") {
						dep = substr(arr[x], \\
							equals + 1)
						if (dep > deps[cur]) \\
							deps[cur] = dep
						continue
					}
					if (key == "og") {
						op_goal = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "plh") {
						plh = substr(arr[x], equals + 1)
						continue
					}
					if (key == "type") {
						type = substr(arr[x], \\
							equals + 1)
						continue
					}
					if (key == "tim") {
						if (divisor == 1) {
							tim = substr(\\
								arr[x], \\
								equals + 1)
						} else {
							l = length(arr[x])
							if (l - equals > 4) {
								tim = substr(\\
								  arr[x], \\
								  equals + 1, \\
								  (l - \\
								  equals) \\
								  - 4) "." \\
								  substr(\\
								  arr[x], \\
								  (l - \\
								  equals) + 1)
							} else {
								tim = "0." \\
								  substr(\\
								  substr(\\
								  arr[x], 1, \\
								  4) "00000" \\
								  substr(\\
								  arr[x], 5), \\
								  (l - \\
								  equals) + 7)
							}
						}
						if (debug != 0) {
							print "do_parse:" \\
								" Read tim= " \\
								tim
						}
						if (tim > last_tim) {
						    if (offset_time > 0) {
							if (debug != 0) {
							  print "do_parse:" \\
								" offset_time"\\
								tim - last_tim
							}
							first_time = \\
								first_time + \\
								tim - last_tim
							if (debug != 0) {
							  printf \\
							    "%s%s%12.4f\n", \\
							    "do_parse:", \\
							    " first_time: ", \\
							    first_time
							}
							offset_time = 0
						    }
						    if (debug != 0) {
							print "do_parse:" \\
								" last_tim= " \\
								last_tim \\
								" NR=" NR
						    }
						    last_tim = tim
						}
						continue
					}
					if (key == "sqlid") {
						sqlid = substr(arr[x], \\
							equals + 1)
						gsub(q,"",sqlid)
						continue
					}
					print "Unexpected parameter for parse"\\
						" found on line " NR ": " arr[x]
				}
				xx = move_curno_waits()
				# Calculate any timing gaps
				if (op == "1") {
					gap_tim = gap_tims[cur]
					gap_tims[cur] = 0
				} else {
					gap_tim = 0
				}
				if (prev_time > 0) {
					gap_tim = sprintf("%d", gap_tim + \\
						tim - (prev_time + \\
						elapsed + all_wait_tot))
				}
				# Zero if within timing degree of precision
				if (gap_tim < 2) gap_tim = 0
				if (gap_tim != 0) {
					if (debug != 0) {
						print "Gap Time err>tim=" tim \\
							", prev_time=" \\
							prev_time
						print "             " \\
							"elapsed=" elapsed \\
							", gap_tim=" gap_tim \\
							", all_wait_tot=" \\
							all_wait_tot ", NR=" NR
					}
					# Accum grand total timing gap
					gap_time = gap_time + gap_tim
					++gap_cnt
				}
				prev_time = tim
				# Calculate unaccounted-for time
				unacc = sprintf("%d", \\
					elapsed - (wait_sub_total + cpu))
				# Zero if within timing degree of precision
				if (unacc < 2) unacc = 0
				# Accum unaccounted-for time
				if (unacc > 0) {
					unacc_total = unacc_total + unacc
					++unacc_cnt
				}
				if (debug != 0) {
					if (unacc != 0) {
						printf "Unaccounted-for time" \\
							">curno=" curno \\
							", elapsed=" elapsed \\
							", waits=" \\
							wait_sub_total \\
							", cpu=" cpu ", NR=" NR
					}
				}
				# Accum total CPU timings
				if (op == "1") {
					cpu_timing_parse = cpu_timing_parse + \\
						cpu
					++cpu_timing_parse_cnt
				}
				if (op == "2") {
					cpu_timing_exec = cpu_timing_exec + \\
						cpu
					++cpu_timing_exec_cnt
				}
				if (op == "3") {
					cpu_timing_fetch = cpu_timing_fetch + \\
						cpu
					++cpu_timing_fetch_cnt
				}
				if (op == "4") {
					cpu_timing_unmap = cpu_timing_unmap + \\
						cpu
					++cpu_timing_unmap_cnt
				}
				if (op == "5") {
					cpu_timing_sort = cpu_timing_sort + \\
						cpu
					++cpu_timing_sort_cnt
				}
				if (op == "6") {
					cpu_timing_close = cpu_timing_close + \\
						cpu
					++cpu_timing_close_cnt
				}
				if (prevdep == dep || prevdep == 999) {
					# Accum cpu and elapsed times for all
					# recursive operations
					if (dep > 0) {
						if (cpu > 0 || elapsed > 0) {
							# Store cpu + elapsed
							# time for this
							# recursive call
							reccpu = reccpu + cpu
							recela = sprintf(\\
								"%d", \\
								recela + \\
								elapsed)
						}
					}
				} else {
					# Remove any double-counted recursive
					# times
					if (reccpu > 0 || recela > 0) {
						if (cpu >= reccpu) \\
							cpu = cpu - reccpu
						if (elapsed >= recela) \\
							elapsed = sprintf(\\
								"%d", \\
								elapsed - \\
								recela)
						reccpu = 0
						recela = 0
					}
				}
				prevdep = dep
				fil = tmpf "/parse/" substr(hv,1,1) "/" hv
				print op " " cpu " " elapsed " " disk " " \\
					query " " current " " rows " " misses \\
					" " op_goal " " tim " " unacc " " \\
					gap_tim " " sqlid >> fil
				close(fil)
				fil = tmpf "/cmdtypes"
				print oct " " cpu " " elapsed " " disk " " \\
					query " " current " " rows " " uid \\
					" " deps[cur] " " NR >> fil
				close(fil)
				if (module != " ") {
					fil = tmpf "/modules"
					print module "~" cpu "~" elapsed "~" \\
						disk "~" query "~" current \\
						"~" rows "~" uid "~" \\
						deps[cur] "~" NR >> fil
					close(fil)
				}
				if (action != " ") {
					fil = tmpf "/actions"
					print action "~" cpu "~" elapsed "~" \\
						disk "~" query "~" current \\
						"~" rows "~" uid "~" \\
						deps[cur] "~" NR >> fil
					close(fil)
				}
			}
		}
	}
	all_wait_tot = 0
} function do_parse_cursor() {
	skip_dump = 0
	skip_to_nonquo = 0
	binds = 0
	rpc_binds = 0
	peeked = "    "
	oacdef = 0
	multi_line_value = 0
	dep = 0					# Recursive depth
	uid = ""				# User ID
	oct = ""				# Oracle command type
	parsing_tim = 0				# Current Time
	hv = 0					# SQL hash value
	err = "x"				# Oracle error
	sqlid = "."
	for (x=first_field;x<=NF;x++) {
		equals = index(\$x, "=")
		if (equals > 0) {
			key = substr(\$x, 1, equals - 1)
			if (key == "len") continue
			if (key == "dep") {
				dep = substr(\$x, equals + 1)
				continue
			}
			if (key == "uid") {
				uid = substr(\$x, equals + 1)
				continue
			}
			if (key == "oct") {
				oct = substr(\$x, equals + 1)
				continue
			}
			if (key == "lid") continue
			if (key == "tim") {
				if (divisor == 1) {
					parsing_tim = substr(\$x, equals + 1)
				} else {
					l = length(\$x)
					if (l - equals > 4) {
						parsing_tim = substr(\$x, \\
							equals + 1, \\
							(l - equals) - 4) "." \\
							substr(\$x, (l - \\
							equals) + 1)
					} else {
						parsing_tim = "0." substr(\\
							substr(\$x, 1, 4) \\
							"00000" \\
							substr(\$x, 5), \\
							(l - equals) + 7)
					}
				}
				if (index(parsing_tim, "+") != 0) {
					print "ERROR: SCIENTIFIC NOTATION" \\
						" FOR PARSING TIME " parsing_tim
				}
				if (debug != 0) {
					print "do_parse_cursor: Read tim= " \\
						parsing_tim
				}
				if (parsing_tim > last_tim) {
				    if (offset_time > 0) {
					if (debug != 0) {
						  print "do_parse_cursor:" \\
							" offset_time: " \\
							parsing_tim - last_tim
					}
					first_time = first_time + parsing_tim \\
						- last_tim
					if (debug != 0) {
						printf "%s%s%12.4f\n", \\
							"do_parse_cursor:", \\
							" first_time: ", \\
							first_time
					}
					offset_time = 0
				    }
				    if (debug != 0) {
						print "do_parse_cursor:" \\
							" last_tim= " \\
							last_tim " NR=" NR
				    }
				    last_tim = parsing_tim
				}
				if (first_time == 0) {
					if (debug != 0) {
						print "store first_time: " \\
							parsing_tim " NR=" NR
					}
					first_time = parsing_tim
				}
				continue
			}
			if (key == "hv") {
				hv = substr(\$x, equals + 1)
				# Use parsing time if no hash value (Bug?)
				if (hv == 0) hv = parsing_tim
				continue
			}
			if (key == "ad") continue
			if (key == "err") {
				err = substr(\$x, equals + 1)
				continue
			}
			if (key == "sqlid") {
				sqlid = substr(\$x, equals + 1)
				gsub(q,"",sqlid)
				continue
			}
			print "Unexpected keyword of " key " in " \$0 \\
				" (line" NR ")"
		}
	}
	gap_tim = 0
	if (prev_time > 0) {
		# Calculate timing gap errors
		if (debug != 0) print "   Curr tim=" parsing_tim \\
			", last tim=" prev_time ", waits=" all_wait_tot \\
			" at NR=" NR
		gap_tim = parsing_tim - (prev_time + all_wait_tot)
		# Zero if within timing degree of precision
		if (gap_tim < 2) gap_tim = 0
		if (gap_tim != 0) {
			if (debug != 0) print "   Found Timing Gap " gap_tim
		}
	}
	if (prev_tim == 0) {
		elapsed_time = 0
	} else {
		elapsed_time = sprintf("%d", parsing_tim - prev_tim)
	}
	prev_tim = parsing_tim
	prev_time = parsing_tim
	all_wait_tot = 0
	# Accum cursors by hash value (as there can be multiple SQL statements
	#			       for a single cursor number)
	x = 0
	hash_ndx = 0
	while (x < ncur) {
		++x
		if (hashvals[x] == hv) {
			hash_ndx = x
			x = ncur
		}
	}
	if (hash_ndx == 0) {
		++ncur
		if (debug != 0) print "do_parse_cursor: Store New CURSOR #" \\
			curno " in " ncur
		cur = ncur
		hashvals[cur] = hv
		octs[cur] = oct
		sqlids[cur] = sqlid
		curnos[cur] = curno
		uids[cur] = uid
		deps[cur] = dep
		errs[cur] = err
		gap_tims[cur] = gap_tim
		bindvars[cur] = 0
		rpcbindvars[cur] = 0
		fil = tmpf "/cursors"
		printf "%4s %s %s %s %s %s %s %s %s %s %s\n", \\
			ncur, curno, hv, oct, uid, dep, elapsed_time, \\
			parsing_tim, err, NR, sqlid >> fil
		close(fil)
		if (module != " ") {
			if (debug != 0) print "do_parse_cursor: Store" \\
				" Module for CURSOR #" curno ": " module
			fil = tmpf "/module/" hv
			print module >> fil
			close(fil)
		}
		if (action != " ") {
			if (debug != 0) print "do_parse_cursor: Store" \\
				" Action for CURSOR #" curno ": " action
			fil = tmpf "/action/" hv
			print action >> fil
			close(fil)
		}
	} else {
		cur = hash_ndx
		if (debug != 0) print "do_parse_cursor: Use CURSOR #" \\
			curno " from " cur
		gap_tims[cur] = gap_tims[cur] + gap_tim
	}
	lcur = curno + 1
	if (lcur > maxlastcur) {
		if (debug != 0) print "do_parse_cursor: Zero " \\
			maxlastcur + 1 " to " lcur
		for (i=maxlastcur+1;i<=lcur;i++) lastcur[i] = 0
		maxlastcur = lcur
	}
	# print "  Store Cursor " lcur - 1 " hash " hv " index of " cur \\
	#	" on line " NR
	lastcur[lcur] = cur
	xx = move_curno_waits()
	return 0
} /^\/[A-Za-z]/ {
	if (abort_me == 2) next
	if (header == 0) {
		totlins = 10 * int((totlins + 9) / 10)
	}
	if (printed_head == 0) {
		print "Oracle Trace Dump File Report" >> outf
		print "" >> outf
		print "NOTE:  SEE THE TEXT AT THE TOP OF THE TRACE_REPORT" \\
			" SCRIPT FOR INSTRUCTIONS" >> outf
		print "       REGARDING HOW TO INTERPRET THIS REPORT!" >> outf
		print "" >> outf
		print "count       = Number of times OCI procedure was" \\
			" executed" >> outf
		print "cpu         = CPU time executing, in seconds" >> outf
		print "elapsed     = Elapsed time executing, in seconds" >> outf
		print "disk        = Number of physical reads of buffers" \\
			" from disk" >> outf
		print "query       = Number of buffers gotten for consistent" \\
			" read" >> outf
		print "current     = Number of buffers gotten in current" \\
			" mode (usually for update)" >> outf
		print "rows        = Number of rows processed by the fetch" \\
			" or execute call" >> outf
		print "" >> outf
		print "Trace File  = " \$1 >> outf
		printed_head = 1
	} else {
		print ""
		print "*** Warning: Multiple trace file headings are in the" \\
			" trace file!"
		print "             This will cause inaccuracies in the" \\
			" Elapsed Wall Clock Time"
		print "             calculation, as actual times are omitted" \\
			" in the trace file."
		print ""
		print "             The extra trace header starts on trace" \\
			" line " NR
		print ""
		# Zero previous time, so no timing gap will be calculated
		prev_time = 0
		# Zero time, so no elapsed time will be printed
		prev_tim = 0
		# Set flag to offset new first_time after new header
		if (first_time == 0) {
			offset_time = 0
		} else {
			offset_time = 1
		}
		fil = tmpf "/duplheader"
		print NR >> fil
		close(fil)
	}
	lins = 1
	next
} /^Dump file/ {
	if (abort_me == 2) next
	totlins = 10 * int((totlins + 9) / 10)
	if (printed_head == 0) {
		print "Oracle Trace Dump File Report" >> outf
		print "" >> outf
		print "NOTE:  SEE THE TEXT AT THE TOP OF THE TRACE_REPORT" \\
			" SCRIPT FOR INSTRUCTIONS" >> outf
		print "       REGARDING HOW TO INTERPRET THIS REPORT!" >> outf
		print "" >> outf
		print "count       = Number of times OCI procedure was" \\
			" executed" >> outf
		print "cpu         = CPU time executing, in seconds" >> outf
		print "elapsed     = Elapsed time executing, in seconds" >> outf
		print "disk        = Number of physical reads of buffers" \\
			" from disk" >> outf
		print "query       = Number of buffers gotten for consistent" \\
			" read" >> outf
		print "current     = Number of buffers gotten in current" \\
			" mode (usually for update)" >> outf
		print "rows        = Number of rows processed by the fetch" \\
			" or execute call" >> outf
		print "" >> outf
		print "Trace File  = " \$3 >> outf
		printed_head = 1
	}
	lins = 1
	next
} /^Oracle9/ {
	xx = check_lins()
	divisor = 10000				# Convert Microseconds to Centi
	next
} /^Oracle1/ {
	xx = check_lins()
	divisor = 10000				# Convert Microseconds to Centi
	next
} /^Oracle Database 9/ {
	xx = check_lins()
	divisor = 10000				# Convert Microseconds to Centi
	next
} /^Oracle Database 1/ {
	xx = check_lins()
	divisor = 10000				# Convert Microseconds to Centi
	next
} /^Node name:/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (header == 0) print "Node Name   = " \$3 >> outf
	next
} /^Instance name:/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (header == 0) print "Instance    = " \$3 >> outf
	next
} /^Unix process pid:/ {
	if (abort_me == 2) next
	xx = check_lins()
	x = \$6
	for(i=7;i<=NF;i++) x = x " " \$i
	print "Image       = " x >> outf
	next
} /^\*\*\*\*\*\*/ {
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	next
} /^==============/ {
	xx = check_lins()
	header = 1
	skip_to_equal = 0
	skip_dump = 0
	skip_to_nonquo = 0
	if (next_line_bind_value == 1) {
		next_line_bind_value = 0
		if (binds == 0) {
			print "Error - Found kxsbbbfp but no Bind# on trace" \\
				" line " NR ": " \$0
		} else {
			if (oacdef == 0) {
				fil = tmpf "/binds/" cur
				printf "%4s %11d    %-44s %10d\n", \\
					peeked, varno + 1, "<null>", NR >> fil
				close(fil)
				# Incr number of binds
				++bindvars[cur]
			}
		}
	}
	next
} /^Dump of memory/ {
	xx = check_lins()
	skip_dump = 1
	skip_to_nonquo = 0
	next
} /^\*\*\* ACTION NAME:/ {
	if (abort_me == 2) next
	xx = check_lins()
	x = index(\$0, "(")
	y = 0
	yx = 1
	while (yx > 0) {
		yx = index(substr(\$0, y + 1), ")")
		if (yx > 0) {
			y = yx + y
		}
	}
	if (header == 0) {
		if (y > x + 1) {
			print "Action      = " substr(\$0,x+1,y-x-1) >> outf
		}
	}
	if (y > x + 1) {
		action = substr(\$0,x+1,y-x-1)
		if (debug != 0) print "***** Found Action " action \\
			" on line " NR "..."
	}
	next
} /^\*\*\* MODULE NAME:/ {
	if (abort_me == 2) next
	xx = check_lins()
	x = index(\$0, "(")
	y = 0
	yx = 1
	while (yx > 0) {
		yx = index(substr(\$0, y + 1), ")")
		if (yx > 0) {
			y = yx + y
		}
	}
	if (header == 0) {
		if (y > x + 1) {
			print "Module      = " substr(\$0,x+1,y-x-1) >> outf
		}
	}
	if (y > x + 1) {
		module = substr(\$0,x+1,y-x-1)
		if (debug != 0) print "***** Found Module " module \\
			" on line " NR "..."
	}
	next
} /^\*\*\* SERVICE NAME:/ {
	if (abort_me == 2) next
	if (abort_me == 1) {
		print ""
		print "THIS TRACE FILE WAS APPENDED TO AN EARLIER CREATED" \\
			" TRACE FILE!"
		print ""
		print "MANUALLY EDIT THE TRACE FILE AND REMOVE THE EARLIER" \\
			" SECTION!"
		print ""
		next
	}
	++abort_me
	xx = check_lins()
	if (header == 0) {
		x = index(\$3, "(")
		y = index(\$3, ")")
		if (y > x + 1) print "Service     = " substr(\$3,x+1,y-x-1) \\
			>> outf
	}
	next
} /^\*\*\* SESSION ID:/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (header == 0) {
		x = index(\$3, "(")
		y = index(\$3, ")")
		print "Session ID  = " substr(\$3,x+1,y-x-1) >> outf
		print "Date/Time   = " \$4 " " \$5 >> outf
		start_date = \$4			# yyyy-mm-dd
		yy = substr(start_date, 1, 4)
		mm = substr(start_date, 6, 2)
		dd = substr(start_date, 9, 2)
		start_time = \$5			# hh:mm:ss.ccc
		hh = substr(start_time, 1, 2)
		mi = substr(start_time, 4, 2)
		ss = substr(start_time, 7, 2)
	}
	next
} /^\*\*\* CLIENT ID:/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (header == 0) {
		x = index(\$3, "(")
		y = index(\$3, ")")
		print "Client ID  = " substr(\$3,x+1,y-x-1) >> outf
	}
	next
} /^APPNAME/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (header == 0) {
		x = index(\$0, q)
		y = index(substr(\$0,x+1), q) + x
		if (y > x + 1) print "Application = " substr(\$0,x+1,y-x-1) \\
			>> outf
		zero = substr(\$0, y + 1)
		x = index(zero, q)
		y = index(substr(zero,x+1), q) + x
		if (y > x + 1) print "Action      = " substr(\$0,x+1,y-x-1) \\
			>> outf
	}
	next
} /^PARSING IN CURSOR/ {
	if (abort_me == 2) next
	xx = check_lins()
	peeked = "    "
	parameters = 0
	parsing = 1
	curno = \$4
	gsub("#","",curno)			# Cursor number
	if (debug != 0) print "***** Processing cursor #" curno " on line " \\
		NR "..."
	first_field = 5
	x = do_parse_cursor() \$0
	next
} /^QUERY/ {
	if (abort_me == 2) next
	xx = check_lins()
	# Try appending the query block to the end of the prior
	# PARSING IN CURSOR?
	skip_dump = 0
	skip_to_nonquo = 0
	parsing = 1
	next
} /^Column Usage Monitoring/ {
	if (abort_me == 2) next
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	skip_to_equal = 1
	next
} /^QUERY BLOCK SIGNAGE/ {
	if (abort_me == 2) next
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	skip_to_equal = 1
	next
} /^BASE STATISTICAL INFORMATION/ {
	if (abort_me == 2) next
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	skip_to_equal = 1
	next
} /^SINGLE TABLE ACCESS PATH/ {
	if (abort_me == 2) next
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	skip_to_equal = 1
	next
} /^Peeked values/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (debug != 0) print "  Processing bind peek #" curno " (cur " cur \\
		") on line " NR "..."
	binds = 1
	peeked = "Peek"
	oacdef = 0
	next_line_bind_value = 0
	multi_line_value = 0
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^PARAMETERS/ {
	if (abort_me == 2) next
	xx = check_lins()
	parameters = 1
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^RPC CALL:/ {
	if (abort_me == 2) next
	xx = check_lins()
	cur = find_cursor()
	if (debug != 0) print "  Processing rpc call #" curno " (hash index " \\
		cur ") on line " NR "..."
	rpc_zero = substr(\$0, 10)
	rpc_call = 1
	next
} /^RPC BINDS:/ {
	x = 0
	rpcndx = 0
	fil = tmpf "/rpccalls"
	while (getline < fil > 0) {
		++x
		if (\$0 == rpc_zero) rpcndx = x
	}
	close(fil)
	if (rpcndx == 0) {
		print rpc_zero >> fil
		close(fil)
		rpcndx = x + 1
	}
	rpc_call = 0
	if (abort_me == 2) next
	xx = check_lins()
	cur = find_cursor()
	if (debug != 0) print "  Processing rpc bind #" curno " (cur " cur \\
		") on line " NR "..."
	rpc_binds = 1
	peeked = "    "
	next_line_bind_value = 0
	oacdef = 0
	multi_line_value = 0
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^BINDS/ {
	if (abort_me == 2) next
	rpc_call = 0
	rpc_binds = 0
	xx = check_lins()
	curno = \$2
	gsub("#","",curno)			# Cursor number
	gsub(":","",curno)			# Cursor number
	cur = find_cursor()
	if (debug != 0) print "  Processing bind #" curno " (cur " cur \\
		") on line " NR "..."
	binds = 1
	peeked = "    "
	next_line_bind_value = 0
	oacdef = 0
	multi_line_value = 0
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^ bind / {
	if (abort_me == 2) next
	xx = check_lins()
	if (rpc_binds != 0) {
		varno = \$2
		gsub(":","",varno)		# Bind variable number
		equals = index(\$3, "=")
		# Data type(1=VARCHAR2,2=NUMBER,12=DATE)
		dty = substr(\$3, equals + 1)
		oacdef = 0
		skip_dump = 0
		skip_to_nonquo = 0
		if (index(\$0, "(No oacdef for this bind)") != 0) {
			# "No oacdef for this bind" indicates binding by name
			fil = tmpf "/rpcbinds/" rpcndx
			printf "%4s%s%4d%-38s%s%8d\n", \\
				" ", "Bind Number: ", varno + 1, \\
				"   (No separate bind buffer exists)", \\
				" Trace line: ", NR >> fil
			close(fil)
			oacdef = 1
			next
		}
		equals = index(\$0, "val=") + 3
		if (equals == 3) {
			print "No rpc bind value found on trace line " \\
				NR ": " \$0
			next
		}
		if (equals == length(\$0)) {
			multi_line_value = 1
		} else {
			if (substr(\$0, length(\$0) - 1) == "=\\"") {
				multi_line_value = 2
			} else {
				val = substr(\$0, equals + 1)
				if (debug != 0) print \\
					"  Bind value " val " on " NR
				if (substr(val, 1, 1) == "\\"") {
					quote = index(substr(val, 2), "\\"")
					if (quote != 0) {
						val = substr(val, 2, quote - 1)
					} else {
						skip_to_nonquo = 1
					}
				}
				if (skip_to_nonquo == 0) {
					if (debug != 0) print \\
						"  Store rpc bind[" varno \\
						"] value: " val \\
						" for rpcndx " rpcndx
					fil = tmpf "/rpcbinds/" rpcndx
					printf "%4s%s%4d%s%-25s%s%8d\n", \\
						" ", "Bind Number: ", \\
						varno + 1, \\
						" Bind Value: ", \\
						substr(val, 1, 25), \\
						" Trace line: ", NR >> fil
					if (length(val) > 25) {
						printf "%34s%-25s\n", " ", \\
							substr(\$0, 26, 25) \\
							>> fil
					}
					if (length(val) > 50) {
						printf "%34s%-25s\n", " ", \\
							substr(\$0, 51, 25) \\
							>> fil
					}
					close(fil)
					# Incr number of rpc binds
					++rpcbindvars[rpcndx]
				}
			}
		}
		next
	}
	if (binds == 0) {
		print "Unprocessed bind line on trace line " NR ": " \$0
		next
	}
	varno = \$2
	gsub(":","",varno)			# Bind variable number
	equals = index(\$3, "=")
	dty = substr(\$3, equals + 1)		# Data type(1=VARCHAR2,2=NUMBER)
	oacdef = 0
	if (index(\$0, "(No oacdef for this bind)") != 0) {
		# "No oacdef for this bind" indicates binding by name
		fil = tmpf "/binds/" cur
		printf "     %11d    %44s %10d\n", varno + 1, \\
			"(No separate bind buffer exists)", NR >> fil
		close(fil)
		oacdef = 1
	}
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^   bfp/ {
	if (abort_me == 2) next
	xx = check_lins()
	if (binds == 0) {
		print "Unprocessed bfp line on trace line " NR ": " \$0
		next
	}
	#if (oacdef == 0) {
	#	equals = index(\$0, "avl=") + 3
	#	space = index(substr(\$0, equals), " ")
	#	avl = substr(\$0, equals + 1, space - 2) + 0
	#}
	skip_dump = 0
	skip_to_nonquo = 0
	next
} /^ Bind#/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	# Check for null bind value
	if (next_line_bind_value == 1) next_line_bind_value = 0
	if (binds == 1) {
		if (oacdef == 0) {
			fil = tmpf "/binds/" cur
			printf "%4s %11d    %-44s %10d\n", \\
				peeked, varno + 1, "<null>", NR >> fil
			close(fil)
			# Incr number of binds
			++bindvars[cur]
		}
	}
	xx = check_lins()
	if (rpc_binds != 0) {
		pound = index(\$1, "#")
		varno = substr(\$1, pound + 1)	# Bind variable number
		next
	}
	if (binds == 0) {
		print "Unprocessed Bind line on trace line " NR ": " \$0
		next
	}
	pound = index(\$1, "#")
	varno = substr(\$1, pound + 1)		# Bind variable number
	next
} /^  No oacdef for this bind./ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (rpc_binds != 0) {
		# "No oacdef for this bind" indicates binding by name
		fil = tmpf "/rpcbinds/" rpcndx
		printf "%4s%s%4d%-38s%s%8d\n", \\
			" ", "Bind Number: ", varno + 1, \\
			"   (No separate bind buffer exists)", \\
			" Trace line: ", NR >> fil
		close(fil)
		oacdef = 1
		next
	}
	if (binds == 0) {
		print "Unprocessed no oacdef line on trace line " NR ": " \$0
		next
	}
	# "No oacdef for this bind" indicates binding by name
	fil = tmpf "/binds/" cur
	printf "     %11d    %44s %10d\n", varno + 1, \\
		"(No separate bind buffer exists)", NR >> fil
	close(fil)
	oacdef = 1
	next
} /^  oacdty=/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (rpc_binds != 0) {
		#equals = index(\$1, "=")
		# Data type(1=VARCHAR2,2=NUM,12=DATE)
		#dty = substr(\$1, equals + 1) + 0
		next
	}
	if (binds == 0) {
		print "Unprocessed oacdty line on trace line " NR ": " \$0
		next
	}
	#equals = index(\$1, "=")
	# Data type(1=VARCHAR2,2=NUMBER,12=DATE)
	#dty = substr(\$1, equals + 1) + 0
	next
} /^  oacflg=/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (rpc_binds != 0) next
	if (binds == 0) {
		print "Unprocessed oacflg line on trace line " NR ": " \$0
		next
	}
	next
} /^  kxsbbbfp=/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	next_line_bind_value = 1
	xx = check_lins()
	if (rpc_binds != 0) next
	if (binds == 0) {
		print "Unprocessed kxsbbbfp line on trace line " NR ": " \$0
		next
	}
	next
} /^PARSE ERROR #/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	parsing = 1
	if (debug != 0) print "  PARSE ERROR: " \$0 " on " NR
	curno = \$3
	gsub(":","",curno)			# Cursor number
	if (debug != 0) print "***** Processing cursor #" curno \\
		" error on line " NR "..."
	first_field = 4
	x = do_parse_cursor() \$0
	next
} /^==/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	parsing = 0
	parameters = 0
	next
} /^END OF STMT/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	parsing = 0
	parameters = 0
	next
} /^PARSE #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^EXEC #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^RPC EXEC:/ {
	if (abort_me == 2) next
	xx = check_lins()
	skip_dump = 0
	skip_to_nonquo = 0
	binds = 0
	rpc_binds = 0
	rpc_call = 0
	peeked = "    "
	oacdef = 0
	multi_line_value = 0
	if (curno == 0 || ncur != 0) {
		cur = find_cursor()
		if (cur > 0) {
			if (debug != 0) print "   Using curno " curno ", NR=" NR
			cpu = 0
			elapsed = 0
			two = substr(\$2, index(\$2, ":") + 1)
			a = split(two, arr, ",")
			for (x=1;x<=a;x++) {
				equals = index(arr[x], "=")
				key = substr(arr[x], 1, equals - 1)
				if (key == "c") {
					if (divisor == 1) {
						# Already in centiseconds
						cpu = substr(arr[x], \\
							equals + 1)
					} else {
						# Convert microseconds
						# to centiseconds
						l = length(arr[x])
						if (l - equals > 4) {
							cpu = substr(arr[x], \\
							  equals + 1, \\
							  (l - equals) - 4) \\
							  "." substr(arr[x], \\
							  (l - equals) - 1)
						} else {
							# Less than .01 sec
							cpu = "0." substr(\\
							  substr(arr[x], 1, \\
							  2) "00000" \\
							  substr(arr[x], 3), \\
							  (l - equals) + 4)
						}
					}
					continue
				}
				# A database call e is approx equal to
				# its total CPU time plus the sum of
				# its wait event times
				if (key == "e") {
					if (divisor == 1) {
						elapsed = substr(arr[x], \\
							equals + 1)
					} else {
						l = length(arr[x])
						if (l - equals > 4) {
							elapsed = \\
							  substr(arr[x], \\
							  equals + 1, \\
							  (l - equals) \\
							  - 4) "." \\
							  substr(arr[x], \\
							  (l - equals) - 1)
						} else {
							elapsed = "0." \\
							  substr(substr(\\
							  arr[x], 1, 2) \\
							  "00000" \\
							  substr(arr[x], 3), \\
							  (l - equals) + 4)
						}
					}
					if (index(elapsed, "+") != 0) {
						print "RPC ERROR: SCIENTIFIC" \\
							" NOTATION FOR " elapsed
					}
					continue
				}
				print "Unexpected parameter for rpc exec"\\
					" found on line " NR ": " arr[x]
			}
			# Accum total RPC CPU timings
			cpu_timing_rpcexec = cpu_timing_rpcexec + cpu
			++cpu_timing_rpcexec_cnt
			fil = tmpf "/rpccpu/" rpcndx
			print cpu " " elapsed >> fil
			close(fil)
		}
	}
	next
} /^FETCH #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^UNMAP #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^SORT UNMAP #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^CLOSE #/ {
	if (abort_me == 2) next
	x = do_parse() \$0
	next
} /^ERROR #/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	pound = index(\$2, "#")
	colon = index(\$2, ":")
	curno = substr(\$2, pound + 1, colon - pound - 1)
	cur = find_cursor()
	if (cur > 0) {
		zero = \$0
		gsub("= ","=",zero)
		errpos = index(zero, "err=")
		timpos = index(zero, "tim=")
		err = substr(zero, errpos + 4, timpos - 5 - errpos)
		if (divisor == 1) {
			# Already in centiseconds
			errti = substr(zero, timpos + 4)
		} else {
			# Convert microseconds to centiseconds
			l = length(zero)
			if (l - timpos > 7) {
				errti = substr(zero, timpos + 4, \\
					(l - timpos) - 7) "." \\
					substr(zero, l - 3)
			} else {
				errti = "0." substr(\\
					substr(zero, 1, 4) "00000" \\
					substr(zero, 5), (l - timpos) + 3)
			}
		}
		tim = parsing_tim + errti
		fil = tmpf "/errors/" hv
		print err "~" NR "~" tim >> fil
		if (debug != 0) print "    Write Error: " err " " \\
			NR " " tim " parsing_tim=" parsing_tim " errti=" errti
		close(fil)
	}
	next
} /^WAIT/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	pound = index(\$2, "#")
	colon = index(\$2, ":")
	curno = substr(\$2, pound + 1, colon - pound - 1)
	#if (debug != 0) print "Read WAIT event for cursor #" curno
	if (curno == 0) {
		if (stored_zero == 0) {
			++ncur
			hashvals[ncur] = 0
			curnos[ncur] = 0
			octs[ncur] = "0"
			sqlids[ncur] = "."
			uids[ncur] = "x"
			deps[ncur] = 0
			gap_tims[ncur] = 0
			fil = tmpf "/cursors"
			if (debug != 0) print "  Storing cursor #0 in array " \\
				ncur
			print "   0 0 0 x x 0 0 0 x 0 ." >> fil
			close(fil)
			if (module != " ") {
				fil = tmpf "/module/0"
				print module >> fil
				close(fil)
			}
			if (action != " ") {
				fil = tmpf "/action/0"
				print action >> fil
				close(fil)
			}
			hv = 0
			oct = "0"
			uid = "x"
			cpu = 0
			elapsed = 0
			disk = 0
			query = 0
			current = 0
			rows = 0
			misses = 0
			op_goal = 0
			sqlid = "."
			tim = 0
			stored_zero = 1
		}
	}
	cur = curno
	if (cur > 0) {
		# Set flag to indicate pending waits for this cursor exist
		x = 0
		xx = 0
		while (x < npend) {
			++x
			if (pends[x] == curno) {
				xx = 1
				x = npend
			}
		}
		if (xx == 0) {
			++npend
			pends[npend] = cur
			if (debug != 0) print "  Store wait for " cur \\
				" in pending array " npend
		}
	}
	if (cur >= 0) {
		zero = \$0
		if (debug != 0) print "zero=" zero
		gsub("= ","=",zero)
		nampos = index(zero, "nam=")
		elapos = index(zero, "ela=")
		if (debug != 0) print "elapos=" elapos
		nam = substr(zero, nampos + 5, elapos - 7 - nampos)
		ela = 0
		p1 = 0
		p2 = 0
		p3 = 0
		objn = 0
		wtim = 0
		fx = 0
		xx = 3
		parm = " "
		pno = 0
		if (debug != 0) print "  Read Wait Event: " \$0
		while (xx < NF) {
			++xx
			if (fx == 1) {
				fx = 0
				if (parm == "ela") {
					if (divisor == 1) {
						ela = \$xx
					} else {
						l = length(\$xx)
						if (l > 4) {
							ela = substr(\$xx, 1, \\
								l - 4) "." \\
								substr(\$xx, \\
								l - 3)
						} else {
							ela = "0." substr(\\
								"00000" \\
								\$xx, l + 2)
						}
					}
				} else {
					pno = pno + 1
					if (pno == 1) p1 = val
					if (pno == 2) p2 = val
					if (pno == 3) p3 = val
					if (substr(\$xx,1,5) == "obj#=") \\
						objn = substr(\$xx, 6)
					if (substr(\$xx,1,4) == "tim=") {
						if (divisor == 1) {
							wtim = substr(\$xx, 5)
						} else {
							l = length(\$xx)
							if (l > 8) {
								wtim = substr(\\
								    \$xx, 5, \\
								    l - 8) \\
								    "." \\
								    substr(\\
								    \$xx, \\
								    l - 3)
							} else {
								wtim = "0." \\
								    substr(\\
								    "00000" \\
								    \$xx, l + 2)
							}
						}
					}
				}
				if (parm == " ") {
					print "Unexpected WAIT parameter(" \\
						parm ") found on line " NR \\
						": " \$0
				}
				continue
			}
			equals = index(\$xx, "=")
			if (equals == 0) continue
			parm = substr(\$xx, 1, equals - 1)
			if (equals == length(\$xx)) {
				fx = 1
				continue
			}
			val = substr(\$xx, equals + 1)
			if (parm == "ela") {
				if (divisor == 1) {
					ela = val
				} else {
					l = length(val)
					if (l > 4) {
						ela = substr(val, 1, l - 4) \\
							"." substr(val, l - 3)
					} else {
						ela = "0." substr("00000" \\
							val, l + 2)
					}
				}
			} else {
				pno = pno + 1
				if (pno == 1) p1 = val
				if (pno == 2) p2 = val
				if (pno == 3) p3 = val
				if (substr(\$xx,1,5) == "obj#=") \\
					objn = substr(\$xx, 6)
				if (substr(\$xx,1,4) == "tim=") {
					if (divisor == 1) {
						wtim = substr(\$xx, 5)
					} else {
						l = length(\$xx)
						if (l > 8) {
							wtim = substr(\$xx, \\
								5, l - 8) \\
								"." \\
								substr(\$xx, \\
								l - 3)
						} else {
							wtim = "0." substr(\\
								"00000" \\
								\$xx, l + 2)
						}
					}
				}
			}
			fx = 0
		}
		if (debug != 0) {
			print "  Storing wait event: " nam ", ela=" ela \\
				", p1=" p1 ", p2=" p2 ", p3=" p3 ", objn=" \\
				objn ", wtim=" wtim
		}
		if (nam == "buffer busy waits") nam = nam " (code=" p3 ")"
		if (nam == "db file scattered read") nam = nam " (blocks=" \\
			p3 ")"
		if (nam == "latch activity") nam = nam " (latch#=" p2 ")"
		if (nam == "latch free") nam = nam " (latch#=" p2 ")"
		if (nam == "latch wait") nam = nam " (latch#=" p2 ")"
		if (nam == "enqueue") {
			# Convert P1 to hex
			if (p1 > 15) {
				val = p1
				v_mod = ""
				while (val > 15) {
					v_hex_mod = sprintf("%x", val % 16)
					v_mod = v_hex_mod v_mod
					val = int(val/16)
				}
				v_hex = sprintf("%x", val) v_mod
			} else {
				v_hex = sprintf("%x", p1)
			}
			c1 = (substr(v_hex,1,1) * 16 + substr(v_hex,2,1)) - 64
			c2 = (substr(v_hex,3,1) * 16 + substr(v_hex,4,1)) - 64
			name = substr(abc, c1, 1) substr(abc, c2, 1)
			mod = substr(v_hex, 5) + 0
			mode = "null"
			if (mod == 1) mode = "Null"
			if (mod == 2) mode = "RowS"
			if (mod == 3) mode = "RowX"
			if (mod == 4) mode = "Share"
			if (mod == 5) mode = "SRowX"
			if (mod == 6) mode = "Excl"
			nam = nam " (Name=" name " Mode=" mode ")"
		}
		if (ela != 0) {
			big_nr = sprintf("%12d", NR)
			if (curno == 0) {
				fil = tmpf "/waits/0/0"
				print nam "~" p1 "~" p2 "~" p3 "~" ela "~" \\
					big_nr "~" objn >> fil
				close(fil)
				fil = tmpf "/waitsopend/0/0"
				print nam "~" objn "~" p1 "~" p2 "~" p3 "~" \\
					ela "~" big_nr >> fil
				close(fil)
				wait_sub_total = wait_sub_total + ela
			} else {
				if (debug != 0) {
					print "  Storing pending waits for " \\
						cur ": " nam ", " ela
				}
				fil = tmpf "/waits/pend" cur
				print nam "~" p1 "~" p2 "~" p3 "~" ela "~" \\
					big_nr "~" objn >> fil
				close(fil)
				fil = tmpf "/waits/objpend" cur
				print nam "~" objn "~" p1 "~" p2 "~" p3 "~" \\
					ela "~" big_nr >> fil
				close(fil)
			}
			all_wait_tot = all_wait_tot + ela
			fil = tmpf "/waits/t"
			if (deps[cur] == "") deps[cur] = 0
			print nam "~" p1 "~" p2 "~" ela "~" uid "~" \\
				deps[cur] >> fil
			close(fil)
			fil = tmpf "/waits/totcur"
			printf "%10d~%-s~%d~%d~%s\n", \\
				cur, nam, p1, p2, ela >> fil
			close(fil)
			if (module != " ") {
				fil = tmpf "/waits/totmod"
				print module "~" nam "~" p1 "~" p2 "~" ela \\
					>> fil
				close(fil)
			}
			if (action != " ") {
				fil = tmpf "/waits/totact"
				print action "~" nam "~" p1 "~" p2 "~" ela \\
					>> fil
				close(fil)
			}
		}
	}
	next
} /^XCTEND/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (hv == 0) next
	parsing = 0
	parameters = 0
	xx = ymdhms(parsing_tim)
	xctrans = "transaction on trace line " NR " at " xx
	cflg = 0
	for (x=2;x<=NF;x++) {
		equals = index(\$x, "=")
		key = substr(\$x, 1, equals - 1)
		val = substr(\$x, equals + 1)
		if (key == "rlbk") {
			if (val != "0,") cflg = 1
		}
		if (key == "rd_only") {
			if (val != "0") {
				xctrans = "READ-ONLY " xctrans
			} else {
				xctrans = "UPDATE " xctrans
			}
		}
	}
	if (cflg == 0) {
		xctrans = "COMMIT " xctrans
	} else {
		xctrans = "ROLLBACK " xctrans
	}
	fil = tmpf "/xctend/" hv
	print xctrans >> fil
	close(fil)
	next
} /^\*\*\*/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (substr(\$0, 1, 6) == "*** DU") {
		fil = tmpf "/truncated"
		print 1 > fil
		close(fil)
		truncated = 1
		next
	}
	if (substr(\$0, 1, 5) == "*** 2") {
		#yy = substr(\$2, 1, 4)
		#mm = substr(\$2, 6, 2)
		#dd = substr(\$2, 9, 2)
		#hh = substr(\$3, 1, 2)
		#mi = substr(\$3, 4, 2)
		#ss = substr(\$3, 7, 2)
		# This line shows the completion date of the gap.
		# The gap duration is measured by the difference between the
		# prior tim= value and the next tim= value.
		# (Nothing seems to be needed, cause there is no missing time in
		#  the trace files I have seen)
		#print "******************* GAP found on trace line " NR
		#print \$0
		next
	}
	if (\$1 == "Undo" && \$2 == "Segment") next
	print "Unprocessed *** line on trace line " NR ": " \$0
	if (index(\$0, "TRACE DUMP CONTINUES IN FILE") > 0 || \\
		index(\$0, "TRACE DUMP CONTINUED FROM FILE") > 0) {
		print ">>> See the comments within trace_report for details!"
	}
} /^STAT/ {
	if (abort_me == 2) next
	skip_dump = 0
	skip_to_nonquo = 0
	xx = check_lins()
	if (hv == 0) next
	binds = 0
	rpc_binds = 0
	rpc_call = 0
	peeked = "    "
	multi_line_value = 0
	curno = \$2
	gsub("#","",curno)
	if (curno != 0 && ncur == 0) next
	cur = find_cursor()
	if (cur > 0) {
		parsing = 0
		parameters = 0
		row = 9999999999
		id = 0
		pid = 0
		desc = ""
		seg_cr = 0
		seg_r = 0
		seg_w = 0
		seg_time = 0
		part_start = 0
		part_stop = 0
		obj = "0"
		cost="."
		size="."
		card="."
		f = 0
		for (x=3;x<=NF;x++) {
			if (f == 1) {
				gsub(q,"",\$x)
				equals = index(\$x, "=")
				if (equals == 0) {
					if (\$x == "us") continue
					if (\$x == "us)") continue
					desc = desc " " \$x
				} else {
					if (obj != 0) {
						key = substr(\$x, 1, equals - 1)
						val = substr(\$x, equals + 1)
						if (key == "(cr") {
							seg_cr = val
							continue
						}
						if (key == "r" || key == "pr") {
							seg_r = val
							continue
						}
						if (key == "w" || key == "pw") {
							seg_w = val
							continue
						}
						if (key == "time") {
							seg_time = val
							continue
						}
						if (key == "START") {
							part_start = val
							continue
						}
						if (key == "STOP") {
							part_stop = val
							continue
						}
						if (key == "cost") {
							cost = int(val)
							continue
						}
						if (key == "size") {
							size = int(val)
							continue
						}
						if (key == "card") {
							card = int(val)
							continue
						}
						print "Unexpected parameter" \\
							" for stat found on" \\
							" line " NR ": " \$x
					}
				}
				continue
			}
			equals = index(\$x, "=")
			key = substr(\$x, 1, equals - 1)
			val = substr(\$x, equals + 1)
			if (key == "id") {
				id = val
				continue
			}
			if (key == "cnt") {
				row = val
				continue
			}
			if (key == "pid") {
				pid = val
				continue
			}
			if (key == "pos") continue
			if (key == "obj") {
				obj = val
				continue
			}
			if (key == "op") {
				f = 1
				desc = val
				gsub(q,"",desc)
				continue
			}
			print "Unexpected parameter for stat found on line " \\
				NR ": " \$x
		}
		if (obj != 0) desc = desc " (object id " obj ")"
		if (row != "9999999999") {
			# Replace any tildes, since I use them as delimiters
			gsub("~","!@#",desc)
			# Skip if execution plan already stored
			mtch = 0
			fil = tmpf "/stats/" substr(hv,1,1) "/" hv
			while (getline < fil > 0) {
				if (\$0 == row "~" id "~" pid "~" obj "~" \\
					seg_cr "~" seg_r "~" seg_w "~" \\
					seg_time "~" part_start "~" part_stop \\
					"~" desc "~" cost "~" size "~" card) \\
					mtch = 1
			}
			close(fil)
			if (mtch == 0) {
				fil = tmpf "/stats/" substr(hv,1,1) "/" hv
				print row "~" id "~" pid "~" obj "~" \\
					seg_cr "~" seg_r "~" seg_w "~" \\
					seg_time "~" part_start "~" part_stop \\
					"~" desc "~" cost "~" size "~" card \\
					>> fil
				close(fil)
			}
		}
	}
	next
} {
	if (abort_me == 2) next
	xx = check_lins()
	if (skip_dump == 1) {
		if (substr(\$NF, length(\$NF)) == "]") next
		if (\$1 == "Repeat" && \$3 == "times") next
		skip_dump = 0
	}
	if (skip_to_equal != 0) next
	if (skip_to_nonquo != 0) {
		quote = index(\$0, "\\"")
		if (quote == 0) {
			val = val \$0
		} else {
			if (quote != 1) val = val substr(\$0, 1, quote - 1)
			skip_to_nonquo = 0
			if (rpc_binds != 0) {
				if (debug != 0) print \\
					"  Store rpc bind[" \\
					varno "] multi value: " val \\
					" for rpcndx " rpcndx
				fil = tmpf "/rpcbinds/" rpcndx
				printf "%4s%s%4d%s%-25s%s%8d\n", " ", \\
					"Bind Number: ", varno + 1, \\
					" Bind Value: ", val \\
					" Trace line: ", NR >> fil
				close(fil)
				# Incr number of rpc binds
				++rpcbindvars[rpcndx]
			} else {
				if (debug != 0) print "  Store bind[" \\
					varno "] multi value: " val \\
					" for cur " cur
				# Skip avl comparison, since the avl buffer may
				# be much larger than the actual bind var
				#if (debug != 0) print "   Bind var len=" \\
				#	length(val) ", avl=" avl " on " NR
				#if (length(val) != avl && dty == 1) {
				#	print "  Truncated bind variable" \\
				#		" on line " NR ", length=" \\
				#		length(val) ", avl=" avl
				#	val = val " (Truncated)"
				#}
				fil = tmpf "/binds/" cur
				printf "%4s %11d    %-44s %10d\n", \\
					peeked, varno + 1, val, NR >> fil
				close(fil)
				# Incr number of binds
				++bindvars[cur]
			}
		}
		next
	}
	if (hv == 0) next
	if (rpc_call == 1) {
		rpc_zero = rpc_zero \$0
		next
	}
	if (substr(\$1, 1, 6) == "value=") {
		next_line_bind_value = 0
		if (abort_me == 2) next
		skip_dump = 0
		skip_to_nonquo = 0
		if (binds == 0) {
			print "Unprocessed value line on trace line " NR ": " \\
				\$0
			next
		}
		if (oacdef == 0) {
			equals = index(\$0, "value=") + 5
			if (equals == 5) {
				print "No bind value found on trace line " NR \\
					": " \$0
				next
			}
			if (equals == length(\$0)) {
				multi_line_value = 1
			} else {
				if (substr(\$0, length(\$0) - 1) == "=\\"") {
					multi_line_value = 2
				} else {
					val = substr(\$0, equals + 1)
					if (debug != 0) print \\
						"  Bind value " val " on " NR
					if (substr(val, 1, 1) == "\\"") {
						quote = index(substr(\\
							val, 2), "\\"")
						if (quote != 0) {
							val = substr(val, 2, \\
								quote - 1)
						} else {
							skip_to_nonquo = 1
						}
					}
					if (skip_to_nonquo == 0) {
						if (debug != 0) print \\
							"  Store bind[" \\
							varno "] value: " val \\
							" for cur " cur
						# Skip avl comparison,
						# since the avl buffer
						# may be much larger
						# than the actual bind var
						fil = tmpf "/binds/" cur
						printf \\
						  "%4s %11d    %-44s %10d\n", \\
							peeked, varno + 1, \\
							val, NR >> fil
						close(fil)
						# Incr number of binds
						++bindvars[cur]
					}
				}
			}
		}
		next
	}
	if (\$1 == "kkscoacd") next
	if (\$1 == "COLUMN:") next
	if (\$1 == "Size:") next
	if (\$1 == "Histogram:") next
	if (\$1 == "No" && \$2 == "bind" && \$3 == "buffers") next
	if (parameters == 1) {
		fil = tmpf "/params/" hv
		print substr(\$0, 1, 80) >> fil
		if (length(\$0) < 81) {
			zero = ""
		} else {
			zero = substr(\$0, 81)
		}
		while (length(zero) > 0) {
			print substr(zero, 1, 80) >> fil
			if (length(zero) < 81) {
				zero = ""
			} else {
				zero = substr(zero, 81)
			}
		}
		close(fil)
		next
	}
	if (parsing == 1 && hash_ndx == 0) {
		fil = tmpf "/sqls/" substr(hv,1,1) "/" hv
		print substr(\$0, 1, 80) >> fil
		if (length(\$0) < 81) {
			zero = ""
		} else {
			zero = substr(\$0, 81)
		}
		while (length(zero) > 0) {
			print substr(zero, 1, 80) >> fil
			if (length(zero) < 81) {
				zero = ""
			} else {
				zero = substr(zero, 81)
			}
		}
		close(fil)
		next
	} else {
		# See if processing a multi-line bind value
		if (rpc_binds != 0) {
			if (multi_line_value == 9) next
			if (multi_line_value > 0) {
				if (multi_line_value == 1) {
					bval = substr(\$0, 1, 25)
				} else {
					bval = "\\"" substr(\$0, 1, 23)
				}
				fil = tmpf "/rpcbinds/" rpcndx
				printf "%4s%s%4d%s%-25s%s%8d\n", \\
					" ", "Bind Number: ", \\
					varno + 1, \\
					" Bind Value: ", bval, \\
					" Trace line: ", NR >> fil
				if (length(\$0) > 25) {
					if (multi_line_value == 1) {
						bval = substr(\$0, 26, 25)
					} else {
						bval = "\\"" substr(\$0, 26, 23)
					}
					printf "%34s%-25s\n", " ", bval >> fil
				}
				if (length(\$0) > 50) {
					if (multi_line_value == 1) {
						bval = substr(\$0, 51, 25)
					} else {
						bval = "\\"" substr(\$0, 51, 23)
					}
					printf "%34s%-25s\n", " ", bval >> fil
				}
				close(fil)
				++rpcbindvars[rpcndx]
				multi_line_value = 9
			}
			next
		}
		if (binds == 1) {
			if (multi_line_value == 9) next
			if (multi_line_value > 0) {
				if (multi_line_value == 1) {
					bval = substr(\$0, 1, 44)
				} else {
					bval = "\\"" substr(\$0, 1, 43)
				}
				fil = tmpf "/binds/" curno
				printf "     %11d    %-44s %10d\n", \\
					varno + 1, bval, NR >> fil
				if (length(\$0) > 44) {
					if (multi_line_value == 1) {
						bval = substr(\$0, 45)
					} else {
						bval = "\\"" substr(\$0, 44)
					}
					fil = tmpf "/binds/" curno
					printf "     %11d    %-44s %10d\n", \\
						varno + 1, bval, NR >> fil
				}
				close(fil)
				++bindvars[curno]
				multi_line_value = 9
				next
			}
		}
		# Skip if we already found this SQL
		if (parsing == 1) next
		# Skip header
		if (NR < 10) next
		if (\$1 == "adbdrv:") next
		if (\$1 == "With") next
		if (\$1 == "ORACLE_HOME") next
		if (\$1 == "System") next
		if (\$1 == "Release:") next
		if (\$1 == "Version:") next
		if (\$1 == "Machine:") next
		if (\$1 == "Redo") next
		if (\$1 == "Oracle") next
		if (\$1 == "JServer") next
		if (NF == 0) next
		print "Unprocessed line on trace line " NR ": " \$0
		if (print_trunc == 0) {
			print ""
			print "Ensure that the dump file has not been " \\
				"truncated!!!!"
			print "Set MAX_DUMP_FILE_SIZE=UNLIMITED to avoid " \\
				"truncation."
			print ""
			print_trunc = 1
		}
	}
} END {
	# Store any pending wait events that do not have a following cursor
	all_cursors = 1
	xx = move_curno_waits()
	if (gap_time < 0) gap_time = 0
	fil = tmpf "/eof"
	if (debug != 0) {
		print "last_tim=   " last_tim
		printf "%s%12.4f\n", "first_time= ", first_time
		print "Write grand_elapsed= " last_tim - first_time
	}
	print int(last_tim - first_time) > fil
	close(fil)
	fil = tmpf "/init"
	print mm " " dd " " yy " " hh " " mi " " ss " " divisor " " \\
		first_time " " gap_time " " gap_cnt " " cpu_timing_parse \\
		" " cpu_timing_exec " " cpu_timing_fetch " " cpu_timing_unmap \\
		" " cpu_timing_sort " " cpu_timing_parse_cnt " " \\
		cpu_timing_exec_cnt " " cpu_timing_fetch_cnt " " \\
		cpu_timing_unmap_cnt " " cpu_timing_sort_cnt " " unacc_total \\
		" " unacc_cnt " " ncur " " cpu_timing_rpcexec " " \\
		cpu_timing_rpcexec_cnt " " cpu_timing_close " " \\
		cpu_timing_close_cnt > fil
	close(fil)
}
EOF
if [ `file $1 | awk '{ print index($0, " CRLF ") }'` -eq 0 ]
then
	cat $1 | sed -e "s/ \. /./g" -e "s/ ,/,/g" | \
		$cmd -f trace_report.awk outf=$outf q="'" tmpf="$tmpf" \
		debug="$debug" totlins="`wc -l $1 | awk '{ print $1 }' -`"
else
	# Convert DOS (CR/LF) text file to Unix (LF) format
	echo "Processing DOS-formatted trace file..."
	tr -d \\015 < $1 | sed -e "s/ \. /./g" -e "s/ ,/,/g" | \
		$cmd -f trace_report.awk outf=$outf q="'" tmpf="$tmpf" \
		debug="$debug" totlins="`wc -l $1 | awk '{ print $1 }' -`"
fi
rm -f trace_report.awk
echo "Sorting temp files..."
if [ "$debug" = "1" ]
then
	echo "Sort cursors..."
fi
sort $tmpf/cursors > $tmpf/srt.tmp
mv -f $tmpf/srt.tmp $tmpf/cursors
#
if [ "$debug" = "1" ]
then
	echo "Sort parse lines..."
fi
for i in 0 1 2 3 4 5 6 7 8 9
do
	ls -1 $tmpf/parse/$i/ | while read line
	do
		sort $tmpf/parse/$i/$line > $tmpf/parse/$i/srt.tmp
		mv -f $tmpf/parse/$i/srt.tmp $tmpf/parse/$i/$line
	done
done
if [ "$debug" = "1" ]
then
	echo "Sort wait lines..."
fi
for i in 0 1 2 3 4 5 6 7 8 9
do
	ls -1 $tmpf/waits/$i/ | while read line
	do
		sort $tmpf/waits/$i/$line > $tmpf/waits/$i/srt.tmp
		mv -f $tmpf/waits/$i/srt.tmp $tmpf/waits/$i/$line
	done
done
if [ "$debug" = "1" ]
then
	echo "Sort cmdtypes..."
fi
sort $tmpf/cmdtypes > $tmpf/srt.tmp
mv -f $tmpf/srt.tmp $tmpf/cmdtypes
if [ "$debug" = "1" ]
then
	echo "Sort modules..."
fi
sort $tmpf/modules > $tmpf/srt.tmp
mv -f $tmpf/srt.tmp $tmpf/modules
if [ "$debug" = "1" ]
then
	echo "Sort actions..."
fi
sort $tmpf/actions > $tmpf/srt.tmp
mv -f $tmpf/srt.tmp $tmpf/actions
if [ "$debug" = "1" ]
then
	echo "Sort waits..."
fi
sort $tmpf/waits/t > $tmpf/waits/srt.tmp
mv -f $tmpf/waits/srt.tmp $tmpf/waits/t
if [ "$debug" = "1" ]
then
	echo "Sort total waits by cursor..."
fi
sort $tmpf/waits/totcur > $tmpf/waits/srt.tmp
mv -f $tmpf/waits/srt.tmp $tmpf/waits/totcur
if [ "$debug" = "1" ]
then
	echo "Sort total waits by module..."
fi
sort $tmpf/waits/totmod > $tmpf/waits/srt.tmp
mv -f $tmpf/waits/srt.tmp $tmpf/waits/totmod
if [ "$debug" = "1" ]
then
	echo "Sort total waits by action..."
fi
sort $tmpf/waits/totact > $tmpf/waits/srt.tmp
mv -f $tmpf/waits/srt.tmp $tmpf/waits/totact
if [ "$debug" = "1" ]
then
	echo "List of all temp files..."
	ls -l $tmpf
fi
cat <<EOF > trace_report.awk
function numtostr(n) {
	if (n < 10000) {
		return sprintf("%5d", n)
	} else {
		if (n < 1024000) {
			return sprintf("%4d%s", (n + 512) / 1024, "K")
		} else {
			if (n < 1048576000) {
				return sprintf("%4d%s", \\
					(n + 524288) / 1048576, "M")
			} else {
				return sprintf("%4d%s", \\
					(n + 536870912) / 1073741824, "G")
			}
		}
	}
} BEGIN {
	dmi[1] = 31
	dmi[2] = 31
	dmi[3] = 30
	dmi[4] = 31
	dmi[5] = 31
	dmi[6] = 30
	dmi[7] = 31
	dmi[8] = 31
	dmi[9] = 30
	dmi[10] = 31
	dmi[11] = 30
	dmi[12] = 31
	totn = 0
	totnr = 0
	blanks = "                                                       "
	offst = "                    "
} function ymdhms(oratim) {
	nyy = yy + 0
	nmm = mm + 0
	ndd = dd + 0
	nhh = hh + 0
	nmi = mi + 0
	nss = ss + int((oratim - first_time) / 100)
	while (nss > 59) {
		nss = nss - 60
		nmi = nmi + 1
	}
	while (nmi > 59) {
		nmi = nmi - 60
		nhh = nhh + 1
	}
	while (nhh > 23) {
		nhh = nhh - 24
		ndd = ndd + 1
	}
	if (nmm == 2) {
		if (nyy == 4 * int(nyy / 4)) {
			if (nyy == 100 * int(nyy / 100)) {
				if (nyy == 400 * int(nyy / 400)) {
					dmi[2] = 29
				} else {
					dmi[2] = 28
				}
			} else {
				dmi[2] = 29
			}
		} else {
			dmi[2] = 28
		}
	}
	while (ndd > dmi[nmm]) {
		ndd = ndd - dmi[nmm]
		nmm = nmm + 1
	}
	while (nmm > 12) {
		nmm = nmm - 12
		nyy = nyy + 1
	}
	return sprintf("%2.2d/%2.2d/%2.2d %2.2d:%2.2d:%2.2d", \\
		nmm, ndd, nyy, nhh, nmi, nss)
} function print_prev_operation() {
	printop = prev_op
	if (prev_op == "1") printop = "Parse"
	if (prev_op == "2") printop = "Execute"
	if (prev_op == "3") printop = "Fetch"
	if (prev_op == "4") printop = "Unmap"
	if (prev_op == "5") printop = "Srt Unm"
	printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
		printop, stcount, stcpu / 100, stelapsed / 100, \\
		stdisk, stquery, stcurrent, strows >> outf
	tcount = tcount + stcount
	tcpu = tcpu + stcpu
	telapsed = telapsed + stelapsed
	if (prev_op == "3") {
		tfetch = tfetch + stelapsed
		if (stdisk > 0) avg_read_time = int(1000 * \\
			((stelapsed - stcpu) / 100) / stdisk)
	}
	tdisk = tdisk + stdisk
	tquery = tquery + stquery
	tcurrent = tcurrent + stcurrent
	trows = trows + strows
	if (dep == "0") {
		x9 = 0
		mtch = 0
		while (x9 < totn) {
			++x9
			if (opnames[x9] == printop) {
				mtch = x9
				x9 = totn
			}
		}
		if (mtch == 0) {
			++totn
			opnames[totn] = printop
			otcounts[totn] = 0
			otcpus[totn] = 0
			otelapseds[totn] = 0
			otdisks[totn] = 0
			otquerys[totn] = 0
			otcurrents[totn] = 0
			otrowss[totn] = 0
			otunaccs[totn] = 0
			mtch = totn
		}
		if (debug != 0) print "    print_prev_operation: Accum" \\
			" recur wait " mtch " out of " totn
		otcounts[mtch] = otcounts[mtch] + stcount
		otcpus[mtch] = otcpus[mtch] + stcpu
		otelapseds[mtch] = otelapseds[mtch] + stelapsed
		otdisks[mtch] = otdisks[mtch] + stdisk
		otquerys[mtch] = otquerys[mtch] + stquery
		otcurrents[mtch] = otcurrents[mtch] + stcurrent
		otrowss[mtch] = otrowss[mtch] + strows
		otunaccs[mtch] = otunaccs[mtch] + stunacc
	} else {
		x9 = 0
		mtch = 0
		while (x9 < totnr) {
			++x9
			if (ropnames[x9] == printop) {
				mtch = x9
				x9 = totnr
			}
		}
		if (mtch == 0) {
			++totnr
			ropnames[totnr] = printop
			rotcounts[totnr] = 0
			rotcpus[totnr] = 0
			rotelapseds[totnr] = 0
			rotdisks[totnr] = 0
			rotquerys[totnr] = 0
			rotcurrents[totnr] = 0
			rotrowss[totnr] = 0
			rotunaccs[totnr] = 0
			mtch = totnr
		}
		if (debug != 0) print "    print_prev_operation: Accum" \\
			" non-recur wait " mtch " out of " totnr
		rotcounts[mtch] = rotcounts[mtch] + stcount
		rotcpus[mtch] = rotcpus[mtch] + stcpu
		rotelapseds[mtch] = rotelapseds[mtch] + stelapsed
		rotdisks[mtch] = rotdisks[mtch] + stdisk
		rotquerys[mtch] = rotquerys[mtch] + stquery
		rotcurrents[mtch] = rotcurrents[mtch] + stcurrent
		rotrowss[mtch] = rotrowss[mtch] + strows
		rotunaccs[mtch] = rotunaccs[mtch] + stunacc
	}
} function print_prev_module() {
	print prev_module >> outf
	printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
		" ", stcount, stcpu / 100, \\
		stelapsed / 100, stdisk, stquery, stcurrent, strows >> outf
	print " " >> outf
	tcount = tcount + stcount
	tcpu = tcpu + stcpu
	telapsed = telapsed + stelapsed
	tdisk = tdisk + stdisk
	tquery = tquery + stquery
	tcurrent = tcurrent + stcurrent
	trows = trows + strows
} function print_prev_action() {
	print prev_action >> outf
	printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
		" ", stcount, stcpu / 100, \\
		stelapsed / 100, stdisk, stquery, stcurrent, strows >> outf
	print " " >> outf
	tcount = tcount + stcount
	tcpu = tcpu + stcpu
	telapsed = telapsed + stelapsed
	tdisk = tdisk + stdisk
	tquery = tquery + stquery
	tcurrent = tcurrent + stcurrent
	trows = trows + strows
} function print_prev_command_type() {
	printcmd = cmdtypstrs[prev_cmd]
	printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
		substr(printcmd, 1, 7), stcount, stcpu / 100, \\
		stelapsed / 100, stdisk, stquery, stcurrent, strows >> outf
	j = 8
	while (length(printcmd) >= j) {
		print substr(printcmd, j, 7) >> outf
		j = j + 7
	}
	tcount = tcount + stcount
	tcpu = tcpu + stcpu
	telapsed = telapsed + stelapsed
	tdisk = tdisk + stdisk
	tquery = tquery + stquery
	tcurrent = tcurrent + stcurrent
	trows = trows + strows
} function print_prev_curwait() {
	if (namela < 1) return
	if (found == 0) {
		print "" >> outf
		print "####################################" \\
			"############################################" >> outf
		print "" >> outf
		print "                          TOTAL WAIT EVENTS BY CURSOR" \\
			>> outf
		print "" >> outf
		print "                                                  " \\
			"                   Wait" >> outf
		print "       Cursor Wait Event                          " \\
			"                  Seconds" >> outf
		print "       ------ ------------------------------------" \\
			"-------------- ----------" >> outf
		found = 1
	}
	printf "       %6d %-50s %10.4f\n", \\
		prev_cur, substr(prev_nam, 1, 50), namela / 100 >> outf
	if (length(prev_nam) > 50) \\
		print "              " substr(prev_nam, 51, 50) >> outf
	namela = 0
} function print_prev_modwait() {
	if (namela < 1) return
	if (print_module == 1) {
		print "" >> outf
		print "####################################" \\
			"############################################" >> outf
		print "" >> outf
		print "                          TOTAL WAIT EVENTS BY MODULE" \\
			>> outf
		print "" >> outf
		print "Module                          " \\
			" Wait Event                       Wait Seconds" >> outf
		print "--------------------------------" \\
			" ------------------------------ --------------" >> outf
		printf "%-32s %-30s %14.4f\n", \\
			substr(prev_module, 1, 32), substr(prev_nam, 1, 30), \\
			namela / 100 >> outf
		if (length(prev_module) > 32) {
			if (length(prev_nam) > 30) {
				printf "%-32s %-30s\n", \\
					substr(prev_module, 33, 32), \\
					substr(prev_nam, 31, 30) >> outf
			} else {
				printf "%-32s\n", substr(prev_module, 33, 32) \\
					>> outf
			}
		} else {
			if (length(prev_nam) > 30) {
				printf "%-32s %-30s\n", " ", \\
					substr(prev_nam, 31, 30) >> outf
			}
		}
		print_module = 0
		found = 1
	} else {
		printf "%-32s %-30s %14.4f\n", \\
			" ", substr(prev_nam, 1, 30), namela / 100 >> outf
		if (length(prev_nam) > 30) {
			printf "%-32s %-30s\n", " ", substr(prev_nam, 31, 30) \\
				>> outf
		}
	}
	namela = 0
} function print_prev_actwait() {
	if (namela < 1) return
	if (print_action == 1) {
		print "" >> outf
		print "####################################" \\
			"############################################" >> outf
		print "" >> outf
		print "                          TOTAL WAIT EVENTS BY ACTION" \\
			>> outf
		print "" >> outf
		print "Action                          " \\
			" Wait Event                       Wait Seconds" >> outf
		print "--------------------------------" \\
			" ------------------------------ --------------" >> outf
		printf "%-32s %-30s %14.4f\n", \\
			substr(prev_action, 1, 32), substr(prev_nam, 1, 30), \\
			namela / 100 >> outf
		if (length(prev_action) > 32) {
			if (length(prev_nam) > 30) {
				printf "%-32s %-30s\n", \\
					substr(prev_action, 33, 32), \\
					substr(prev_nam, 31, 30) >> outf
			} else {
				printf "%-32s\n", substr(prev_action, 33, 32) \\
					>> outf
			}
		} else {
			if (length(prev_nam) > 30) {
				printf "%-32s %-30s\n", " ", \\
					substr(prev_nam, 31, 30) >> outf
			}
		}
		print_action = 0
		found = 1
	} else {
		printf "%-32s %-30s %14.4f\n", \\
			" ", substr(prev_nam, 1, 30), namela / 100 >> outf
		if (length(prev_nam) > 30) {
			printf "%-32s %-30s\n", " ", substr(prev_nam, 31, 30) \\
				>> outf
		}
	}
	namela = 0
} function print_prev_wait() {
	if (totwts == 0) return
	if (totela < 1) return
	if (found == 0) {
		print "" >> outf
		print "####################################" \\
			"############################################" >> outf
		print "" >> outf
		if (wait_head == 1) {
			print "             WAIT EVENTS FOR ALL" \\
				" NON-RECURSIVE STATEMENTS FOR USERS" >> outf
		}
		if (wait_head == 2) {
			print "               WAIT EVENTS FOR ALL" \\
				" RECURSIVE STATEMENTS FOR USERS" >> outf
		}
		if (wait_head == 3) {
			print "                WAIT EVENTS FOR ALL" \\
				" RECURSIVE STATEMENTS FOR SYS" >> outf
		}
		if (wait_head == 4) {
			print "                   **** GRAND TOTAL NON-IDLE" \\
				" WAIT EVENTS ****" >> outf
		}
		if (wait_head == 5) {
			print "                         *** ORACLE TIMING" \\
				" ANALYSIS ***" >> outf
		}
		print "" >> outf
		print "                                   " \\
			"                 Elapsed             Seconds" >> outf
		if (wait_head == 5) {
			print "Oracle Process/Wait Event          " \\
				"                 Seconds  Pct  Calls  /Call" \\
				>> outf
		} else {
			print "Oracle Wait Event Name             " \\
				"                 Seconds  Pct  Calls  /Call" \\
				>> outf
		}
		print "-----------------------------------" \\
			"--------------- -------- ---- ------ -------" >> outf
		found = 1
	}
	printf "%-50s %8.2f %3d%s %6d %7.2f\n", \\
		substr(print_nam, 1, 50), totela / 100, \\
		int(1000 * (totela + .0000001) / (totwait + .0000001)) / 10, \\
		"%", totwts, totela / (totwts * 100 + .0000001) >> outf
	if (length(print_nam) > 50) print "  " substr(print_nam, 51) >> outf
	if (wait_head != 5) {
		if (substr(print_nam,1,17) == "buffer busy waits" || \\
			substr(print_nam,1,16) == "direct path read" || \\
			substr(print_nam,1,17) == "direct path write" || \\
			print_nam == "free buffer waits" || \\
			print_nam == "write complete waits" || \\
			substr(print_nam,1,12) == "db file scat" || \\
			substr(print_nam,1,11) == "db file seq") filblk = 1
	}
	gtotwts = gtotwts + totwts
	gtotela = gtotela + totela
} {
	if (NF != 27) {
		print "Unexpected number of columns (" NF ") in init line:"
		print \$0
		next
	}
	if (debug != 0) print "Init report..."
	mm = \$1
	dd = \$2
	yy = \$3
	hh = \$4
	mi = \$5
	ss = \$6
	divisor = \$7
	first_time = \$8
	gap_time = \$9
	gap_cnt = \$10
	cpu_timing_parse = \$11
	cpu_timing_exec = \$12
	cpu_timing_fetch = \$13
	cpu_timing_unmap = \$14
	cpu_timing_sort = \$15
	cpu_timing_parse_cnt = \$16
	cpu_timing_exec_cnt = \$17
	cpu_timing_fetch_cnt = \$18
	cpu_timing_unmap_cnt = \$19
	cpu_timing_sort_cnt = \$20
	unacc_total= \$21
	unacc_cnt = \$22
	maxcn = \$23 + 1
	cpu_timing_rpcexec = \$24
	cpu_timing_rpcexec_cnt =\$25
	cpu_timing_close = \$26
	cpu_timing_close_cnt = \$27
	fil = tmpf "/eof"
	if (getline < fil > 0) {
		grand_elapsed = \$0
		if (debug != 0) print "Report: Read grand_elapsed= " \\
			grand_elapsed
	} else {
		print "Error while trying to read eof"
	}
	close(fil)
	#
	# Process each cursor
	#
	if (debug != 0) print "********** Reading cursors file... **********"
	print_revisits = 1
	cn = 0
	curfil = tmpf "/cursors"
	while (getline < curfil > 0) {
		if (NF != 11) {
			print "Unexpected number of columns (" NF \\
				") in cursor line:"
			print \$0
			continue
		}
		cur = \$1
		curno = \$2
		++cn
		if (debug == 0) {
			if (cn == 10 * int(cn / 10)) \\
				print "Processing cursor " cn " of " maxcn "..."
		} else {
			print "Read cursor #" curno " in array #" cur " (cn=" \\
				cn " maxcn=" maxcn ")"
		}
		hv = \$3
		oct = \$4
		uid = \$5
		dep = \$6
		elapsed_time = \$7
		parsing_tim = \$8
		err = \$9
		recn = \$10
		sqlid = \$11
		if (debug != 0) print "  hv=" hv " elapsed=" elapsed_time
		#
		# Start of new cursor
		#
		print "" >> outf
		print "###################################################" \\
			"#############################" >> outf
		print "" >> outf
		found = 0
		if (cur != 9999) {
			if (parsing_tim == 0) {
				xxx = ""
			} else {
				xxx = " at " ymdhms(parsing_tim)
			}
			if (dep == "0") {
				print "ID #" cur xxx " (Cursor " curno "):" \\
					>> outf
			} else {
				print "ID #" cur " (RECURSIVE DEPTH " dep \\
					")" xxx " (Cursor " curno "):" >> outf
			}
			print "" >> outf
			#
			# Print any Parameters used by the optimizer
			#
			if (debug != 0) print "  Read Optimizer Parameters..."
			found = 0
			fil = tmpf "/params/" hv
			while (getline < fil > 0) {
				print \$0 >> outf
				found = 1
			}
			close(fil)
			if (found != 0) print "" >> outf
			#
			# Print any SQL Text
			#
			if (debug != 0) print "  Read SQL text..."
			found = 0
			fil = tmpf "/sqls/" substr(hv,1,1) "/" hv
			while (getline < fil > 0) {
				print \$0 >> outf
				found = 1
			}
			close(fil)
			if (found != 0) {
				print "" >> outf
				if (sqlid == ".") {
					print "SQL Hash Value: " hv >> outf
				} else {
					print "SQL Hash Value: " hv \\
						"   SQL ID: " sqlid >> outf
				}
				print "" >> outf
			}
			#
			# Print any bind variables for this cursor
			#
			if (debug != 0) print "  Read bind variables..."
			cnt = 0
			fil = tmpf "/binds/" cur
			while (getline < fil > 0) {
				++cnt
				if (found == 0) print "" >> outf
				if (found < 2) {
					print "          First 100 Bind" \\
						" Variable Values (Including" \\
						" any peeked values)" >> outf
					print "" >> outf
					print "     Bind Number    Bind Valu" \\
						"e                         " \\
						"          Trace line" >> outf
					print "     -----------    --------" \\
						"---------------------" \\
						"--------------- ----------" \\
						>> outf
				}
				if (cnt <= 100) {
					if (length(\$0) <= 75) {
						print \$0 >> outf
					} else {
						# Wrap long variables over
						# multiple lines
						print substr(\$0, 1, 64) >> outf
						xxx = substr(\$0, 65)
						ll = length(xxx)
						while (ll > 0) {
							if (ll > 55) {
								print offst \\
								    substr(\\
								    xxx, 1, \\
								    44) >> outf
								xxx = substr(\\
									xxx, 45)
								ll = ll - 44
							} else {
								if (ll < 55) {
								  print offst \\
								    substr(\\
								    xxx, 1, \\
								    ll - 10) \\
								    substr(\\
								    blanks, \\
								    1, 55 - \\
								    ll) \\
								    substr(\\
								    xxx, ll - \\
								    9) >> outf
								} else {
								  print offst \\
								    xxx >> outf
								}
								ll = 0
							}
						}
					}
				}
				found = 2
			}
			close(fil)
			if (cnt > 0) print "     Total of " cnt \\
				" bind variables" >> outf
			if (found != 0) print "" >> outf
			#
			# Print any Parse/Execute/Fetch times
			#
			if (debug != 0) print "  Read parse..."
			fil = tmpf "/parse/" substr(hv,1,1) "/" hv
			found = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
			stunacc = 0
			stgap = 0
			avg_read_time = 0
			while (getline < fil > 0) {
				if (NF != 13) {
					print "Unexpected number of columns" \\
						" (" NF ") in parse line" \\
						" for hash value " hv ":"
					print \$0
					continue
				}
				if (found == 0) {
					print "call     count      cpu" \\
						"    elapsed       disk" \\
						"      query    current" \\
						"       rows" >> outf
					print "------- ------ --------" \\
						" ---------- ----------" \\
						" ---------- ----------" \\
						" ----------" >> outf
					found = 1
					prev_op = "@"
					tcount = 0
					tcpu = 0
					telapsed = 0
					tfetch = 0
					tdisk = 0
					tquery = 0
					tcurrent = 0
					trows = 0
				}
				op = \$1
				if (prev_op != op) {
					if (prev_op != "@") {
						xx = print_prev_operation()
					}
					prev_op = op
					stcount = 0
					stcpu = 0
					stelapsed = 0
					stdisk = 0
					stquery = 0
					stcurrent = 0
					strows = 0
					op_goal = \$9
					tim = \$10
					sqlid = \$13
				}
				++stcount
				stcpu = stcpu + \$2
				stelapsed = stelapsed + \$3
				stdisk = stdisk + \$4
				stquery = stquery + \$5
				stcurrent = stcurrent + \$6
				strows = strows + \$7
				if (op == "1") stmissparse = stmissparse + \$8
				if (op == "2") stmissexec = stmissexec + \$8
				if (op == "3") stmissfetch = stmissfetch + \$8
				stunacc = stunacc + \$11
				stgap = stgap + \$12
			}
			close(fil)
			if (found != 0) {
				xx = print_prev_operation()
				print "------- ------ -------- ----------" \\
					" ---------- ---------- ----------" \\
					" ----------" >> outf
				printf \\
				"%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
					"total", tcount, tcpu / 100, \\
					telapsed / 100, tdisk, tquery, \\
					tcurrent, trows >> outf
				print "" >> outf
			}
			if (stunacc >= 1) {
				printf "%s %7.2f\n", \\
					"  Unaccounted-for time:   ", \\
					stunacc / 100 >> outf
				print "" >> outf
			}
			if (stgap >= 1) {
				printf "%s %7.2f\n", \\
					"  Timing Gap error (secs):", \\
					stgap / 100 >> outf
				print "" >> outf
			}
			if (avg_read_time > 0) {
				printf "%s%s%8d\n", \\
					"Avg time to read one disk", \\
					" block(ms): ", avg_read_time >> outf
				print "" >> outf
			}
			if (elapsed_time >= 100) {
				printf "%s%13.2f\n", \\
					"Elapsed wall clock time (secs): ", \\
					int(elapsed_time) / 100 >> outf
				print "" >> outf
			}
		}
		#
		# Accum total Wait time
		#
		if (debug != 0) print "  Read total wait..."
		fil = tmpf "/waits/" substr(hv,1,1) "/" hv
		fil2 = tmpf "/waitblocks/" hv
		print "0" >> fil2
		totela = 0
		totreads = 0
		totblocks = 0
		totread_time = 0
		while (getline < fil > 0) {
			elem = split(\$0, arr, "~")
			if (elem != 7) {
				print "Unexpected number of columns (" elem \\
					") in waits line for hash value " hv ":"
				print \$0
				continue
			}
			ela = arr[5]
			if (arr[1] == "db file sequential read" || \\
				substr(arr[1],1,12) == "db file scat") {
				totreads = totreads + 1
				totblocks = totblocks + arr[4]
				totread_time = totread_time + ela
				printf "%12d %12d\n", arr[2], arr[3] >> fil2
			}
			totela = totela + ela
		}
		close(fil)
		close(fil2)
		if (found != 0) {
			fil = tmpf "/elap"
			telapsed = int(telapsed)
			printf \\
			    "%12d %12d %12d %12d %12d %12d %12d %12d %12d\n", \\
				telapsed, cur, uid, tcount, tcpu, \\
				totela, tdisk, tquery, tcurrent >> fil
			close(fil)
			fil = tmpf "/fetch"
			tfetch = int(tfetch)
			printf \\
			    "%12d %12d %12d %12d %12d %12d %12d %12d %12d\n", \\
				tfetch, cur, uid, tcount, tcpu, \\
				telapsed, tdisk, tquery, tcurrent >> fil
			close(fil)
		}
		system("sort -n " tmpf "/waitblocks/" hv \\
			" > " tmpf "/waitblocks/s" hv)
		system("rm -f " tmpf "/waitblocks/" hv)
		prev_file = -1
		prev_block = -1
		cnt = 0
		fil = tmpf "/waitblocks/s" hv
		fil2 = tmpf "/waitblocks/s2" hv
		while (getline < fil > 0) {
			if (\$0 == "0") {
				print "0 0 0" >> fil2
				continue
			}
			if (prev_file != \$1 || prev_block != \$2) {
				if (prev_file >= 0 && cnt > 1) {
					print cnt " " prev_file " " \\
						prev_block >> fil2
				}
				prev_file = \$1
				prev_block = \$2
				cnt = 0
			}
			cnt = cnt + 1
		}
		if (prev_file >= 0 && cnt > 1) {
			print cnt " " prev_file " " prev_block >> fil2
		}
		close(fil2)
		close(fil)
		system("rm -f " tmpf "/waitblocks/s" hv)
		system("sort -nr " tmpf "/waitblocks/s2" hv " > " tmpf \\
			"/waitblocks/s3" hv)
		#
		# Print any Wait times
		#
		if (debug != 0) print "  Print waits (totela=" totela ")..."
		if (totela > 0 || cur == 0) {
			if (cur == 0) hv = "0"
			fil = tmpf "/waits/" substr(hv,1,1) "/" hv
			found = 0
			wait_ctr = 0
			while (getline < fil > 0) {
				elem = split(\$0, arr, "~")
				if (elem != 7) continue
				nam = arr[1]
				ela = arr[5]
				if (10 * ela >= 1) {
					if (substr(nam,1,17) == \\
						"buffer busy waits" || \\
						substr(nam,1,16) == \\
						"direct path read" || \\
						substr(nam,1,17) == \\
						"direct path write" || \\
						nam == "free buffer waits" || \\
						nam == "write complete waits" \\
						|| nam == \\
						"buffer busy global cache" || \\
						nam == \\
						"buffer busy global CR" || \\
						nam == "buffer read retry" || \\
						nam == \\
						"control file sequential read"\\
						|| nam == \\
						"control file single write" \\
						|| nam == \\
						"conversion file read" || \\
						nam == \\
						"db file single write" || \\
						nam == \\
						"global cache lock busy" || \\
						nam == \\
						"global cache lock cleanup" \\
						|| nam == \\
						"global cache lock null to s" \\
						|| nam == \\
						"global cache lock null to x" \\
						|| nam == \\
						"global cache lock open null" \\
						|| nam == \\
						"global cache lock open s" \\
						|| nam == \\
						"global cache lock open x" \\
						|| nam == \\
						"global cache lock s to x" \\
						|| nam == \\
						"local write wait" || \\
						substr(nam,1,12) == \\
						"db file scat" || \\
						substr(nam,1,11) == \\
						"db file seq") {
							file_numb = arr[2] # p1
							block_numb = arr[3] # p2
					} else {
						file_numb = ""
						block_numb = ""
					}
					if (substr(nam,1,11) == "enqueue (Na") {
						rollback_seg = arr[3]	# p2
					} else {
						rollback_seg = 0
					}
					if (found == 0) {
						if (hv == 1) {
							print "            " \\
								"        " \\
								"Unaccounted" \\
								" Wait" \\
								" Events for" \\
								" all" \\
								" cursors" \\
								>> outf
						} else {
							print "            " \\
								"         " \\
								"    " \\
								"Significant" \\
								" Wait" \\
								" Events" \\
								>> outf
						}
						print " " >> outf
						print "                   " \\
							"                 " \\
							"       Total" >> outf
						print "                   " \\
							"                 " \\
							"       Wait      " \\
							"   Trace" >> outf
						print "                    " \\
							"                  " \\
							"     Time         " \\
							" File File   Block" \\
							>> outf
						print "Oracle Event Name" \\
							"               " \\
							"          (secs)" \\
							"  Pct    Line Numb" \\
							"  Number" >> outf
						print "-----------------" \\
							"---------------" \\
							"------- --------" \\
							" ---- ------- ----" \\
							" -------" >> outf
						found = 1
						prev_event = "@"
						event_ctr = 0
					}
					recnum = arr[6]
					objn = arr[7]
					if (prev_event != nam || \\
						event_ctr < 11) {
						if (prev_event != "@" && \\
							event_ctr > 10) {
							print "     " \\
								event_ctr - \\
								10 " more " \\
								prev_event \\
								" wait" \\
								" events..." \\
								>> outf
							printf \\
					   "%s%s%9.3f %s%s%9.3f %s%s%9.3f\n", \\
								"Min Wait", \\
								" Time=", \\
								min_wait / \\
								100, \\
								"Avg Wait", \\
								" Time=", \\
								(avg_wait / \\
								event_ctr) / \\
								100, \\
								"Max Wait", \\
								" Time=", \\
								max_wait / \\
								100>> outf
						}
						if (totela == 0) {
							printf \\
					     "%-39s%9.3f      %7d %4s%8s\n", \\
							  substr(nam, 1, 39), \\
							  ela / 100, \\
							  recnum, file_numb, \\
							  block_numb >> outf
						} else {
							printf \\
					     "%-39s%9.3f %3d%s %7d %4s%8s\n", \\
							  substr(nam, 1, 39), \\
							  ela / 100, \\
							  int(1000 * ela / \\
							  totela) / 10, "%", \\
							  recnum, file_numb, \\
							  block_numb >> outf
						}
						if (length(nam) > 39) \\
							print "  " \\
							substr(nam, 40) >> outf
						if (substr(nam,1,11) == \\
							"enqueue (Na") {
							rbsn = int(\\
								rollback_seg \\
								/ 65536)
							print "  Rollback" \\
								" segment #" \\
								rbsn \\
								", Slot #" \\
								rollback_seg \\
								- (rbsn * \\
								65536) >> outf
						}
						if (prev_event != nam) {
							prev_event = nam
							min_wait = 9999999999999
							avg_wait = 0
							max_wait = 0
							event_ctr = 0
						}
					}
					rest = 0
					++event_ctr
					avg_wait = avg_wait + ela
					if (ela < min_wait) min_wait = ela
					if (ela > max_wait) max_wait = ela
				}
				# Accum subtotals by event name
				if (debug != 0) print "  Accum wait subtots..."
				x9 = 0
				mtch = 0
				while (x9 < wait_ctr) {
					++x9
					if (file_numb == "") {
						if (waitevs[x9] == nam) {
							mtch = x9
							x9 = wait_ctr
						}
					} else {
						if (waitevs[x9] == \\
							nam " (File " \\
							file_numb ")") {
							mtch = x9
							x9 = wait_ctr
						}
					}
				}
				if (mtch == 0) {
					++wait_ctr
					if (file_numb == "") {
						waitevs[wait_ctr] = nam
						waitfile[wait_ctr] = " "
					} else {
						waitevs[wait_ctr] = nam \\
							" (File " file_numb ")"
						if (substr(nam, 1, 7) == \\
							"db file") {
							waitfile[wait_ctr] = \\
								file_numb
						} else {
							waitfile[wait_ctr] = " "
						}
					}
					maxwait[wait_ctr] = ela
					waitsecs[wait_ctr] = ela
					waitcnts[wait_ctr] = 1
					ms1_wait[wait_ctr] = 0
					ms2_wait[wait_ctr] = 0
					ms4_wait[wait_ctr] = 0
					ms8_wait[wait_ctr] = 0
					ms16_wait[wait_ctr] = 0
					ms32_wait[wait_ctr] = 0
					ms64_wait[wait_ctr] = 0
					ms128_wait[wait_ctr] = 0
					ms256_wait[wait_ctr] = 0
					msbig_wait[wait_ctr] = 0
					mtch = wait_ctr
				} else {
					waitsecs[mtch] = waitsecs[mtch] + ela
					if (ela > maxwait[mtch]) \\
						maxwait[mtch] = ela
					++waitcnts[mtch]
				}
				if (debug != 0) print "  Accum wait hists..."
				if (ela * 1000 <= 100) {
					++ms1_wait[mtch]
				} else {
				  if (ela * 500 <= 100) {
				    ++ms2_wait[mtch]
				  } else {
				    if (ela * 250 <= 100) {
				      ++ms4_wait[mtch]
				    } else {
				      if (ela * 125 <= 100) {
					++ms8_wait[mtch]
				      } else {
					if (ela * 125 <= 2 * 100) {
					  ++ms16_wait[mtch]
					} else {
					  if (ela * 125 <= 4 * 100) {
					    ++ms32_wait[mtch]
					  } else {
					    if (ela * 125 <= 8 * 100) {
					      ++ms64_wait[mtch]
					    } else {
					      if (ela * 125 <= 16 * 100) {
						++ms128_wait[mtch]
					      } else {
						if (ela * 125 <= 32 * 100) {
						  ++ms256_wait[mtch]
						} else {
						  ++msbig_wait[mtch]
						}
					      }
					    }
					  }
					}
				      }
				    }
				  }
				}
			}
			close(fil)
			if (found != 0) {
				if (prev_event != "@" && event_ctr > 10) {
					print "     " event_ctr - 10 " more " \\
						prev_event " wait events..." \\
						>> outf
					printf "%s%9.3f %s%9.3f %s%9.3f\n", \\
						" Min Wait Time=", \\
						min_wait / 100, \\
						"Avg Wait Time=", \\
						(avg_wait / event_ctr) / \\
						100, \\
						"Max Wait Time=", \\
						max_wait / 100 >> outf
				}
				if (totela == 0) {
					print "-----------------------------" \\
						"---------- --------" >> outf
					printf "%-39s%9.3f\n", \\
						"Total", totela / 100 >> outf
				} else {
					print "-----------------------------" \\
						"---------- -------- ----" \\
						>> outf
					printf "%-39s%9.3f %3d%s\n", \\
						"Total", totela / 100, 100, \\
						"%" >> outf
				}
				print "" >> outf
				if (debug != 0) print "  Print wait subtots..."
				print "                           Sub-Totals" \\
					" by Wait Event:" >> outf
				print "" >> outf
				print "                            " \\
					"                        Total" >> outf
				print "                            " \\
					"                        Wait " \\
					"       Number" >> outf
				print "                            " \\
					"                        Time " \\
					"         of    Avg ms" >> outf
				if (totela == 0) {
					print "Oracle Event Name           " \\
						"                       " \\
						"(secs)        Waits" \\
						" per Wait" >> outf
					print "----------------------------" \\
						"-------------------- --" \\
						"------      -------" \\
						" --------" >> outf
				} else {
					print "Oracle Event Name           " \\
						"                       " \\
						"(secs)  Pct   Waits" \\
						" per Wait" >> outf
					print "----------------------------" \\
						"-------------------- --" \\
						"------ ---- -------" \\
						" --------" >> outf
				}
				twait = 0
				nwaits = 0
				x9 = 0
				while (x9 < wait_ctr) {
					++x9
					if (totela == 0) {
						printf \\
						"%-48s%9.3f      %7d%9.2f\n",\\
						  substr(waitevs[x9], 1, 48), \\
						  waitsecs[x9] / 100, \\
						  waitcnts[x9], (1000 * \\
						  waitsecs[x9] / 100) / \\
						  waitcnts[x9] >> outf
					} else {
						printf \\
						"%-48s%9.3f %3d%s %7d%9.2f\n",\\
						  substr(waitevs[x9], 1, 48), \\
						  waitsecs[x9] / 100, \\
						  int(1000 * waitsecs[x9] / \\
						  totela) / 10, "%", \\
						  waitcnts[x9], (1000 * \\
						  waitsecs[x9] / 100) / \\
						  waitcnts[x9] >> outf
					}
					if (length(waitevs[x9]) > 48) \\
						print "  " \\
							substr(waitevs[x9], \\
							49) >> outf
					twait = twait + waitsecs[x9]
					nwaits = nwaits + waitcnts[x9]
				}
				print "----------------------------" \\
					"-------------------- --------" \\
					" ---- ------- --------" >> outf
				printf "%40s%s%9.3f %3d%s %7d%9.2f\n",\\
					" ", "  Total ", twait / 100, \\
					100, "%", nwaits, \\
					(1000 * twait / 100) / nwaits >> outf
				print "" >> outf
				if (debug != 0) print "  Print max wait..."
				print "                            " \\
					"                          Max ms" \\
					>> outf
				print "Oracle Event Name           " \\
					"                         per Wait" \\
					>> outf
				print "----------------------------" \\
					"-------------------- ------------" \\
					>> outf
				x9 = 0
				while (x9 < wait_ctr) {
					++x9
					printf "%-48s%13.2f\n",\\
						substr(waitevs[x9], 1, 48), \\
						1000 * maxwait[x9] / 100 >> outf
					if (length(waitevs[x9]) > 48) \\
						print "  " \\
							substr(waitevs[x9], \\
							49) >> outf
				}
				print "" >> outf
				if (debug != 0) print "  Print wait hists..."
				print "                             Wait" \\
					" Event Histograms" >> outf
				print "" >> outf
				print "                               <<<<" \\
					"<< Count of Wait Events that waited" \\
					" for >>>>>" >> outf
				print "                                   " \\
					"                       16   32  64 " \\
					"  128  >" >> outf
				print "                                0-1" \\
					"  1-2  2-4  4-8 8-16  -32  -64 -128" \\
					" -256 256+" >> outf
				print "Oracle Event Name               ms " \\
					"  ms   ms   ms   ms   ms   ms   ms " \\
					"  ms   ms" >> outf
				print "------------------------------ ----" \\
					" ---- ---- ---- ---- ---- ---- ----" \\
					" ---- ----" >> outf
				x9 = 0
				tot = 0
				tot1 = 0
				tot2 = 0
				tot4 = 0
				tot8 = 0
				tot16 = 0
				tot32 = 0
				tot64 = 0
				tot128 = 0
				tot256 = 0
				totbig = 0
				while (x9 < wait_ctr) {
					++x9
					ms1 = numtostr(ms1_wait[x9])
					ms2 = numtostr(ms2_wait[x9])
					ms4 = numtostr(ms4_wait[x9])
					ms8 = numtostr(ms8_wait[x9])
					ms16 = numtostr(ms16_wait[x9])
					ms32 = numtostr(ms32_wait[x9])
					ms64 = numtostr(ms64_wait[x9])
					ms128 = numtostr(ms128_wait[x9])
					ms256 = numtostr(ms256_wait[x9])
					msbig = numtostr(msbig_wait[x9])
					printf \\
				      "%-30s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s\n",\\
						substr(waitevs[x9], 1, 30), \\
						ms1, ms2, ms4, ms8, ms16, \\
						ms32, ms64, ms128, ms256, \\
						msbig >> outf
					if (length(waitevs[x9]) > 30) \\
						print "  " \\
							substr(waitevs[x9], \\
							31) >> outf
					if (debug != 0) print "  Accum hists..."
					tot1 = tot1 + ms1_wait[x9]
					tot2 = tot2 + ms2_wait[x9]
					tot4 = tot4 + ms4_wait[x9]
					tot8 = tot8 + ms8_wait[x9]
					tot16 = tot16 + ms16_wait[x9]
					tot32 = tot32 + ms32_wait[x9]
					tot64 = tot64 + ms64_wait[x9]
					tot128 = tot128 + ms128_wait[x9]
					tot256 = tot256 + ms256_wait[x9]
					totbig = totbig + msbig_wait[x9]
				}
				if (debug != 0) print "  Grand tot hists..."
				tot = tot1 + tot2 + tot4 + tot8 + tot16 + \\
					tot32 + tot64 + tot128 + tot256 + totbig
				if (tot > 0) {
					t = numtostr(tot)
					t1 = numtostr(tot1)
					t2 = numtostr(tot2)
					t4 = numtostr(tot4)
					t8 = numtostr(tot8)
					t16 = numtostr(tot16)
					t32 = numtostr(tot32)
					t64 = numtostr(tot64)
					t128 = numtostr(tot128)
					t256 = numtostr(tot256)
					tbig = numtostr(totbig)
					print "-----------------------------" \\
						"- ---- ---- ---- ---- ----" \\
						" ---- ---- ---- ---- ----" \\
						>> outf
					printf \\
				      "%-30s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s\n",\\
						" Histogram Bucket" \\
						" Sub-Totals  ", t1, t2, t4, \\
						t8, t16, t32, t64, t128, \\
						t256, tbig >> outf
					printf \\
		  "%-30s%4d%s%4d%s%4d%s%4d%s%4d%s%4d%s%4d%s%4d%s%4d%s%4d%s\n",\\
						" Percent of Total" \\
						" Wait Events ", \\
						int(100 * tot1 / tot), "%", \\
						int(100 * tot2 / tot), "%", \\
						int(100 * tot4 / tot), "%", \\
						int(100 * tot8 / tot), "%", \\
						int(100 * tot16 / tot), "%", \\
						int(100 * tot32 / tot), "%", \\
						int(100 * tot64 / tot), "%", \\
						int(100 * tot128 / tot), "%", \\
						int(100 * tot256 / tot), "%", \\
						int(100 * totbig / tot), "%" \\
						>> outf
					print "" >> outf
				}
			}
			#
			# Waits by Event Name/Object Number
			#
			fil = tmpf "/waitsopend/" substr(hv,1,1) "/" hv
			found = 0
			wait_obj = 0
			while (getline < fil > 0) {
				elem = split(\$0, arr, "~")
				if (elem != 7) continue
				nam = arr[1]
				objn = arr[2]
				if (objn <= 0) continue
				ela = arr[6]
				if (substr(nam,1,17) == \\
					"buffer busy waits" || \\
					substr(nam,1,16) == \\
					"direct path read" || \\
					substr(nam,1,17) == \\
					"direct path write" || \\
					nam == "free buffer waits" || \\
					nam == "write complete waits" \\
					|| nam == \\
					"buffer busy global cache" || \\
					nam == "buffer busy global CR" || \\
					nam == "buffer read retry" || \\
					nam == "control file sequential read"\\
					|| nam == "control file single write" \\
					|| nam == "conversion file read" || \\
					nam == "db file single write" || \\
					nam == "global cache lock busy" || \\
					nam == "global cache lock cleanup" \\
					|| nam == \\
					"global cache lock null to s" \\
					|| nam == \\
					"global cache lock null to x" \\
					|| nam == \\
					"global cache lock open null" \\
					|| nam == \\
					"global cache lock open s" \\
					|| nam == \\
					"global cache lock open x" \\
					|| nam == \\
					"global cache lock s to x" \\
					|| nam == "local write wait" || \\
					substr(nam,1,12) == "db file scat" || \\
					substr(nam,1,11) == "db file seq") {
						file_numb = arr[3] # p1
						block_numb = arr[4] # p2
				} else {
					file_numb = ""
					block_numb = ""
				}
				if (substr(nam,1,11) == "enqueue (Na") {
					rollback_seg = arr[4]	# p2
				} else {
					rollback_seg = 0
				}
				if (10 * ela >= 1) {
					if (found == 0) {
						if (hv == 1) {
							print "            " \\
								"        " \\
								"Unaccounted" \\
								" Wait" \\
								" Events for" \\
								" all" \\
								" cursors" \\
								>> outf
						} else {
							print "            " \\
								"        " \\
								"Significant" \\
								" Wait" \\
								" Events by" \\
								" Object" \\
								>> outf
						}
						print " " >> outf
						print "                 " \\
							"               " \\
							"               " \\
							"     Total" >> outf
						print "                 " \\
							"               " \\
							"               " \\
							"     Wait" >> outf
						print "                 " \\
							"               " \\
							"          Objec" \\
							"t    Time      " \\
							" File   Block" >> outf
						if (totela == 0) {
							print \\
							  "Oracle Event Name" \\
							  "               " \\
							  "          Numbe" \\
							  "r   (secs)     " \\
							  " Numb  Number" \\
							  >> outf
							print \\
							  "-----------------" \\
							  "---------------" \\
							  "------- -------" \\
							  "- --------     " \\
							  " ---- -------" \\
							  >> outf
						} else {
							print \\
							  "Oracle Event Name" \\
							  "               " \\
							  "          Numbe" \\
							  "r   (secs)  Pct" \\
							  " Numb  Number" \\
							  >> outf
							print \\
							  "-----------------" \\
							  "---------------" \\
							  "------- -------" \\
							  "- -------- ----" \\
							  " ---- -------" \\
							  >> outf
						}
						found = 1
						prev_event = "@"
						prev_objn = -9
						event_ctr = 0
					}
					recnum = arr[7]
					if (prev_event != nam || \\
						prev_objn != objn || \\
						event_ctr < 11) {
						if (prev_event != "@" && \\
							event_ctr > 10) {
							print "     " \\
								event_ctr - \\
								10 " more " \\
								prev_event \\
								", Object #" \\
								prev_objn \\
								" wait" \\
								" events..." \\
								>> outf
							printf \\
					   "%s%s%9.3f %s%s%9.3f %s%s%9.3f\n", \\
								"Min Wait", \\
								" Time=", \\
								min_wait / \\
								100, \\
								"Avg Wait", \\
								" Time=", \\
								(avg_wait / \\
								event_ctr) / \\
								100, \\
								"Max Wait", \\
								" Time=", \\
								max_wait / \\
								100>> outf
						}
						if (totela == 0) {
							printf \\
					    "%-39s %8d %8.3f      %4s%8s\n", \\
							  substr(nam, 1, 39), \\
							  objn, ela / 100, \\
							  file_numb, \\
							  block_numb >> outf
						} else {
							printf \\
					    "%-39s %8d %8.3f %3d%s %4s%8s\n", \\
							  substr(nam, 1, 39), \\
							  objn, ela / 100, \\
							  int(1000 * ela / \\
							  totela) / 10, "%", \\
							  file_numb, \\
							  block_numb >> outf
						}
						if (length(nam) > 39) \\
							print "  " \\
							substr(nam, 40) >> outf
						if (substr(nam,1,11) == \\
							"enqueue (Na") {
							rbsn = int(\\
								rollback_seg \\
								/ 65536)
							print "  Rollback" \\
								" segment #" \\
								rbsn \\
								", Slot #" \\
								rollback_seg \\
								- (rbsn * \\
								65536) >> outf
						}
						if (prev_event != nam || \\
							prev_objn != objn) {
							prev_event = nam
							prev_objn = objn
							min_wait = 9999999999999
							avg_wait = 0
							max_wait = 0
							event_ctr = 0
						}
					}
					rest = 0
					++event_ctr
					avg_wait = avg_wait + ela
					if (ela < min_wait) min_wait = ela
					if (ela > max_wait) max_wait = ela
				}
				# Accum subtotals by event name/object
				if (debug != 0) print "  Accum wait subtots..."
				x9 = 0
				mtch = 0
				while (x9 < wait_obj) {
					++x9
					if (file_numb == "") {
						if (waitevs[x9] == nam && \\
							waitobs[x9] == objn) {
							mtch = x9
							x9 = wait_obj
						}
					} else {
						if (waitevs[x9] == \\
							nam " (File " \\
							file_numb ")" && \\
							waitobs[x9] == objn) {
							mtch = x9
							x9 = wait_obj
						}
					}
				}
				if (mtch == 0) {
					++wait_obj
					if (file_numb == "") {
						waitevs[wait_obj] = nam
					} else {
						waitevs[wait_obj] = nam \\
							" (File " file_numb ")"
					}
					waitobs[wait_obj] = objn
					maxwait[wait_obj] = ela
					waitsecs[wait_obj] = ela
					waitcnts[wait_obj] = 1
					ms1_wait[wait_obj] = 0
					ms2_wait[wait_obj] = 0
					ms4_wait[wait_obj] = 0
					ms8_wait[wait_obj] = 0
					ms16_wait[wait_obj] = 0
					ms32_wait[wait_obj] = 0
					ms64_wait[wait_obj] = 0
					ms128_wait[wait_obj] = 0
					ms256_wait[wait_obj] = 0
					msbig_wait[wait_obj] = 0
					mtch = wait_obj
				} else {
					waitsecs[mtch] = waitsecs[mtch] + ela
					if (ela > maxwait[mtch]) \\
						maxwait[mtch] = ela
					++waitcnts[mtch]
				}
				if (debug != 0) print "  Accum wait hists..."
				if (ela * 1000 <= 100) {
					++ms1_wait[mtch]
				} else {
				  if (ela * 500 <= 100) {
				    ++ms2_wait[mtch]
				  } else {
				    if (ela * 250 <= 100) {
				      ++ms4_wait[mtch]
				    } else {
				      if (ela * 125 <= 100) {
					++ms8_wait[mtch]
				      } else {
					if (ela * 125 <= 2 * 100) {
					  ++ms16_wait[mtch]
					} else {
					  if (ela * 125 <= 4 * 100) {
					    ++ms32_wait[mtch]
					  } else {
					    if (ela * 125 <= 8 * 100) {
					      ++ms64_wait[mtch]
					    } else {
					      if (ela * 125 <= 16 * 100) {
						++ms128_wait[mtch]
					      } else {
						if (ela * 125 <= 32 * 100) {
						  ++ms256_wait[mtch]
						} else {
						  ++msbig_wait[mtch]
						}
					      }
					    }
					  }
					}
				      }
				    }
				  }
				}
			}
			close(fil)
			if (found != 0) {
				if (prev_event != "@" && event_ctr > 10) {
					print "     " event_ctr - 10 " more " \\
						prev_event ", Object Number " \\
						prev_objn " wait events..." \\
						>> outf
					printf "%s%9.3f %s%9.3f %s%9.3f\n", \\
						" Min Wait Time=", \\
						min_wait / 100, \\
						"Avg Wait Time=", \\
						(avg_wait / event_ctr) / \\
						100, "Max Wait Time=", \\
						max_wait / 100 >> outf
				}
				if (totela == 0) {
					print "-----------------------------" \\
						"----------" \\
						"          --------" >> outf
					printf "%-48s%9.3f\n", \\
						"Total", totela / 100 >> outf
				} else {
					print "-----------------------------" \\
						"----------" \\
						"          -------- ----" \\
						>> outf
					printf "%-48s%9.3f %3d%s\n", \\
						"Total", totela / 100, 100, \\
						"%" >> outf
				}
				print "" >> outf
				if (debug != 0) print "  Print wait subtots..."
				print "                       Sub-Totals" \\
					" by Wait Event/Object:" >> outf
				print "" >> outf
				print "                            " \\
					"                        Total" >> outf
				print "                            " \\
					"                        Wait " \\
					"       Number" >> outf
				print "                            " \\
					"              Object    Time " \\
					"         of    Avg ms" >> outf
				if (totela == 0) {
					print "Oracle Event Name           " \\
						"              Number" \\
						"   (secs)" \\
						"        Waits per Wait" >> outf
					print "----------------------------" \\
						"----------- --------" \\
						" --------" \\
						"      ------- --------" >> outf
				} else {
					print "Oracle Event Name           " \\
						"              Number" \\
						"   (secs)" \\
						"  Pct   Waits per Wait" >> outf
					print "----------------------------" \\
						"----------- --------" \\
						" --------" \\
						" ---- ------- --------" >> outf
				}
				twait = 0
				nwaits = 0
				x9 = 0
				while (x9 < wait_obj) {
					++x9
					if (totela == 0) {
						printf \\
					   "%-39s %8d %8.3f      %7d%9.2f\n",\\
						  substr(waitevs[x9], 1, 39), \\
						  waitobs[x9], \\
						  waitsecs[x9] / 100, \\
						  waitcnts[x9], (1000 * \\
						  waitsecs[x9] / 100) / \\
						  waitcnts[x9] >> outf
					} else {
						printf \\
					   "%-39s %8d %8.3f %3d%s %7d%9.2f\n",\\
						  substr(waitevs[x9], 1, 39), \\
						  waitobs[x9], \\
						  waitsecs[x9] / 100, \\
						  int(1000 * waitsecs[x9] / \\
						  totela) / 10, "%", \\
						  waitcnts[x9], (1000 * \\
						  waitsecs[x9] / 100) / \\
						  waitcnts[x9] >> outf
					}
					if (length(waitevs[x9]) > 39) \\
						print "  " \\
							substr(waitevs[x9], \\
							40) >> outf
					twait = twait + waitsecs[x9]
					nwaits = nwaits + waitcnts[x9]
				}
				print "----------------------------" \\
					"-----------          --------" \\
					" ---- ------- --------" >> outf
				printf "%-48s %8.3f %3d%s %7d%9.2f\n",\\
					"Total", twait / 100, \\
					100, "%", nwaits, \\
					(1000 * twait / 100) / nwaits >> outf
				print "" >> outf
				if (debug != 0) print "  Print max wait..."
				print "                            " \\
					"              Object   Max ms" >> outf
				print "Oracle Event Name           " \\
					"              Number  per Wait" >> outf
				print "----------------------------" \\
					"----------- -------- ---------" >> outf
				x9 = 0
				while (x9 < wait_obj) {
					++x9
					printf "%-39s %8d %9.2f\n",\\
						substr(waitevs[x9], 1, 39), \\
						waitobs[x9], \\
						1000 * maxwait[x9] / 100 >> outf
					if (length(waitevs[x9]) > 39) \\
						print "  " \\
							substr(waitevs[x9], \\
							40) >> outf
				}
				print "" >> outf
			}
			#
			#	Block Revisits
			#
			if (debug != 0) print "  Print block revisits..."
			h = 0
			revisit_ctr = 0
			fil = tmpf "/waitblocks/s3" hv
			while (getline < fil > 0) {
				if (\$1 == "0") continue
				if (h == 0) {
					print "                      Report" \\
						" of Frequently Visited" \\
						" Blocks" >> outf
					print " " >> outf
					if (print_revisits == 1) {
						print "           This shows" \\
							" which blocks have" \\
							" been re-read" \\
							" multiple times." \\
							>> outf
						print " " >> outf
						print "           Processes" \\
							" with a significant" \\
							" number of" \\
							" frequently visited" \\
							>> outf
						print "                " \\
							"blocks may offer" \\
							" the largest" \\
							" improvement gain." \\
							>> outf
						print " " >> outf
					}
					print "                  Block" \\
						" Visits     File Number" \\
						"    Block Number" >> outf
					print "                 ------" \\
						"------- ---------------" \\
						" ---------------" >> outf
					h = 1
				}
				printf "                 %13d %15d %15d\n", \\
					\$1, \$2, \$3 >> outf
				x9 = 0
				mtch = 0
				while (x9 < revisit_ctr) {
					++x9
					if (revfiles[x9] == \$2) {
						mtch = x9
						x9 = revisit_ctr
					}
				}
				if (mtch == 0) {
					++revisit_ctr
					revfiles[revisit_ctr] = \$2
					revvisits[revisit_ctr] = \$1
					revblocks[revisit_ctr] = \$3
					mtch = revisit_ctr
				} else {
					revvisits[mtch] = revvisits[mtch] + \$1
					revblocks[mtch] = revblocks[mtch] + 1
				}
			}
			close(fil)
			if (h == 1) print " " >> outf
			system("rm -f " tmpf "/waitblocks/s3" hv)
			h = 0
			x9 = 0
			while (x9 < revisit_ctr) {
				++x9
				if (h == 0) {
					print "                      Summary" \\
						" of Frequently Visited" \\
						" Blocks" >> outf
					if (print_revisits == 1) {
						print " " >> outf
						print "         Processes" \\
							" with a" \\
							" significant" \\
							" Revisit Wait Time" \\
							" and a % Revisit" \\
							>> outf
						print "               Wait" \\
							" Time may" \\
							" offer the largest" \\
							" improvement gain." \\
							>> outf
						print_revisits = 0
					}
					print " " >> outf
					print "      File   Total Number" \\
						"  Total Block  Total Wait" \\
						"  Revisit Wait  % Revisit" \\
						>> outf
					print "     Number    of Blocks " \\
						"    Visits     Time (secs" \\
						")  Time (secs)  Wait Time" \\
						>> outf
					print "     ------  ------------" \\
						"  -----------  ----------" \\
						"  ------------  ---------" \\
						>> outf
					h = 1
				}
				totwat = 0
				totblk = 0
				x8 = 0
				while (x8 < wait_ctr) {
					++x8
					if (waitfile[x8] == revfiles[x9]) {
						totwat = totwat + waitsecs[x8]
						totblk = totblk + waitcnts[x8]
					}
				}
				if (totwat == 0 || revvisits[x9] == 0) {
					printf "    %7d  %12d  %11d\n",\\
						revfiles[x9], revblocks[x9], \\
						revvisits[x9] >> outf
				} else {
					printf \\
			    "    %7d  %12d  %11d  %10.3f  %12.3f    %3d%s\n",\\
						revfiles[x9], revblocks[x9], \\
						revvisits[x9], totwat / 100, \\
						(totwat / 100) * \\
						(revvisits[x9] / totblk), \\
						100 * (totwat * \\
						(revvisits[x9] / totblk)) / \\
						totwat, "%" >> outf
				}
			}
		}
		#
		# Print Read Time Histogram Buckets for this cursor
		#
		if (debug != 0) print "  Print read time hist..."
		if (totela > 0 && totreads > 0) {
			found = 0
			ms1_read = 0
			ms1_block = 0
			ms1_time = 0
			ms2_read = 0
			ms2_block = 0
			ms2_time = 0
			ms4_read = 0
			ms4_block = 0
			ms4_time = 0
			ms8_read = 0
			ms8_block = 0
			ms8_time = 0
			ms16_read = 0
			ms16_block = 0
			ms16_time = 0
			ms32_read = 0
			ms32_block = 0
			ms32_time = 0
			ms64_read = 0
			ms64_block = 0
			ms64_time = 0
			ms128_read = 0
			ms128_block = 0
			ms128_time = 0
			ms256_read = 0
			ms256_block = 0
			ms256_time = 0
			msbig_read = 0
			msbig_block = 0
			msbig_time = 0
			fil = tmpf "/waits/" substr(hv,1,1) "/" hv
			while (getline < fil > 0) {
				elem = split(\$0, arr, "~")
				if ((arr[1] == "db file sequential read" || \\
					substr(arr[1],1,12) == \\
					"db file scat") && arr[4] > 0) {
					if (found == 0) {
						print " " >> outf
						print "                Disk" \\
							" Read Time" \\
							" Histogram Summary" \\
							" for this cursor" \\
							>> outf
						print " " >> outf
						print "Millisecond          " \\
							"              I/O  " \\
							"  Pct of Pct of" \\
							" Throughput" \\
							" Throughput" >> outf
						print " Range per    Number " \\
							"  Number   Read Tim" \\
							"e  Total  Total" \\
							"  (Reads/" \\
							"   (DBblocks/" >> outf
						print "   Read      of Reads" \\
							" of Blocks  in secs" \\
							"   Reads Blocks" \\
							"  second)" \\
							"     second)" >> outf
						print "-----------  --------" \\
							" ---------" \\
							" --------- ------" \\
							" ------ ----------" \\
							" ----------" >> outf
						found = 1
					}
					blocks = arr[4]
					ela = arr[5]
					objn = arr[7]
					ms = int((1000 * ela) / 100)
					if (ms <= 1) {
						ms1_read = ms1_read + 1
						ms1_block = ms1_block + blocks
						ms1_time = ms1_time + ela
					} else {
					 if (ms <= 2) {
						ms2_read = ms2_read + 1
						ms2_block = ms2_block + blocks
						ms2_time = ms2_time + ela
					 } else {
					  if (ms <= 4) {
						ms4_read = ms4_read + 1
						ms4_block = ms4_block + blocks
						ms4_time = ms4_time + ela
					  } else {
					   if (ms <= 8) {
						ms8_read = ms8_read + 1
						ms8_block = ms8_block + blocks
						ms8_time = ms8_time + ela
					   } else {
					    if (ms <= 16) {
						ms16_read = ms16_read + 1
						ms16_block = ms16_block + blocks
						ms16_time = ms16_time + ela
					    } else {
					     if (ms <= 32) {
						ms32_read = ms32_read + 1
						ms32_block = ms32_block + blocks
						ms32_time = ms32_time + ela
					     } else {
					      if (ms <= 64) {
						ms64_read = ms64_read + 1
						ms64_block = ms64_block + blocks
						ms64_time = ms64_time + ela
					      } else {
					       if (ms <= 128) {
						ms128_read = ms128_read + 1
						ms128_block = ms128_block + \\
							blocks
						ms128_time = ms128_time + ela
					       } else {
					        if (ms <= 256) {
						 ms256_read = ms256_read + 1
						 ms256_block = ms256_block + \\
							blocks
						 ms256_time = ms256_time + ela
					        } else {
						 msbig_read = msbig_read + 1
						 msbig_block = msbig_block + \\
							blocks
						 msbig_time = msbig_time + ela
					        }
					       }
					      }
					     }
					    }
					   }
					  }
					 }
					}
				}
			}
			close(fil)
			if (ms1_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					0, 1, ms1_read, ms1_block, \\
					ms1_time / 100, \\
					int(100 * ms1_read / totreads), \\
					int(100 * ms1_block / totblocks), \\
					int(ms1_read / (ms1_time / 100)), \\
					int(ms1_block / (ms1_time / 100)) \\
					>> outf
			}
			if (ms2_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					1, 2, ms2_read, ms2_block, \\
					ms2_time / 100, \\
					int(100 * ms2_read / totreads), \\
					int(100 * ms2_block / totblocks), \\
					int(ms2_read / (ms2_time / 100)), \\
					int(ms2_block / (ms2_time / 100)) \\
					>> outf
			}
			if (ms4_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					2, 4, ms4_read, ms4_block, \\
					ms4_time / 100, \\
					int(100 * ms4_read / totreads), \\
					int(100 * ms4_block / totblocks), \\
					int(ms4_read / (ms4_time / 100)), \\
					int(ms4_block / (ms4_time / 100)) \\
					>> outf
			}
			if (ms8_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					4, 8, ms8_read, ms8_block, \\
					ms8_time / 100, \\
					int(100 * ms8_read / totreads), \\
					int(100 * ms8_block / totblocks), \\
					int(ms8_read / (ms8_time / 100)), \\
					int(ms8_block / (ms8_time / 100)) \\
					>> outf
			}
			if (ms16_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					8, 16, ms16_read, ms16_block, \\
					ms16_time / 100, \\
					int(100 * ms16_read / totreads), \\
					int(100 * ms16_block / totblocks), \\
					int(ms16_read / \\
					(ms16_time / 100)), \\
					int(ms16_block / \\
					(ms16_time / 100)) >> outf
			}
			if (ms32_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					16, 32, ms32_read, ms32_block, \\
					ms32_time / 100, \\
					int(100 * ms32_read / totreads), \\
					int(100 * ms32_block / totblocks), \\
					int(ms32_read / \\
					(ms32_time / 100)), \\
					int(ms32_block / \\
					(ms32_time / 100)) >> outf
			}
			if (ms64_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					32, 64, ms64_read, ms64_block, \\
					ms64_time / 100, \\
					int(100 * ms64_read / totreads), \\
					int(100 * ms64_block / totblocks), \\
					int(ms64_read / \\
					(ms64_time / 100)), \\
					int(ms64_block / \\
					(ms64_time / 100)) >> outf
			}
			if (ms128_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					64, 128, ms128_read, ms128_block, \\
					ms128_time / 100, \\
					int(100 * ms128_read / totreads), \\
					int(100 * ms128_block / totblocks), \\
					int(ms128_read / \\
					(ms128_time / 100)), \\
					int(ms128_block / \\
					(ms128_time / 100)) >> outf
			}
			if (ms256_read > 0) {
				printf \\
				    "%4d - %4d%10d%10d%10.2f%7d%7d%11d%11d\n",\\
					128, 256, ms256_read, ms256_block, \\
					ms256_time / 100, \\
					int(100 * ms256_read / totreads), \\
					int(100 * ms256_block / totblocks), \\
					int(ms256_read / \\
					(ms256_time / 100)), \\
					int(ms256_block / \\
					(ms256_time / 100)) >> outf
			}
			if (msbig_read > 0) {
				printf \\
				  "%4d%s      %10d%10d%10.2f%7d%7d%11d%11d\n",\\
					256, "+", msbig_read, msbig_block, \\
					msbig_time / 100, \\
					int(100 * msbig_read / totreads), \\
					int(100 * msbig_block / totblocks), \\
					int(msbig_read / \\
					(msbig_time / 100)), \\
					int(msbig_block / \\
					(msbig_time / 100)) >> outf
			}
			if (found != 0) {
				print "-----------  -------- ---------" \\
					" --------- ------ ------ ----------" \\
					" ----------" >> outf
				printf \\
				  "   Total   %10d%10d%10.2f%7d%7d%11d%11d\n",\\
					totreads, totblocks, \\
					totread_time / 100, 100, 100, \\
					int(totreads / \\
					(totread_time / 100)), \\
					int(totblocks / \\
					(totread_time / 100)) >> outf
				print " " >> outf
			}
		}
		#
		# Print any Errors
		#
		if (debug != 0) print "  Print errors..."
		if (err != "x") {
			print "Oracle Parse Error: " err " on trace line " \\
				recn >> outf
		}
		found = 0
		fil = tmpf "/errors/" hv
		while (getline < fil > 0) {
			elem = split(\$0, arr, "~")
			if (elem != 3) {
				print "Unexpected number of columns (" NF \\
					") in errors line for hash value " hv \\
					":"
				print \$0
				continue
			}
			err = arr[1]
			recnum = arr[2]
			errtim = arr[3]
			if (debug != 0) print "    Read Error: " err " " \
				recnum " " errtim
			er = "ORA-" substr("00000",1,5-length(err)) err
			#Ignore error time, since it may be more than 2gig
			#xx = ymdhms(errtim)
			#if (debug != 0) print "    at time: " xx
			print "Oracle Error " er " on trace line " \\
				recnum >> outf
			found = 1
		}
		close(fil)
		if (found != 0) {
			print "" >> outf
		}
		if (cur != 9999) {
			if (debug != 0) print "  Print misses..."
			if (stmissparse != 0) print "Misses in library cache" \\
				" during parse: " stmissparse >> outf
			if (stmissexec != 0) print "Misses in library cache" \\
				" during execute: " stmissexec >> outf
			if (stmissfetch != 0) print "Misses in library cache" \\
				" during fetch: " stmissfetch >> outf
			if (op_goal == 1) print "Optimizer goal: All_Rows" \\
				>> outf
			if (op_goal == 2) print "Optimizer goal: First_Rows" \\
				>> outf
			if (op_goal == 3) print "Optimizer goal: Rule" >> outf
			if (op_goal == 4) print "Optimizer goal: Choose" >> outf
			if (op_goal > 4) print \\
				"Unexpected optimizer goal of " \\
				op_goal " on line " NR
			if (uid == "0") {
				print "Parsing user id: SYS" >> outf
			} else {
				if (uid != "x") {
					print "Parsing user id: " uid >> outf
				}
			}
			#
			# Get any module and action for this cursor
			#
			fil = tmpf "/module/" hv
			while (getline < fil > 0) {
				print "Module: " \$0 >> outf
			}
			close(fil)
			fil = tmpf "/action/" hv
			while (getline < fil > 0) {
				print "Action: " \$0 >> outf
			}
			close(fil)
			if (sqlid != ".") print "SQL ID: " sqlid >> outf
			#
			# Print any Transaction Info
			#
			if (debug != 0) print "  Print transaction..."
			found = 0
			fil = tmpf "/xctend/" hv
			while (getline < fil > 0) {
				print \$0 >> outf
				found = 1
			}
			close(fil)
			if (found != 0) print "" >> outf
			#
			# Print any non-segment-level Optimizer Statistics
			#
			if (debug != 0) print "  Print optimizer stats..."
			n = 0
			fnd = 0
			fil = tmpf "/stats/" substr(hv,1,1) "/" hv
			while (getline < fil > 0) {
				elem = split(\$0, arr, "~")
				if (elem != 14) {
					print "Unexpected number of columns" \\
						" (" NF ") in errors line" \\
						" for stats value " hv ":"
					print "elem is " elem
					print \$0
					continue
				}
				if (fnd == 0) {
					print "" >> outf
					print "      Rows  Row Source" \\
						" Operation" >> outf
					print "----------  ----------" \\
						"------------" \\
						"-------------------" \\
						"----------" >> outf
					fnd = 1
				}
				# Reinsert any tildes that I previously replaced
				gsub("!@#","~",arr[11])
				# Calculate indentation and print STAT info
				found = 0
				nn = 0
				while (nn < n) {
					++nn
					if (stat_id[nn] == arr[3]) {
						found = nn
						nn = n
					}
				}
				if (found == 0) {
					link = 0
				} else {
					link = stat_indent[found] + 1
				}
				++n
				stat_id[n] = arr[2]
				stat_indent[n] = link
				indent = substr( \\
			 "                                                  ",\\
					1, 2 + link)
				printf "%10d%s%s\n", arr[1], indent, \\
					arr[11] >> outf
				if (arr[9] != 0 || arr[10] != 0) {
					printf \\
				"%sPartition Start: %s  Partition End: %s\n", \\
						"            ", \\
						arr[9], arr[10] >> outf
				}
			}
			close(fil)
			if (fnd != 0) print "" >> outf
			#
			# Print any segment-level Optimizer Statistics
			# (Oracle 9.2)
			#
			found = 0
			t4 = 0
			t5 = 0
			t6 = 0
			t7 = 0
			t8 = 0
			cost_flag = 0
			if (debug != 0) print "  Print segment stats..."
			fil = tmpf "/stats/" substr(hv,1,1) "/" hv
			while (getline < fil > 0) {
				elem = split(\$0, arr, "~")
				if (elem != 14) {
					print "Unexpected number of columns" \\
						" (" NF ") in errors line" \\
						" for stats value " hv ":"
					print "elem is " elem
					print \$0
					continue
				}
				if (arr[5] != 0 || arr[8] != 0) {
					if (found == 0) {
						if (arr[12] == ".") {
						  print "                   " \\
							"         " \\
							"Segment-Level" \\
							" Statistics" >> outf
						  print "                " \\
							"                "\\
							"                " \\
							"                " \\
							" Elapsed Time" >> outf
						  print "   Object ID" \\
							"        Logical I/Os"\\
							"      Phys Reads" \\
							"     Phys Writes" \\
							"  (seconds)" >> outf
						  print "   -------------" \\
							" ---------------"\\
							" ---------------" \\
							" ---------------" \\
							" ------------" >> outf
						} else {
						  print "                   " \\
							"         " \\
							"Segment-Level" \\
							" Statistics" >> outf
						  print "                " \\
							"           " \\
							"     Phys   Phys " \\
							" Elapsed Time" >> outf
						  print "   Object ID  " \\
							" Logical I/Os" \\
							"     Reads Writes" \\
							"  (seconds)  " \\
							"   Cost     Size" \\
							"   Card" >> outf
						  print "   -----------" \\
							" ------------" \\
							" --------- ------" \\
							" ------------" \\
							" ------ --------" \\
							" ------" >> outf
						  cost_flag = 1
						}
					}
					if (cost_flag == 0) {
					  printf \\
					  "   %13d %15d %15d %15d %12.6f\n", \\
						arr[4], arr[5], arr[6], \\
						arr[7], arr[8] / 1000000 >> outf
					} else {
					  printf \\
			       "   %11d %12d %9d %6d %12.6f %6d %8d %6d\n", \\
						arr[4], arr[5], arr[6], \\
						arr[7], arr[8] / 1000000, \\
						arr[12], arr[13], arr[14] \\
						>> outf
					}
					t4 = t4 + arr[5]
					t5 = t5 + arr[6]
					t6 = t6 + arr[7]
					t7 = t7 + arr[8]
					t8 = t8 + arr[12]
					found = 1
				}
			}
			close(fil)
			if (t4 != 0 || t7 != 0) {
				if (cost_flag == 0) {
					print "   -------------" \\
						" ---------------" \\
						" ---------------" \\
						" ---------------" \\
						" ------------" >> outf
					printf \\
				    "       Total %19d %15d %15d %12.6f\n", \\
						t4, t5, t6, t7 / 1000000 >> outf
				} else {
					print "   -----------" \\
						" ------------" \\
						" ---------" \\
						" ------" \\
						" ------------ ------" >> outf
					printf \\
				  "         Total %12d %9d %6d %12.6f %6d\n", \\
						t4, t5, t6, t7 / 1000000, t8 \\
						>> outf
				}
			}
			if (found != 0) print "" >> outf
		}
	}
	close(curfil)
	#
	# Print any RPC info
	#
	if (debug != 0) print "  Read any RPC calls..."
	x = 0
	fil = tmpf "/rpccalls"
	while (getline < fil > 0) {
		++x
		rpc_text = \$0
		#
		# Accum any RPC cpu/elapsed times for this RPC call
		#
		stcount = 0
		stcpu = 0
		stelapsed = 0
		fil2 = tmpf "/rpccpu/" x
		while (getline < fil2 > 0) {
			if (NF != 2) {
				print "Unexpected number of columns" \\
					" (" NF ") in rpccpu line" \\
					" for index " x ":"
				print \$0
				continue
			}
			++stcount
			stcpu = stcpu + \$1
			stelapsed = stelapsed + \$2
		}
		close(fil2)
		if (x == 1) {
			print "##########################################" \\
				"######################################" >> outf
			print "                         Remote Procedure" \\
				" Call Summary" >> outf
			print "" >> outf
			print "         (The total elapsed time for all RPC" \\
				" EXEC calls is shown in the" >> outf
			print "       ORACLE TIMING ANALYSIS section of this" \\
				" report as \\"RPC EXEC Calls\\")" >> outf
			print "" >> outf
			print "RPC Text:                                    " \\
				"        Execs CPU secs Elapsed secs" >> outf
			print "---------------------------------------------" \\
				"------- ----- -------- ------------" >> outf
		}
		while (length(rpc_text) > 52) {
			print substr(rpc_text, 1, 52) >> outf
			rpc_text = substr(rpc_text, 53)
		}
		printf "%-52s %5d %8.2f %12.2f\n", \\
			rpc_text, stcount, stcpu / 100, stelapsed / 100 >> outf
		#
		# Print any RPC bind variables
		#
		if (debug != 0) print "  Print RPC bind variables..."
		cnt = 0
		fil2 = tmpf "/rpcbinds/" x
		while (getline < fil2 > 0) {
			++cnt
			if (cnt <= 100) print \$0 >> outf
		}
		close(fil2)
		if (cnt > 0) print "     Total of " cnt " RPC bind variables" \\
			>> outf
		print "" >> outf
	}
	close(fil)
	#
	# Print totals by module
	#
	if (debug == 0) {
		print "Creating report totals..."
	} else {
		print "  Print module totals..."
	}
	fil = tmpf "/modules"
	found = 0
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 10) {
			print "Unexpected number of columns (" elem \\
				") in module totals line #" NR ":"
			print \$0
			continue
		}
		dep = arr[9]
		if (found == 0) {
			print "###################################" \\
				"#################################" \\
				"############" >> outf
			print "" >> outf
			print "                      TOTALS FOR ALL" \\
				" STATEMENTS BY MODULE" >> outf
			print "" >> outf
			print "Module   count      cpu    elapsed" \\
				"       disk      query    current" \\
				"       rows" >> outf
			print "------- ------ -------- ----------" \\
				" ---------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			prev_module = "@"
			tcount = 0
			tcpu = 0
			telapsed = 0
			tdisk = 0
			tquery = 0
			tcurrent = 0
			trows = 0
		}
		module = arr[1]
		if (prev_module != module) {
			if (prev_module != "@") xx = print_prev_module()
			prev_module = module
			stcount = 0
			stcpu = 0
			stelapsed = 0
			stdisk = 0
			stquery = 0
			stcurrent = 0
			strows = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
		}
		++stcount
		stcpu = stcpu + arr[2]
		stelapsed = stelapsed + arr[3]
		stdisk = stdisk + arr[4]
		stquery = stquery + arr[5]
		stcurrent = stcurrent + arr[6]
		strows = strows + arr[7]
	}
	close(fil)
	if (found != 0) {
		xx = print_prev_module()
		print "        ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", tcount, tcpu / 100, \\
			telapsed / 100, tdisk, tquery, tcurrent, trows >> outf
		print "" >> outf
	}
	#
	# Print totals by action
	#
	if (debug > 0) {
		print "  Print action summary..."
	}
	fil = tmpf "/actions"
	found = 0
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 10) {
			print "Unexpected number of columns (" elem \\
				") in action totals line #" NR ":"
			print \$0
			continue
		}
		dep = arr[9]
		if (found == 0) {
			print "###################################" \\
				"#################################" \\
				"############" >> outf
			print "" >> outf
			print "                      TOTALS FOR ALL" \\
				" STATEMENTS BY ACTION" >> outf
			print "" >> outf
			print "Action   count      cpu    elapsed" \\
				"       disk      query    current" \\
				"       rows" >> outf
			print "------- ------ -------- ----------" \\
				" ---------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			prev_action = "@"
			tcount = 0
			tcpu = 0
			telapsed = 0
			tdisk = 0
			tquery = 0
			tcurrent = 0
			trows = 0
		}
		action = arr[1]
		if (prev_action != action) {
			if (prev_action != "@") xx = print_prev_action()
			prev_action = action
			stcount = 0
			stcpu = 0
			stelapsed = 0
			stdisk = 0
			stquery = 0
			stcurrent = 0
			strows = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
		}
		++stcount
		stcpu = stcpu + arr[2]
		stelapsed = stelapsed + arr[3]
		stdisk = stdisk + arr[4]
		stquery = stquery + arr[5]
		stcurrent = stcurrent + arr[6]
		strows = strows + arr[7]
	}
	close(fil)
	if (found != 0) {
		xx = print_prev_action()
		print "        ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", tcount, tcpu / 100, \\
			telapsed / 100, tdisk, tquery, tcurrent, trows >> outf
		print "" >> outf
	}
	#
	# Init for command type summaries
	#
	if (debug > 0) print "  Print command type summaries..."
	maxcmdtyp = 0
	fil = tmpf "/cmdtypes"
	while (getline < fil > 0) {
		if (NF != 10) {
			print "Unexpected number of columns (" NF \\
				") in cmdtypes line #" NR ":"
			print \$0
			continue
		}
		if (\$1 > maxcmdtyp) maxcmdtyp = \$1
	}
	close(fil)
	for (x=77;x<=maxcmdtyp;x++) cmdtypstrs[x] = x ""
	cmdtypstrs[0] = "UNKNOWN"
	cmdtypstrs[1] = "create table"
	cmdtypstrs[2] = "insert"
	cmdtypstrs[3] = "select"
	cmdtypstrs[4] = "create cluster"
	cmdtypstrs[5] = "alter cluster"
	cmdtypstrs[6] = "update"
	cmdtypstrs[7] = "delete"
	cmdtypstrs[8] = "drop cluster"
	cmdtypstrs[9] = "create index"
	cmdtypstrs[10] = "drop index"
	cmdtypstrs[11] = "alter index"
	cmdtypstrs[12] = "drop table"
	cmdtypstrs[13] = "create sequence"
	cmdtypstrs[14] = "alter sequence"
	cmdtypstrs[15] = "alter table"
	cmdtypstrs[16] = "drop sequence"
	cmdtypstrs[17] = "grant"
	cmdtypstrs[18] = "revoke"
	cmdtypstrs[19] = "create synonym"
	cmdtypstrs[20] = "drop synonym"
	cmdtypstrs[21] = "create view"
	cmdtypstrs[22] = "drop view"
	cmdtypstrs[23] = "validate index"
	cmdtypstrs[24] = "create procedure"
	cmdtypstrs[25] = "alter procedure"
	cmdtypstrs[26] = "lock table"
	cmdtypstrs[27] = "no operation"
	cmdtypstrs[28] = "rename"
	cmdtypstrs[29] = "comment"
	cmdtypstrs[30] = "audit"
	cmdtypstrs[31] = "noaudit"
	cmdtypstrs[32] = "create database link"
	cmdtypstrs[33] = "drop database link"
	cmdtypstrs[34] = "create database"
	cmdtypstrs[35] = "alter database"
	cmdtypstrs[36] = "create rollback segment"
	cmdtypstrs[37] = "alter rollback segment"
	cmdtypstrs[38] = "drop rollback segment"
	cmdtypstrs[39] = "create tablespace"
	cmdtypstrs[40] = "alter tablespace"
	cmdtypstrs[41] = "drop tablespace"
	cmdtypstrs[42] = "alter session"
	cmdtypstrs[43] = "alter use"
	cmdtypstrs[44] = "commit"
	cmdtypstrs[45] = "rollback"
	cmdtypstrs[46] = "savepoint"
	cmdtypstrs[47] = "pl/sql execute"
	cmdtypstrs[48] = "set transaction"
	cmdtypstrs[49] = "alter system switch log"
	cmdtypstrs[50] = "explain"
	cmdtypstrs[51] = "create user"
	cmdtypstrs[52] = "create role"
	cmdtypstrs[53] = "drop user"
	cmdtypstrs[54] = "drop role"
	cmdtypstrs[55] = "set role"
	cmdtypstrs[56] = "create schema"
	cmdtypstrs[57] = "create control file"
	cmdtypstrs[58] = "alter tracing"
	cmdtypstrs[59] = "create trigger"
	cmdtypstrs[60] = "alter trigger"
	cmdtypstrs[61] = "drop trigger"
	cmdtypstrs[62] = "analyze table"
	cmdtypstrs[63] = "analyze index"
	cmdtypstrs[64] = "analyze cluster"
	cmdtypstrs[65] = "create profile"
	cmdtypstrs[66] = "drop profile"
	cmdtypstrs[67] = "alter profile"
	cmdtypstrs[68] = "drop procedure"
	cmdtypstrs[69] = "drop procedure"
	cmdtypstrs[70] = "alter resource cost"
	cmdtypstrs[71] = "create snapshot log"
	cmdtypstrs[72] = "alter snapshot log"
	cmdtypstrs[73] = "drop snapshot log"
	cmdtypstrs[74] = "create snapshot"
	cmdtypstrs[75] = "alter snapshot"
	cmdtypstrs[76] = "drop snapshot"
	cmdtypstrs[79] = "alter role"
	cmdtypstrs[85] = "truncate table"
	cmdtypstrs[86] = "truncate couster"
	cmdtypstrs[88] = "alter view"
	cmdtypstrs[91] = "create function"
	cmdtypstrs[92] = "alter function"
	cmdtypstrs[93] = "drop function"
	cmdtypstrs[94] = "create package"
	cmdtypstrs[95] = "alter package"
	cmdtypstrs[96] = "drop package"
	cmdtypstrs[97] = "create package body"
	cmdtypstrs[98] = "alter package body"
	cmdtypstrs[99] = "drop package body"
	#
	# Print total Wait time by cursor
	#
	if (debug != 0) print "  Print wait time by cursor totals..."
	fil = tmpf "/waits/totcur"
	found = 0
	prev_cur = 99999
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 5) {
			print "Unexpected number of columns (" elem \\
				") in waits by cursor line #" NR ":"
			print \$0
			continue
		}
		cur = arr[1]
		nam = arr[2]
		p1 = arr[3]
		p2 = arr[4]
		ela = arr[5]
		if (prev_cur != cur) {
			if (prev_cur != 99999) xx = print_prev_curwait()
			prev_cur = cur
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
		}
		if (prev_nam != nam) {
			xx = print_prev_curwait()
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
		}
		namela = namela + ela
	}
	close(fil)
	if (prev_cur != 99999) xx = print_prev_curwait()
	if (found == 1) print "" >> outf
	#
	# Print total Wait time by module/wait event
	#
	if (debug != 0) print "  Print wait time by module totals..."
	fil = tmpf "/waits/totmod"
	found = 0
	print_module = 1
	prev_module = "@"
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 5) {
			print "Unexpected number of columns (" elem \\
				") in waits by module line #" NR ":"
			print \$0
			continue
		}
		module = arr[1]
		nam = arr[2]
		p1 = arr[3]
		p2 = arr[4]
		ela = arr[5]
		if (prev_module != module) {
			if (prev_module != "@") xx = print_prev_modwait()
			prev_module = module
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
			print_module = 1
		}
		if (prev_nam != nam) {
			xx = print_prev_modwait()
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
		}
		namela = namela + ela
	}
	close(fil)
	if (prev_module != "@") xx = print_prev_modwait()
	if (found == 1) print "" >> outf
	#
	# Print total Wait time by action/wait event
	#
	if (debug != 0) print "  Print wait time by action totals..."
	fil = tmpf "/waits/totact"
	found = 0
	prev_action = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 5) {
			print "Unexpected number of columns (" elem \\
				") in waits by action line #" NR ":"
			print \$0
			continue
		}
		action = arr[1]
		nam = arr[2]
		p1 = arr[3]
		p2 = arr[4]
		ela = arr[5]
		if (prev_action != action) {
			if (prev_action != "@") xx = print_prev_actwait()
			prev_action = action
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
			print_action = 1
		}
		if (prev_nam != nam) {
			xx = print_prev_actwait()
			prev_nam = nam
			prev_p1 = p1
			prev_p2 = p2
			namela = 0
		}
		namela = namela + ela
	}
	close(fil)
	if (prev_action != "@") xx = print_prev_actwait()
	if (found == 1) print "" >> outf
	#
	# Print non-recursive totals by command type for user
	#
	if (debug != 0) print "  Print non-recursive totals..."
	fil = tmpf "/cmdtypes"
	found = 0
	while (getline < fil > 0) {
		if (NF != 10) continue
		dep = \$9
		if (dep != 0) continue		# Skip if recursive
		if (found == 0) {
			print "###################################" \\
				"#################################" \\
				"############" >> outf
			print "" >> outf
			print "       TOTALS FOR ALL NON-RECURSIVE" \\
				" STATEMENTS BY COMMAND TYPE FOR" \\
				" USERS" >> outf
			print "" >> outf
			print "cmdtyp   count      cpu    elapsed" \\
				"       disk      query    current" \\
				"       rows" >> outf
			print "------- ------ -------- ----------" \\
				" ---------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			prev_cmd = "@"
			tcount = 0
			tcpu = 0
			telapsed = 0
			tdisk = 0
			tquery = 0
			tcurrent = 0
			trows = 0
		}
		cmd = \$1
		if (prev_cmd != cmd) {
			if (prev_cmd != "@") {
				xx = print_prev_command_type()
			}
			prev_cmd = cmd
			stcount = 0
			stcpu = 0
			stelapsed = 0
			stdisk = 0
			stquery = 0
			stcurrent = 0
			strows = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
		}
		++stcount
		stcpu = stcpu + \$2
		stelapsed = stelapsed + \$3
		stdisk = stdisk + \$4
		stquery = stquery + \$5
		stcurrent = stcurrent + \$6
		strows = strows + \$7
	}
	close(fil)
	if (found != 0) {
		xx = print_prev_command_type()
		print "------- ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", tcount, tcpu / 100, \\
			telapsed / 100, tdisk, tquery, tcurrent, trows >> outf
		print "" >> outf
	}
	#
	# Print recursive totals by command type for user
	#
	if (debug != 0) print "  Print recursive totals..."
	fil = tmpf "/cmdtypes"
	found = 0
	while (getline < fil > 0) {
		if (NF != 10) continue
		uid = \$8
		dep = \$9
		if (dep == 0) continue		# Skip if non-recursive
		if (uid == 0) continue		# Skip if SYS user
		if (found == 0) {
			print "###################################" \\
				"#################################" \\
				"############" >> outf
			print "" >> outf
			print "         TOTALS FOR ALL RECURSIVE" \\
				" STATEMENTS BY COMMAND TYPE FOR" \\
				" USERS" >> outf
			print "" >> outf
			print "cmdtyp   count      cpu    elapsed" \\
				"       disk      query    current" \\
				"       rows" >> outf
			print "------- ------ -------- ----------" \\
				" ---------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			prev_cmd = "@"
			tcount = 0
			tcpu = 0
			telapsed = 0
			tdisk = 0
			tquery = 0
			tcurrent = 0
			trows = 0
		}
		cmd = \$1
		if (prev_cmd != cmd) {
			if (prev_cmd != "@") {
				xx = print_prev_command_type()
			}
			prev_cmd = cmd
			stcount = 0
			stcpu = 0
			stelapsed = 0
			stdisk = 0
			stquery = 0
			stcurrent = 0
			strows = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
		}
		++stcount
		stcpu = stcpu + \$2
		stelapsed = stelapsed + \$3
		stdisk = stdisk + \$4
		stquery = stquery + \$5
		stcurrent = stcurrent + \$6
		strows = strows + \$7
	}
	close(fil)
	if (found != 0) {
		xx = print_prev_command_type()
		print "------- ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", tcount, tcpu / 100, \\
			telapsed / 100, tdisk, tquery, tcurrent, trows >> outf
		print "" >> outf
	}
	#
	# Print recursive totals by command type for SYS
	#
	if (debug != 0) print "  Print recursive sys totals..."
	fil = tmpf "/cmdtypes"
	found = 0
	while (getline < fil > 0) {
		if (NF != 10) continue
		uid = \$8
		dep = \$9
		if (dep == 0) continue		# Skip if non-recursive
		if (uid != 0) continue		# Skip if non-SYS user
		if (found == 0) {
			print "###################################" \\
				"#################################" \\
				"############" >> outf
			print "" >> outf
			print "          TOTALS FOR ALL RECURSIVE" \\
				" STATEMENTS BY COMMAND TYPE FOR" \\
				" SYS" >> outf
			print "" >> outf
			print "cmdtyp   count      cpu    elapsed" \\
				"       disk      query    current" \\
				"       rows" >> outf
			print "------- ------ -------- ----------" \\
				" ---------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			prev_cmd = "@"
			tcount = 0
			tcpu = 0
			telapsed = 0
			tdisk = 0
			tquery = 0
			tcurrent = 0
			trows = 0
		}
		cmd = \$1
		if (prev_cmd != cmd) {
			if (prev_cmd != "@") {
				xx = print_prev_command_type()
			}
			prev_cmd = cmd
			stcount = 0
			stcpu = 0
			stelapsed = 0
			stdisk = 0
			stquery = 0
			stcurrent = 0
			strows = 0
			stmissparse = 0
			stmissexec = 0
			stmissfetch = 0
		}
		++stcount
		stcpu = stcpu + \$2
		stelapsed = stelapsed + \$3
		stdisk = stdisk + \$4
		stquery = stquery + \$5
		stcurrent = stcurrent + \$6
		strows = strows + \$7
	}
	close(fil)
	if (found != 0) {
		xx = print_prev_command_type()
		print "------- ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", tcount, tcpu / 100, \\
			telapsed / 100, tdisk, tquery, tcurrent, trows >> outf
		print "" >> outf
	}
	totcounts = 0
	totcpus = 0
	totelapseds = 0
	totdisks = 0
	totquerys = 0
	totcurrents = 0
	totrowss = 0
	totunaccs = 0
	h = 0
	x9 = 0
	while (x9 < totn) {
		++x9
		if (h == 0) {
			print "############################################" \\
				"####################################" >> outf
			print "" >> outf
			print "                OVERALL TOTALS FOR ALL" \\
				" NON-RECURSIVE STATEMENTS" >> outf
			print "" >> outf
			print "call     count      cpu    elapsed       disk" \\
				"      query    current       rows" >> outf
			print "------- ------ -------- ---------- ----------" \\
				" ---------- ---------- ----------" >> outf
			h = 1
		}
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			opnames[x9], otcounts[x9], otcpus[x9] / 100, \\
			otelapseds[x9] / 100, otdisks[x9], otquerys[x9], \\
			otcurrents[x9], otrowss[x9] >> outf
		totcounts = totcounts + otcounts[x9]
		totcpus = totcpus + otcpus[x9]
		totelapseds = totelapseds + otelapseds[x9]
		totdisks = totdisks + otdisks[x9]
		totquerys = totquerys + otquerys[x9]
		totcurrents = totcurrents + otcurrents[x9]
		totrowss = totrowss + otrowss[x9]
		totunaccs = totunaccs + otunaccs[x9]
	}
	if (h == 1) {
		print "------- ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", totcounts, totcpus / 100, totelapseds / 100, \\
			totdisks, totquerys, totcurrents, totrowss >> outf
		if (totunaccs != 0) {
			print " " >> outf
			printf "  Unaccounted-for time: %10.2f\n", \\
				totunaccs / 100 >> outf
			print " " >> outf
			print "  Large amounts of unaccounted-for time can" \\
				" indicate excessive context" >> outf
			print "  switching, paging, swapping, CPU run" \\
				" queues, or uninstrumented Oracle code." \\
				>> outf
			print " " >> outf
		}
		print "" >> outf
	}
	h = 0
	totcounts = 0
	totcpus = 0
	totelapsedsr = 0
	totdisks = 0
	totquerys = 0
	totcurrents = 0
	totrowss = 0
	totunaccs = 0
	x9 = 0
	while (x9 < totnr) {
		++x9
		if (h == 0) {
			print "###########################################" \\
				"#####################################" >> outf
			print "" >> outf
			print "                  OVERALL TOTALS FOR ALL" \\
				" RECURSIVE STATEMENTS" >> outf
			print "" >> outf
			print "call     count      cpu    elapsed       disk" \\
				"      query    current       rows" >> outf
			print "------- ------ -------- ---------- ----------" \\
				" ---------- ---------- ----------" >> outf
			h = 1
		}
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			ropnames[x9], rotcounts[x9], rotcpus[x9] / 100, \\
			rotelapseds[x9] / 100, rotdisks[x9], \\
			rotquerys[x9], rotcurrents[x9], rotrowss[x9] >> outf
		totcounts = totcounts + rotcounts[x9]
		totcpus = totcpus + rotcpus[x9]
		totelapsedsr = totelapsedsr + rotelapseds[x9]
		totdisks = totdisks + rotdisks[x9]
		totquerys = totquerys + rotquerys[x9]
		totcurrents = totcurrents + rotcurrents[x9]
		totrowss = totrowss + rotrowss[x9]
		totunaccs = totunaccs + rotunaccs[x9]
	}
	if (h == 1) {
		print "------- ------ -------- ---------- ----------" \\
			" ---------- ---------- ----------" >> outf
		printf "%-8s%6d %8.2f %10.2f %10d %10d %10d %10d\n", \\
			"total", totcounts, totcpus / 100, \\
			totelapsedsr / 100, totdisks, totquerys, \\
			totcurrents, totrowss >> outf
		if (totunaccs != 0) {
			print " " >> outf
			printf "  Unaccounted-for time: %10.2f\n", \\
				totunaccs / 100 >> outf
			print " " >> outf
			print "  Large amounts of unaccounted-for time can" \\
				" indicate excessive context" >> outf
			print "  switching, paging, swapping, CPU run" \\
				" queues, or uninstrumented Oracle code." \\
				>> outf
			print " " >> outf
		}
		print "" >> outf
	}
	#
	# Print summary by descending elapsed time
	#
	if (debug != 0) print "  Print elapsed summary totals..."
	grtelapsed = 0
	fil = tmpf "/elap"
	system("sort -n -r " tmpf "/elap > " tmpf "/srt.tmp")
	system("mv -f " tmpf "/srt.tmp " tmpf "/elap")
	found = 0
	while (getline < fil > 0) {
		if (NF != 9) {
			print "Unexpected number of columns (" NF \\
				") in elap line for hash value " hv ":"
			print \$0
			continue
		}
		if (int(100 * \$5 / 100) == 0 && \\
			int(100 * \$1 / 100) == 0 && \\
			int(100 * \$6 / 100) == 0) continue
		if (found == 0) {
			print "#####################################" \\
				"###################################" \\
				"########" >> outf
			print "" >> outf
			print "       SUMMARY OF TOTAL CPU TIME," \\
				" ELAPSED TIME, WAITS, AND I/O PER" \\
				" CURSOR" >> outf
			print "                       (SORTED BY" \\
				" DESCENDING ELAPSED TIME)" >> outf
			print "" >> outf
			print " Cur User  Total     CPU     Elapsed" \\
				"      Wait   Physical Consistent" \\
				"    Current" >> outf
			print " ID#  ID   Calls     Time      Time " \\
				"      Time     Reads     Reads  " \\
				"     Reads" >> outf
			print "---- ---- ------ -------- ----------" \\
				" --------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			telapsed = 0
			tcpu = 0
		}
		printf \\
		    "%4d %4s %6d %8.2f %10.2f %9.2f %10d %10d %10d\n", \\
			\$2, \$3, \$4, \$5 / 100, \$1 / 100, \\
			\$6 / 100, \$7, \$8, \$9 >> outf
		tcpu = tcpu + \$5
		telapsed = telapsed + \$1
	}
	close(fil)
	if (found != 0) {
		print "               ---------- ----------" >> outf
		printf "               %10.2f %10.2f %-s\n",
			tcpu / 100, telapsed / 100, \\
			"Total elapsed time for all cursors" >> outf
		print "" >> outf
		grtcpu = int(tcpu)
		grtelapsed = int(telapsed)
	}
	#
	# Print summary by descending fetch time
	#
	if (debug != 0) print "  Print fetch time totals..."
	fil = tmpf "/fetch"
	system("sort -n -r " tmpf "/fetch > " tmpf "/srt.tmp")
	system("mv -f " tmpf "/srt.tmp " tmpf "/fetch")
	found = 0
	while (getline < fil > 0) {
		if (NF != 9) {
			print "Unexpected number of columns (" NF \\
				") in fetch line for hash value " hv ":"
			print \$0
			continue
		}
		if (int(100 * \$5 / 100) == 0 && \\
			int(100 * \$6 / 100) == 0 && \\
			int(100 * \$1 / 100) == 0) continue
		if (found == 0) {
			print "#####################################" \\
				"###################################" \\
				"########" >> outf
			print "" >> outf
			print "       SUMMARY OF TOTAL CPU TIME," \\
				" ELAPSED TIME, AND FETCH TIME PER" \\
				" CURSOR" >> outf
			print "                        (SORTED BY" \\
				" DESCENDING FETCH TIME)" >> outf
			print "" >> outf
			print " Cur User  Total     CPU     Elapsed" \\
				"     Fetch   Physical Consistent" \\
				"    Current" >> outf
			print " ID#  ID   Calls     Time      Time " \\
				"      Time     Reads     Reads  " \\
				"     Reads" >> outf
			print "---- ---- ------ -------- ----------" \\
				" --------- ---------- ----------" \\
				" ----------" >> outf
			found = 1
			tfetch = 0
		}
		printf \\
		    "%4d %4s %6d %8.2f %10.2f %9.2f %10d %10d %10d\n", \\
			\$2, \$3, \$4, \$5 / 100, \$6 / 100, \\
			\$1 / 100, \$7, \$8, \$9 >> outf
		tfetch = tfetch + \$1
	}
	close(fil)
	if (found != 0) {
		print "                                    ----------" >> outf
		printf "                                    %10.2f %-s\n",
			tfetch / 100, "Total fetch time for all cursors" >> outf
		print "" >> outf
	}
	filblk = 0
	#
	# Print total Wait times for all non-recursive statements for users
	#
	if (debug != 0) print "  Print wait time totals..."
	fil = tmpf "/waits/t"
	totwait = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) {
			print "Unexpected number of columns (" elem \\
				") in total waits line #" NR ":"
			print \$0
			continue
		}
		uid = arr[5]
		dep = arr[6]
		if (dep != 0) continue		# Skip if recursive
		nam = arr[1]
		ela = arr[4]
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				if (totela >= 1) totwait = totwait + totela
			}
			prev_nam = nam
			totela = 0
		}
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		if (totela >= 1) totwait = totwait + totela
	}
	fil = tmpf "/waits/t"
	found = 0
	wait_head = 1
	gtotwts = 0
	gtotela = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		p1 = arr[2]
		p2 = arr[3]
		ela = arr[4]
		uid = arr[5]
		dep = arr[6]
		if (dep != 0) continue		# Skip if recursive
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				print_nam = prev_nam
				xx = print_prev_wait()
			}
			prev_nam = nam
			totela = 0
			totwts = 0
		}
		++totwts
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		print_nam = prev_nam
		xx = print_prev_wait()
	}
	if (found == 1) {
		print "--------------------------------------------------" \\
			" -------- ---- ------ -------" >> outf
		printf "%-50s %8.2f %3d%s %6d %7.2f\n", "Total Wait Events:", \\
			gtotela / 100, 100, "%", gtotwts, \\
			gtotela / (gtotwts * 100 + .0000001) >> outf
		print "" >> outf
	}
	#
	# Print total Wait times for all recursive statements for users
	#
	if (debug != 0) print "  Print total wait totals..."
	fil = tmpf "/waits/t"
	totwait = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		uid = arr[5]
		dep = arr[6]
		if (dep == 0) continue		# Skip if non-recursive
		if (uid == 0) continue		# Skip if SYS user
		nam = arr[1]
		ela = arr[4]
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				if (totela >= 1) totwait = totwait + totela
			}
			prev_nam = nam
			totela = 0
		}
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		if (totela >= 1) totwait = totwait + totela
	}
	fil = tmpf "/waits/t"
	found = 0
	wait_head = 2
	gtotwts = 0
	gtotela = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		p1 = arr[2]
		p2 = arr[3]
		ela = arr[4]
		uid = arr[5]
		dep = arr[6]
		if (dep == 0) continue		# Skip if non-recursive
		if (uid == 0) continue		# Skip if SYS user
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				print_nam = prev_nam
				xx = print_prev_wait()
			}
			prev_nam = nam
			totela = 0
			totwts = 0
		}
		++totwts
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		print_nam = prev_nam
		xx = print_prev_wait()
	}
	if (found == 1) {
		print "--------------------------------------------------" \\
			" -------- ---- ------ -------" >> outf
		printf "%-50s %8.2f %3d%s %6d %7.2f\n", "Total Wait Events:", \\
			gtotela / 100, 100, "%", gtotwts, \\
			gtotela / (gtotwts * 100 + .0000001) >> outf
		print "" >> outf
	}
	#
	# Print total Wait times for all recursive statements for SYS
	#
	if (debug != 0) print "  Print total sys wait totals..."
	fil = tmpf "/waits/t"
	totwait = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		uid = arr[5]
		dep = arr[6]
		if (dep == 0) continue		# Skip if non-recursive
		if (uid != 0) continue		# Skip if non-SYS user
		nam = arr[1]
		ela = arr[4]
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				if (totela >= 1) totwait = totwait + totela
			}
			prev_nam = nam
			totela = 0
		}
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		if (totela >= 1) totwait = totwait + totela
	}
	fil = tmpf "/waits/t"
	found = 0
	wait_head = 3
	gtotwts = 0
	gtotela = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		p1 = arr[2]
		p2 = arr[3]
		ela = arr[4]
		uid = arr[5]
		dep = arr[6]
		if (dep == 0) continue		# Skip if non-recursive
		if (uid != 0) continue		# Skip if non-SYS user
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				print_nam = prev_nam
				xx = print_prev_wait()
			}
			prev_nam = nam
			totela = 0
			totwts = 0
		}
		++totwts
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		print_nam = prev_nam
		xx = print_prev_wait()
	}
	if (found == 1) {
		print "--------------------------------------------------" \\
			" -------- ---- ------ -------" >> outf
		printf "%-50s %8.2f %3d%s %6d %7.2f\n", "Total Wait Events:", \\
			gtotela / 100, 100, "%", gtotwts, \\
			gtotela / (gtotwts * 100 + .0000001) >> outf
		print "" >> outf
	}
	if (filblk != 0) {
		print "" >> outf
		print "To determine which segment is causing a" \\
			" specific wait, issue the following" >> outf
		print "query:" >> outf
		print "   SELECT OWNER, SEGMENT_NAME FROM DBA_EXTENTS" >> outf
		print "   WHERE FILE_ID = <File-ID-from-above> AND" >> outf
		print "   <Block-Number-from-above> BETWEEN BLOCK_ID" \\
			" AND BLOCK_ID+BLOCKS-1;" >> outf
	}
	#
	# Print grand total Wait times
	#
	if (debug != 0) print "  Print grand total waits..."
	fil = tmpf "/waits/t"
	totwait = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		# Skip events issued between database calls
		if (nam == "smon timer" || \\
			nam == "pmon timer" || \\
			nam == "rdbms ipc message" || \\
			nam == "pipe get" || \\
			nam == "client message" || \\
			nam == "single-task message" || \\
			nam == "SQL*Net message from client" || \\
			nam == "SQL*Net more data from client" || \\
			nam == "dispatcher timer" || \\
			nam == "virtual circuit status" || \\
			nam == "lock manager wait for remote message" || \\
			nam == "wakeup time manager" || \\
			nam == "PX Deq: Execute Reply" || \\
			nam == "PX Deq: Execution Message" || \\
			nam == "PX Deq: Table Q Normal" || \\
			nam == "PX Idle Wait" || \\
			nam == "slave wait" || \\
			nam == "i/o slave wait" || \\
			nam == "jobq slave wait") continue
		ela = arr[4]
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				if (totela >= 1) totwait = totwait + totela
			}
			prev_nam = nam
			totela = 0
		}
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		if (totela >= 1) totwait = totwait + totela
	}
	fil = tmpf "/waits/t"
	found = 0
	found_scattered = 0
	wait_head = 4
	gtotwts = 0
	gtotela = 0
	gridle = 0
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		if (nam == "smon timer" || \\
			nam == "pmon timer" || \\
			nam == "rdbms ipc message" || \\
			nam == "pipe get" || \\
			nam == "client message" || \\
			nam == "single-task message" || \\
			nam == "SQL*Net message from client" || \\
			nam == "SQL*Net more data from client" || \\
			nam == "dispatcher timer" || \\
			nam == "virtual circuit status" || \\
			nam == "lock manager wait for remote message" || \\
			nam == "wakeup time manager" || \\
			nam == "PX Deq: Execute Reply" || \\
			nam == "PX Deq: Execution Message" || \\
			nam == "PX Deq: Table Q Normal" || \\
			nam == "PX Idle Wait" || \\
			nam == "slave wait" || \\
			nam == "i/o slave wait" || \\
			nam == "jobq slave wait") {
			gridle = gridle + arr[4]
			continue
		}
		p1 = arr[2]
		p2 = arr[3]
		ela = arr[4]
		if (prev_nam != nam) {
			if (substr(nam,1,12) == "db file scat") {
				found_scattered = found_scattered + 1
			}
			if (prev_nam != "@") {
				print_nam = prev_nam
				xx = print_prev_wait()
			}
			prev_nam = nam
			totela = 0
			totwts = 0
		}
		++totwts
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		print_nam = prev_nam
		xx = print_prev_wait()
	}
	if (found == 1) {
		print "--------------------------------------------------" \\
			" -------- ---- ------ -------" >> outf
		printf "%-50s %8.2f %3d%s %6d %7.2f\n", \\
			"Grand Total Non-Idle Wait Events:", \\
			gtotela / 100, 100, "%", gtotwts, \\
			gtotela / (gtotwts * 100 + .0000001) >> outf
		print "" >> outf
	}
	if (found_scattered > 1) {
		print " " >> outf
		print "Note:  For db file scattered read, the number of" \\
			" blocks read may be less" >> outf
		print "       than db_file_multiblock_read_count, if Oracle" \\
			" is able to locate the" >> outf
		print "       block it needs from cache and therefore does" \\
			" not need to read in" >> outf
		print "       the block(s) from disk." >> outf
	}
	# Calc lines for Oracle Timing Analysis
	n = 0
	totwait = 0
	# Store any CPU usage in arrays
	if (cpu_timing_parse_cnt > 0) {
		if (cpu_timing_parse >= 1) {
			++n
			ta_nams[n] = "CPU PARSE Calls"
			ta_ela[n] = cpu_timing_parse
			ta_calls[n] = cpu_timing_parse_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_parse
		}
	}
	if (cpu_timing_exec_cnt > 0) {
		if (cpu_timing_exec >= 1) {
			++n
			ta_nams[n] = "CPU EXEC Calls"
			ta_ela[n] = cpu_timing_exec
			ta_calls[n] = cpu_timing_exec_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_exec
		}
	}
	if (cpu_timing_fetch_cnt > 0) {
		if (cpu_timing_fetch >= 1) {
			++n
			ta_nams[n] = "CPU FETCH Calls"
			ta_ela[n] = cpu_timing_fetch
			ta_calls[n] = cpu_timing_fetch_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_fetch
		}
	}
	if (cpu_timing_unmap_cnt > 0) {
		if (cpu_timing_unmap >= 1) {
			++n
			ta_nams[n] = "CPU UNMAP Calls"
			ta_ela[n] = cpu_timing_unmap
			ta_calls[n] = cpu_timing_unmap_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_unmap
		}
	}
	if (cpu_timing_sort_cnt > 0) {
		if (cpu_timing_sort >= 1) {
			++n
			ta_nams[n] = "CPU SORT UNMAP Calls"
			ta_ela[n] = cpu_timing_sort
			ta_calls[n] = cpu_timing_sort_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_sort
		}
	}
	if (cpu_timing_rpcexec_cnt > 0) {
		if (cpu_timing_rpcexec >= 1) {
			++n
			ta_nams[n] = "RPC EXEC Calls"
			ta_ela[n] = cpu_timing_rpcexec
			ta_calls[n] = cpu_timing_rpcexec_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_rpcexec
		}
	}
	if (cpu_timing_close_cnt > 0) {
		if (cpu_timing_close >= 1) {
			++n
			ta_nams[n] = "CPU CLOSE Calls"
			ta_ela[n] = cpu_timing_close
			ta_calls[n] = cpu_timing_close_cnt
			ta_flg[n] = 0
			totwait = totwait + cpu_timing_close
		}
	}
	# Store any timing gap error in arrays
	if (gap_cnt > 0) {
		if (gap_time >= 1) {
			++n
			ta_nams[n] = "Timing Gap Error"
			ta_ela[n] = gap_time
			ta_calls[n] = gap_cnt
			ta_flg[n] = 0
			totwait = totwait + gap_time
		}
	}
	# Store any unaccounted-for time in arrays
	if (unacc_cnt > 0) {
		if (unacc_total >= 1) {
			++n
			ta_nams[n] = "Unaccounted-for time"
			ta_ela[n] = unacc_total
			ta_calls[n] = unacc_cnt
			ta_flg[n] = 0
			totwait = totwait + unacc_total
		}
	}
	# Store all wait info in arrays, and accum total elapsed times
	fil = tmpf "/waits/t"
	prev_nam = "@"
	while (getline < fil > 0) {
		elem = split(\$0, arr, "~")
		if (elem != 6) continue
		nam = arr[1]
		if (nam == "smon timer" || \\
			nam == "pmon timer" || \\
			nam == "rdbms ipc message" || \\
			nam == "pipe get" || \\
			nam == "client message" || \\
			nam == "single-task message" || \\
			nam == "dispatcher timer" || \\
			nam == "virtual circuit status" || \\
			nam == "lock manager wait for remote message" || \\
			nam == "wakeup time manager" || \\
			nam == "slave wait" || \\
			nam == "i/o slave wait" || \\
			nam == "jobq slave wait") continue
		p1 = arr[2]
		p2 = arr[3]
		ela = arr[4]
		if (prev_nam != nam) {
			if (prev_nam != "@") {
				if (totwts > 0) {
					if (totela >= 1) {
						++n
						ta_nams[n] = prev_nam
						ta_ela[n] = totela
						ta_calls[n] = totwts
						ta_flg[n] = 0
						totwait = totwait + totela
					}
				}
			}
			prev_nam = nam
			totela = 0
			totwts = 0
		}
		++totwts
		totela = totela + ela
	}
	close(fil)
	if (prev_nam != "@") {
		if (totwts > 0) {
			if (totela >= 1) {
				++n
				ta_nams[n] = prev_nam
				ta_ela[n] = totela
				ta_calls[n] = totwts
				ta_flg[n] = 0
				totwait = totwait + totela
			}
		}
	}
	# Print grand total timings, sorted by descending elapsed time
	found = 0
	wait_head = 5
	gtotwts = 0
	gtotela = 0
	print_gap_desc = 0
	i = 0
	while (i < n) {
		++i
		greatest_time = 0
		k = 0
		j = 0
		while (j < n) {
			++j
			if (ta_ela[j] > greatest_time && ta_flg[j] == 0) {
				greatest_time = ta_ela[j]
				k = j
			}
		}
		print_nam = ta_nams[k]
		totela = ta_ela[k]
		totwts = ta_calls[k]
		xx = print_prev_wait()
		ta_flg[k] = 1
		# See if > 10% Timing Gap Error
		if (print_nam == "Timing Gap Error" && 10 * totela > totwait) {
			print_gap_desc = 1
		}
	}
	if (found == 1) {
		print "--------------------------------------------------" \\
			" -------- ---- ------ -------" >> outf
		printf "%-50s %8.2f %3d%s %6d %7.2f\n", \\
			"Total Oracle Timings:", \\
			gtotela / 100, 100, "%", gtotwts, \\
			gtotela / (gtotwts * 100 + .0000001) >> outf
		print "" >> outf
		print "(Note that these timings may differ from the" \\
			" following grand totals, due to" >> outf
		print " overlapping wall clock time for" \\
			" simultaneously-executed processes, as well as" >> outf
		print " omitted RPC times.)" >> outf
	}
	if (print_gap_desc != 0) {
		print "" >> outf
		print "A significant portion of the total elapsed time is" \\
			" due to Timing Gap" >> outf
		print "Error.  This measurement accumulates the differences" \\
			" in the trace file's" >> outf
		print "timing values when there is an unexplained increase" \\
			" of time.  When Timing" >> outf
		print "Gap Error time is a large amount of the total" \\
			" elapsed time, this usually" >> outf
		print "indicates that a process has spent a significant" \\
			" amount of time in a" >> outf
		print "preempted state.  The operating system's scheduler" \\
			" will preempt a process" >> outf
		print "if there is contention for the CPU's run queue." \\
			"  The best way to reduce" >> outf
		print "this time is to reduce the demand for the CPUs," \\
			" typically by optimizing" >> outf
		print "the application code to reduce the number of I/O" \\
			" and/or parsing operations." >> outf
		print "" >> outf
		print "Note that excessive parsing will show up in this" \\
			" report as \"CPU PARSE Calls\"." >> outf
		print "Programs which parse too much will typically have a" \\
			" \"CPU PARSE Calls\"" >> outf
		print "value near the value of \"CPU EXEC Calls\"." >> outf
	}
	post_wait = 0
	fil = tmpf "/waitsela"
	while (getline < fil > 0) {
		post_wait = post_wait + \$0
	}
	close(fil)
	if (post_wait >= 1) {
		print "" >> outf
		printf "%-50s %8.2f\n", \\
			"Total Wait Time without a matching cursor:", \\
			post_wait / 100 >> outf
	}
	print "" >> outf
	print "###################################################" \\
		"#############################" >> outf
	print "" >> outf
	if (first_time == 0) {
		elapsed_time = 0
	} else {
		elapsed_time = int(100 * grand_elapsed / 100)
	}
	if (debug != 0) print "Grand total: elapsed_time = " elapsed_time
	if (elapsed_time == 0) {
		printf "%s  %12.2f\n", \\
			"GRAND TOTAL SECS:", elapsed_time / 100 >> outf
	} else {
		print "                   Elapsed Wall  Elapsed         " \\
			" Non-Idle     Idle" >> outf
		print "                    Clock Time    Time   CPU Time" \\
			"   Waits     Waits" >> outf
		print "                   ------------ -------- --------" \\
			" -------- --------" >> outf
		printf "%s  %12.2f %8.2f %8.2f %8.2f %8.2f\n", \\
			"GRAND TOTAL SECS:", \\
			elapsed_time / 100, \\
			int(grtelapsed) / 100, \\
			int(grtcpu) / 100, \\
			int(gtotela) / 100, \\
			int(gridle) / 100 >> outf
		printf "%s %3d%s %3d%s %3d%s %3d%s\n", \\
			"PCT OF WALL CLOCK:                 ", \\
			int((10000 * grtelapsed) / (100 * elapsed_time)), \\
			"%    ", \\
			int((10000 * grtcpu) / (100 * elapsed_time)), \\
			"%    ", \\
			int((10000 * gtotela) / (100 * elapsed_time)), \\
			"%    ", \\
			int((10000 * gridle) / (100 * elapsed_time)), \\
			"%" >> outf
	}
	fil = tmpf "/truncated"
	if (getline < fil > 0) {
		if (\$0 == 1) {
			print "" >> outf
			print "WARNING:  THIS DUMP FILE HAS BEEN TRUNCATED!" \\
				>> outf
		}
	} else {
		print "Error while trying to read truncated"
	}
	close(fil)
	fil = tmpf "/duplheader"
	x = 0
	if (getline < fil > 0) {
		if (x == 0) {
			print "" >> outf
			print "*** Warning: Multiple trace file headings" \\
				" are in the trace file!" >> outf
			print "             This will cause inaccuracies" \\
				" in the Elapsed Wall Clock Time" >> outf
			print "             calculation, as actual times" \\
				" are omitted in the trace file." >> outf
			print "" >> outf
			x = 1
		}
		print "             An extra trace header starts on" \\
			" trace line " \$0 >> outf
	}
	close(fil)
	if (debug != 0) print "DONE..."
}
EOF
echo "Processing cursors..."
cat $tmpf/init | $cmd -f trace_report.awk outf=$outf tmpf="$tmpf" debug="$debug"
rm -f trace_report.awk
ls -l $outf
if [ "$debug" = "1" ]
then
	echo "Retaining $tmpf for debugging..."
else
	rm -Rf $tmpf
	echo ""
fi
