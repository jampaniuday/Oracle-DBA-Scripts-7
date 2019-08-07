alter session set sort_area_size=5000000;
spool db_audit9i.log
#audit_db9i.sql

prompt	
prompt =======================================================================================
prompt ======================================================================================= 
prompt Comprehensive Database Overview
prompt =======================================================================================
prompt =======================================================================================
clear column breaks 
set pagesize 1000
set heading  on 
set pause    off 
set feedback on 
set verify   off 
set arraysize 12 
prompt	
prompt	
prompt Timestamp
select localtimestamp "Local Time" from dual;
prompt Date
select to_char(sysdate,'Day, Month DD, YYYY HH:MIAM') from dual;
prompt =======================================================================================
prompt
prompt Current Local Time Zone
select sessiontimezone "Local Time Zone" from dual;
prompt 
prompt
prompt Time Zone of the Database
select dbtimezone from dual;
prompt
prompt
prompt Current DB SCN:
select dbms_flashback.get_system_change_number from dual;
prompt 
prompt
column global_name       format a16      heading "Global Name" 
column created           format a9       heading "Database|Creation Date" 
column log_mode          format a10      heading Database|Mode 
column startup_time      format a13      heading "Database|Startup Time" 
column db_name           format a8       heading Database|Name 
column machine           format a7       heading Login|Host 
column logins            format a10      heading Access|Restricted 
column db_block_sizes    format a10      heading "Database|Block Size" 
column archiver          format a7       heading Arch|Process 
column audits            format a6       heading Audit|Trail 
column sql_traces        format a6       heading SQL|Trace 
column statistics        format a10      heading Timed|Statistics 
column sessions_current  format 9,999    heading Total|Users 
column shared_mbytes     format 999,990  heading "Free SGA|(SH)Mbyte" 
column large_mbytes      format 999,990  heading "Free SGA|(LG)Mbyte" 
column optimizer_modes   format a10      heading Optimizer|Mode 
column remote_os_authent format a6       heading "Rmt OS|Auth" 
column rmt_password      format a5       heading Rmt|Paswd 
column os_authent_prefix format a7       heading "OS Auth|Prefix" 
column os_roles          format a5       heading OS|Roles 
column db_domain         format a15      heading Database|Domain 
column global_names      format a6       heading Global|Names 
column total_mbytes      format 999,990  heading "Total SGA|Mbyte" 
column user              format a10      heading Login|User 
column parallel_q_server format a8       heading "Parallel|Qry Svr" 
column mts_servers       format a5       heading MTS|Svr 
column total noprint new_value  total format 9,999  heading "Total|Mbytes" 
rem clear screen 

select 'AUDIT DATE: '||substr(to_char(sysdate,'fmMonth DD, YYYY HH:MI:SS P.M.'),1,35) from dual; 

prompt
prompt =======================================================================================
prompt General Information
prompt =======================================================================================
prompt Instance Information
prompt =======================================================================================
select 'DBID              : '||dbid as "-" from v$database;
select 'Instance          : '||name as "-" from v$database;
select 'Global Name       : '||substr(global_name,1,40) as "-" from global_name;
select 'Creation Date     : '||created as "-" from v$database;
select 'Open Mode         : '||open_mode as "-" from v$database;
select 'Archive Mode      : '||log_mode from v$database;
select 'Auto Archive Mode : '||decode(value,'TRUE','ENABLED','DISABLED') from v$parameter
 where name = 'log_archive_start';
select 'Current Uptime    : '||floor(xx)||' days '||floor((xx-floor(xx))*24)||' hours '||
	round(((xx-floor(xx)*24)-floor((xx-floor(xx)*24)))*60)||
       ' minutes' "Database Uptime" from (select (sysdate-startup_time) xx from v$instance);
select 'RMAN in use?      : '||decode(count(*),0,'NO   ','YES   ')||
       'Last used -> '||decode(max(completion_time),null,' ',max(completion_time)) 
  from v$backup_set
 where recid = (select max(recid) from v$backup_set);
select 'Number of CPUs    :   '||value from v$parameter where name='cpu_count';

select 'Total Size        : '||to_char(sum(bytes),'999,999,999,999,999')||' bytes' from dba_data_files;
select 'Free              : '||to_char(sum(bytes),'999,999,999,999,999')||' bytes' from dba_free_space;
select 'Used              : '||to_char(sum(bytes),'999,999,999,999,999')||' bytes' from dba_segments;
column product format a10;
prompt Version
select * from v$version;
Prompt Base System Parameters
select count(*) from v$parameter;
prompt KSPPI Count
select count(*) from x$ksppi;
prompt Dictionary Objects
select count(*) from dict;
prompt SYS-owned Tables
select count(*) from dba_tables where owner = 'SYS';
prompt Total Database Object Count
select count(*) from dba_objects;
prompt Total Number of Wait Events Trackable
select count(*) from v$event_name;
prompt Total Number of System Stats Trackable
select count(*) from v$sysstat;
prompt Total Number of Lock Types Trackable
select count(*) from v$lock_type;
prompt Total Number Reserved Words
select count(*) from v$reserved_words;
prompt
prompt =======================================================================================
prompt SPFile Status
prompt
prompt If "Value" is empty then no SPFILE was specified at startup.
prompt =======================================================================================
show parameter spfile;
prompt
prompt
prompt
prompt =======================================================================================
prompt Buffer Pool Contents
prompt =======================================================================================
select    name,    block_size,   
(1-(physical_reads/ decode(db_block_gets+consistent_gets, 0, .001)))*100 cache_hit_ratio 
from v$buffer_pool_statistics;
prompt
prompt =======================================================================================
prompt SGA:
prompt Variable Size = java_pool_size + shared_pool_size + and large_pool_size
prompt =======================================================================================
show sga;

prompt
column x1 format a60 heading "DESCRIPTION"
select rpad(substr(name,1,20),20)||decode(name, 'Variable Size',' (See SGA Memory Usage: shared pool)',
       'Database Buffers',' (DB_BLOCK_SIZE*DB_BLOCK_BUFFERS)',
       'Redo Buffers',' (LOG_BUFFER)',' ') x1,
       to_char(value,'999999999999') "        BYTES"
  from v$sga;

set serveroutput on

DECLARE
  v_sga_size number;

BEGIN
  select sum(value) into v_sga_size from v$sga;
  DBMS_OUTPUT.PUT_LINE('SGA Size                                                     '||to_char(v_sga_size,'999999999999'));
END;
/
set serveroutput off
prompt
prompt    Total SGA 
select sum(s1.value)/1048576 total 
from   v$sga s1; 

prompt    SGA Subcomponents
column component format a30;
select * from v$sga_dynamic_components;

prompt
prompt  In 9i, Non-OLAP, non Budget/Planning 11i instance, olap_page_pool_size is 
prompt  defaulted is 32M.  32M per user connection is pulled from the 
prompt  UGA (part of PGA in non-MTS mode).  It is recommended to reset this to 4M 
prompt  for the system and in the init.ora.  This will likely decrease the adviseries
prompt  recommendation for optimal pga size.\
prompt
prompt  via:   	SQLPLUS: alter system set OLAP_PAGE_POOL_SIZE=4194304 deferred;
prompt 		INIT:    olap_page_pool_size = 4194304
prompt
column value format a30 trunc;
column name format a25 trunc;
select name, value from v$parameter where name like '%pool%';

select p1.value db_name , substr(d.log_mode,1,10) log_mode, g.global_name, 
       s.machine, 
       to_char(i.startup_time,'dd-MON HH24:MI') startup_time, 
       d.created, p2.value db_block_sizes 
from v$session s,global_name g, v$database d, v$parameter p1,v$parameter p2,v$instance i 
where s.sid=1 
and   p1.name = 'db_name' 
and   p2.name = 'db_block_size'; 

select substr(i.logins,1,10) logins, i.archiver, p1.value audits, 
       p2.value sql_traces, p3.value statistics, p4.value optimizer_modes, 
       p5.value os_roles, 
       l.sessions_current, user 
from   v$instance i, v$parameter p1, v$parameter p2, v$parameter p3, 
       v$parameter p4, v$parameter p5, v$license l 
where p1.name = 'audit_trail' 
and   p2.name = 'sql_trace' 
and   p3.name = 'timed_statistics' 
and   p4.name = 'optimizer_mode' 
and   p5.name = 'os_roles'; 

column value$   format a12 heading "Current|Value" 
column comment$ format a13 heading "Comment" word_wrapped 
column name format a17 heading "Name" 
rem set linesize 130 
Prompt 


select d.name||' is in '||d.log_mode ||' mode.'"DB Mode",a.name,a.value$,a.comment$ 
FROM sys.props$ a,v$database d 
WHERE a.name like 'NLS_CHAR%'; 
Prompt 

select p1.value db_domain, p2.value global_names, 
       p3.value os_authent_prefix, 
       p4.value remote_os_authent, 
       p5.value rmt_password, 
       p6.value parallel_q_server, 
       p7.value mts_servers, 
        s1.bytes/1048576 shared_mbytes 
from   v$parameter p1, v$parameter p2, v$parameter p3, 
       v$parameter p4, v$parameter p5, v$parameter p6, v$parameter p7, 
       v$sgastat s1 
where p1.name = 'db_domain' 
and   p2.name = 'global_names' 
and   p3.name = 'os_authent_prefix' 
and   p4.name = 'remote_os_authent' 
and   p5.name = 'remote_login_passwordfile' 
and   p6.name = 'parallel_min_servers' 
and   p7.name = 'mts_servers' 
and   s1.name = 'free memory' 
and   s1.pool ='shared pool'; 

rem This may be missing 
select s2.bytes/1048576 large_mbytes 
from v$sgastat s2 
where s2.name = 'free memory' 
and   s2.pool ='large pool'; 

set heading  on 
set feedback on 
set verify   on 
column value format a15 trunc;

prompt
prompt =======================================================================================
prompt Current Database User Session Highwater Marks
prompt =======================================================================================
select * from v$license;
prompt
prompt =======================================================================================
prompt Current Database Resource Usage
prompt =======================================================================================
select * from v$resource_limit;

prompt
prompt =======================================================================================
prompt Display Product_Profile
prompt =======================================================================================
SELECT * FROM PRODUCT_PROFILE;


prompt
prompt =======================================================================================
prompt Database Options Installed
prompt =======================================================================================
select * from V$option;

!!!!throw all of this just below v$option section if applicable



prompt =======================================================================================
PROMPT PARTITIONING
prompt =======================================================================================



SELECT 'ORACLE PARTITIONING INSTALLED: '||value from v$option where
parameter='Partitioning';



SELECT OWNER, TABLE_NAME, PARTITIONED
FROM DBA_TABLES
WHERE PARTITIONED='YES';
prompt =======================================================================================
PROMPT IF NO ROWS ARE RETURNED, THEN PARTITIONING IS NOT BEING USED.
PROMPT
PROMPT IF ROWS ARE RETURNED, CHECK THAT BOTH OWNER AND TABLE ARE  
PROMPT ORACLE CREATED. IF NOT, THEN PARTITIONING IS BEING USED.
PROMPT
prompt =======================================================================================



prompt =======================================================================================
PROMPT OLAP
prompt =======================================================================================

SELECT 'ORACLE OLAP INSTALLED: '||value from v$option where
parameter='OLAP';

PROMPT
PROMPT
prompt =======================================================================================
PROMPT CHECKING TO SEE IF OLAP IS INSTALLLED / USED...
prompt =======================================================================================
select 
	value
from 
	v$option 
where 
	parameter = 'OLAP';

prompt =======================================================================================
PROMPT If the value is TRUE then the OLAP option IS INSTALLED
PROMPT If the value is FALSE then the OLAP option IS NOT INSTALLED
PROMPT If NO rows are selected then the option is NOT being used.
prompt =======================================================================================
PROMPT
PROMPT CHECKING TO SEE IF THE OLAP OPTION IS BEING USED...
PROMPT
PROMPT CHECKING FOR OLAP CATALOGS...
PROMPT
prompt =======================================================================================


SELECT 
	count(*) "OLAP CATALOGS" 
FROM 
	olapsys.dba$olap_cubes 
WHERE 
	OWNER <>'SH' ;

prompt =======================================================================================
PROMPT IF THE COUNT IS > 0 THEN THE OLAP OPTION IS BEING USED
PROMPT IF THE COUNT IS = 0 THEN THE OLAP OPTION IS NOT BEING USED
PROMPT IF THE TABLE DOES NOT EXIST (ORA-00942) ...THEN THE OLAP CATALOGS ARE NOT BEING USED
prompt =======================================================================================
prompt
PROMPT CHECKING FOR ANALYTICAL WORK SPACES...
PROMPT 
prompt =======================================================================================
SELECT count(*) "Analytical Workspaces" 
FROM	 dba_aws;

prompt =======================================================================================
PROMPT IF THE COUNT IS >1 THEN THE OPTION IS BEING USED
PROMPT IF THE COUNT IS 0 OR 1 THEN ANALYTICAL WORKSPACES ARE NOT BEING USED
PROMPT IF THE TABLE DOES NOT EXIST (ORA-00942) ...THEN ANALYTICAL WORKSPACES ARE NOT BEING USED
PROMPT
PROMPT CHECKING FOR ANALYTICAL WORKSPACE OWNERS...
PROMPT 
prompt =======================================================================================
SELECT OWNER, AW_NUMBER, AW_NAME, PAGESPACES, GENERATIONS FROM
DBA_AWS;

PROMPT
prompt =======================================================================================
PROMPT NOTE: A positive result FROM either QUERY indicates the use of the OLAP option.
PROMPT	 Check the Workspace owners to detemine if Workspaces are Oracle created. 
PROMPT
prompt =======================================================================================

PROMPT
prompt =======================================================================================
PROMPT RAC (REAL APPLICATION CLUSTERS)
prompt =======================================================================================
SELECT 'ORACLE RAC INSTALLED: '||value from v$option where
parameter='Real Application Clusters';


PROMPT
prompt =======================================================================================
PROMPT CHECKING TO SEE IF RAC IS INSTALLED AND BEING USED...
PROMPT RAC (Real Application Cluster)= Former OPS(Oracle Parallel Server)
prompt =======================================================================================
SELECT instance_name, host_name 
FROM	 gv$instance
ORDER BY instance_name;

PROMPT
prompt =======================================================================================
PROMPT If only one row is returned, then RAC/OPS is NOT being used.
PROMPT If more than one row is returned, then RAC/OPS IS being used for this database.
prompt =======================================================================================

PROMPT
PROMPT LABEL SECURITY
prompt =======================================================================================
SELECT 'ORACLE LABEL SECURITY INSTALLED: '||value from v$option where
parameter='Label Security';

PROMPT
prompt =======================================================================================
PROMPT CHECKING TO SEE IF LABEL SECURITY IS INSTALLLED / USED...
prompt =======================================================================================
select value
from   v$option 
where  parameter = 'Oracle Label Security';

PROMPT
prompt =======================================================================================
PROMPT If the value is TRUE then the LABEL SECURITY OPTION IS installed
PROMPT If the value is FALSE then the LABEL SECURITY OPTION IS NOT installed
prompt =======================================================================================
PROMPT

prompt =======================================================================================
PROMPT OEM
prompt =======================================================================================
PROMPT
PROMPT CHECKING TO SEE IF OEM PROGRAMS ARE RUNNING...
PROMPT
prompt =======================================================================================


SELECT DISTINCT 
	program
FROM
	v$session
WHERE
	upper(program) LIKE '%XPNI.EXE%'
	OR upper(program) LIKE '%VMS.EXE%'
	OR upper(program) LIKE '%EPC.EXE%'
	OR upper(program) LIKE '%TDVAPP.EXE%'
	OR upper(program) LIKE 'VDOSSHELL%'
	OR upper(program) LIKE '%VMQ%'
	OR upper(program) LIKE '%VTUSHELL%'
	OR upper(program) LIKE '%JAVAVMQ%'
	OR upper(program) LIKE '%XPAUTUNE%'
	OR upper(program) LIKE '%XPCOIN%'
	OR upper(program) LIKE '%XPKSH%'
	OR upper(program) LIKE '%XPUI%';

PROMPT
PROMPT CHECKING FOR OEM REPOSITORIES...
PROMPT 

	SET SERVEROUTPUT ON

      DECLARE 
      cursor1 integer;
	v_count number(1);
      v_schema dba_tables.owner%TYPE;
      v_version varchar2(10);
      v_component varchar2(20);
      v_i_name varchar2(10);
      v_h_name varchar2(30);
      stmt varchar2(200);
      rows_processed integer;

      CURSOR schema_array IS
      SELECT owner 
      FROM dba_tables WHERE table_name = 'SMP_REP_VERSION';

      CURSOR schema_array_v2 IS
      SELECT owner 
      FROM dba_tables WHERE table_name = 'SMP_VDS_REPOS_VERSION';

      BEGIN
      	DBMS_OUTPUT.PUT_LINE ('.');
	      DBMS_OUTPUT.PUT_LINE ('OEM REPOSITORY LOCATIONS');

      	select instance_name,host_name into v_i_name, v_h_name from
            v$instance;
            DBMS_OUTPUT.PUT_LINE ('Instance: '||v_i_name||' on host: '||v_h_name);

            OPEN schema_array;
            OPEN schema_array_v2;

            cursor1:=dbms_sql.open_cursor;

            v_count := 0;

            LOOP -- this loop steps through each valid schema.
            FETCH schema_array INTO v_schema;
            EXIT WHEN schema_array%notfound;
            v_count := v_count + 1;
            dbms_sql.parse(cursor1,'select c_current_version, c_component from
            '||v_schema||'.smp_rep_version', dbms_sql.native);
            dbms_sql.define_column(cursor1, 1, v_version, 10);
            dbms_sql.define_column(cursor1, 2, v_component, 20);

            rows_processed:=dbms_sql.execute ( cursor1 );

            loop -- to step through cursor1 to find console version.
            if dbms_sql.fetch_rows(cursor1) >0 then
            dbms_sql.column_value (cursor1, 1, v_version);
            dbms_sql.column_value (cursor1, 2, v_component);
            if v_component = 'CONSOLE' then
            dbms_output.put_line ('Schema '||rpad(v_schema,15)||' has a repository
            version '||v_version);
            exit;

            end if;
            else
            	exit;
            end if;
            end loop;

            END LOOP;

            LOOP -- this loop steps through each valid V2 schema.
            FETCH schema_array_v2 INTO v_schema;
            EXIT WHEN schema_array_v2%notfound;

            v_count := v_count + 1;
            dbms_output.put_line ( 'Schema '||rpad(v_schema,15)||' has a repository
            version 2.x' );
            end loop;

            dbms_sql.close_cursor (cursor1);
            close schema_array;
            close schema_array_v2;
            if v_count = 0 then
            dbms_output.put_line ( 'There are NO OEM repositories on this instance.');
            end if;
	end;
/


prompt
prompt =======================================================================================
prompt If NO ROWS are returned then OEM is not being used.
prompt If ROWS are returned, then OEM is being utilized.
prompt =======================================================================================
prompt

prompt
prompt =======================================================================================
PROMPT SPATIAL
prompt =======================================================================================

SELECT 'ORACLE SPATIAL INSTALLED: '||value from v$option where
parameter='Spatial';



PROMPT
prompt =======================================================================================
PROMPT CHECKING TO SEE IF SPATIAL IS BEING USED...
prompt =======================================================================================
select count(*) "ALL_SDO_GEOM_METADATA"
from ALL_SDO_GEOM_METADATA;

PROMPT
prompt =======================================================================================
PROMPT If no rows are returned, then SPATIAL is NOT being used.
PROMPT If rows are returned then SPATIAL IS being used.
prompt =======================================================================================


PROMPT
prompt =======================================================================================
PROMPT DATA MINING
prompt =======================================================================================

SELECT 'ORACLE DATA MINING INSTALLED: '||value from v$option where
parameter like '%Data Mining';



PROMPT
prompt =======================================================================================
PROMPT CHECKING TO SEE IF DATA MINING IS BEING USED:
prompt =======================================================================================
PROMPT
select count(*) "Data_Mining_Model" from odm.odm_mining_model;



prompt
prompt =======================================================================================
prompt Database Registered Components Installed
prompt =======================================================================================
column comp_name format a30 trunc;
set lines 300;
select comp_name, version, status, modified, schema from dba_registry;
prompt
prompt =======================================================================================
prompt Current Database Background Processes
prompt =======================================================================================
select name, description from v$bgprocess;
prompt
prompt =======================================================================================
prompt Default Temporary Tablespace
prompt This can be changed by: alter database ABC default temporary tablespace XYZ;
column property_value format a40;
select property_name, property_value from database_properties
where property_name='DEFAULT_TEMP_TABLESPACE';

prompt
prompt =======================================================================================
prompt Default Undo Tablespace
prompt This can be changed by: alter system set undo_tablespace='XYZ';
select tablespace_name from dba_tablespaces where contents='UNDO';

prompt
prompt =======================================================================================
prompt Suppressing Undo Errors
prompt If you have a system that calls specific rollback segments to run transactions, run the
prompt following command to suppress the generated errors caused by the fact that your code 
prompt is not migrated to automatic undo management.
prompt
prompt NOTE: Init.ora param "compatible" must be set to 9.2.0.0.0 for this to work.
prompt
prompt alter system set undo_suppress_errors=true scope=both;
prompt


prompt
prompt =======================================================================================
prompt Key 9i Init Parameters:
prompt =======================================================================================
prompt
prompt =======================================================================================
prompt Statistics Level
prompt This should be set to TYPICAL in order for database adviseries to function
prompt Note: There is no significant performance improvement from lowering this level.
prompt Use 9i OEM to view adviseries several hours after the system starts.
prompt =======================================================================================
select value from v$parameter where name ='statistics_level';
prompt
col statistics_name      for a30 head "Statistics Name"
col session_status       for a10 head "Session|Status"
col system_status        for a10 head "System|Status"
col activation_level     for a10 head "Activation|Level"
col session_settable     for a10 head "Session|Settable"

SELECT STATISTICS_NAME,
       SESSION_STATUS,
       SYSTEM_STATUS,
       ACTIVATION_LEVEL,
       SESSION_SETTABLE
  FROM v$statistics_level
 ORDER BY 1
/
prompt
prompt =======================================================================================
prompt PGA Aggregate Target
prompt alter system set pga_aggregate_target=nn scope=both;
prompt
prompt SGA:
select value from v$parameter where name ='sga_max_size';
prompt
prompt PGA Aggregate Target:
select value from v$parameter where name ='pga_aggregate_target';
prompt
prompt Ratio of PGA to SGA:
prompt This should be set to 20% of SGA for OLTP. 
create table pga_bbmm (pga number);
create table sga_bbmm (sga number);
insert into pga_bbmm select value from v$parameter 
where name ='pga_aggregate_target';
insert into sga_bbmm select value from v$parameter where name ='sga_max_size';
select (p.pga/s.sga)*100  "PGA % of SGA" from pga_bbmm p, sga_bbmm s;
drop table pga_bbmm;
drop table sga_bbmm;
prompt
prompt =======================================================================================
prompt Work Area Size Management
prompt This should be set to AUTO to enable automatic sizing of needed sort areas.
prompt "MANUAL" result in "sub-optimal performance and poor PGA memory utilization."
select value from v$parameter where name ='workarea_size_policy';
prompt
prompt The OPTIMAL work area executions should be greater than 95 percent of tasks.
prompt If lower, then the pga_aggregate_target is too small.
prompt If consistently 100 percent, you may consider reducing the value of pga_aggregate_target.
prompt

set lines 300;
select
   name profile, 
   cnt, 
   decode(total, 0, 0, round(cnt*100/total)) percentage 
from  
	(select name, value cnt, (sum(value) over ()) total 
	from v$sysstat 
	where name like 'workarea exec%')
;


prompt
prompt =======================================================================================
prompt File System I/O
prompt Asynch I/O is the best for an OLTP environment to prevent waits.
prompt
prompt Disk Asynch I/O should be "TRUE"
select value from v$parameter where name ='disk_asynch_io';
prompt File System I/O should be "asynch"
select value from v$parameter where name ='filesystemio_options';

prompt
prompt =======================================================================================
prompt Cursor Sharing
prompt For 9i, Oracle recommends setting cursor sharing to "similar"
prompt 	alter system set cursor_sharing='SIMILAR' scope=both;
prompt
select value from v$parameter where name ='cursor_sharing';


prompt
prompt =======================================================================================
prompt DB Files count should be at least 1.5 x the total number of files.
prompt There is no gain by lowering this value.
select value "DB Files" from v$parameter where name ='db_files';
prompt Total Datafile count in the database at this time.
select count(*) from dba_Data_files;
prompt Total Tempfile count in the database at this time.
select count(*) from dba_temp_files;


prompt
prompt =======================================================================================
prompt MTTR Target
prompt This should be set between 1000 and 100.
prompt For an average instance recovery time of 2 minutes, set this to 120.
prompt =======================================================================================
select value seconds from v$parameter where name ='fast_start_mttr_target';
prompt
prompt
prompt =======================================================================================
prompt =======================================================================================
prompt

prompt
prompt =======================================================================================
prompt Oracle Managed Files:
prompt A value returned below indicates that Oracle Managed Files are used in this database.
select name from v$datafile where name like '%u.ctl';
select name from v$datafile where name like '%g_%u.log';
select name from v$datafile where name like '%t_%u.dbf';
select name from v$datafile where name like '%t_%u.tmp';



prompt 
prompt =======================================================================================
prompt Database Performance Overview
prompt =======================================================================================
set echo      off
set feedback  off
set verify    off
set termout   on
set trimspool on
set linesize  150
column timecol new_value timestamp
column spool_extension new_value suffix
select to_char(sysdate,'_MMDDYY_HHMISS') timecol,
'.txt' spool_extension
from sys.dual;



prompt
prompt =======================================================================================
prompt Performance Information
prompt =======================================================================================
select 'Library Cache Hit Ratio (%)        : '||to_char((1- sum(reloads)/sum(pins)) * 100,'99999.999')
       ||'     Ideal Target: >99%' from v$librarycache;

select 'Dictionary Cache Hit Ratio (%)     : '||to_char((1- sum(getmisses)/sum(gets)) * 100,'99999.999')
       ||'     Ideal Target: >90%' from v$rowcache;

select 'Buffer Cache Hit Ratio (%) 		 : '||to_char((1-((sum(decode(a.name,'physical reads',value,0)))
   -(sum(decode(a.name,'physical reads direct',a.value,0))
   +sum(decode(a.name,'physical reads direct (lob)',a.value,0)))) / (sum(decode(a.name,'db block gets',a.value,0))
   +sum(decode(a.name,'consistent gets',a.value,0)) 
   - (sum(decode(a.name,'physical reads direct',a.value,0))
   +sum(decode(a.name,'physical reads direct (lob)',a.value,0)))))*100,'99990.000')||
  ' Ideal Target: >90%'from v$sysstat a;

select 'Sort Area Hit Ratio (%)            : '||to_char((1- (sum(decode(a.name,'sorts (disk)',value,0)))/
       (sum(decode(a.name,'sorts (memory)',value,0))+sum(decode(a.name,'sorts (disk)',value,0)))) * 100, '99999.999')
       ||'     Ideal Target: >90%' from v$sysstat a;
select 'Redo Log Space Requests            : '||to_char(value,'999999999')
       ||'     Ideal Target:    0' from v$sysstat where name = 'redo log space requests';

select 'Immediate Allocation Latches       : '||DECODE(a.immediate_misses,0,DECODE(a.immediate_gets,0,'     0.000',
       to_char(a.immediate_misses/(a.immediate_gets + a.immediate_misses), '99990.999')),
       to_char(a.immediate_misses/(a.immediate_gets + a.immediate_misses), '99990.999'))
       ||'     Ideal Target: < 1%' 
  from v$latch a, v$latchname b
 where b.name = 'redo allocation'
   and b.latch# = a.latch#;

select 'Willing-to-wait Allocation Latches : '||DECODE(a.misses,0,DECODE(a.gets,0,'     0.000',
       to_char(a.misses/a.gets, '99990.999')), to_char(a.misses/a.gets, '99990.999'))
       ||'     Ideal Target: < 1%'
  from v$latch a, v$latchname b
 where b.name = 'redo allocation'
   and b.latch# = a.latch#;

select 'Immediate Copy Latches             : '||DECODE(a.immediate_misses,0,DECODE(a.immediate_gets,0,'     0.000',
       to_char(a.immediate_misses/(a.immediate_gets + a.immediate_misses),'99990.999')),
       to_char(a.immediate_misses/(a.immediate_gets + a.immediate_misses), '99990.999'))
       ||'     Ideal Target: < 1%'
  from v$latch a, v$latchname b
 where b.name = 'redo copy'
   and b.latch# = a.latch#;

select 'Willing-to-wait Copy Latches       : '||DECODE(a.misses,0,DECODE(a.gets,0,'     0.000',
       to_char(a.misses/a.gets, '99990.999')), to_char(a.misses/a.gets, '99990.999'))
       ||'     Ideal Target: < 1%'
  from v$latch a, v$latchname b
 where b.name = 'redo copy'
   and b.latch# = a.latch#;

select 'Enqueues Waits                     : '||to_char(value,'999999999') 
       ||'     Ideal Target:   0' 
  from v$sysstat
 where name = 'enqueue waits';

select 'Warning: Enqueue Timeouts are '||value||'. They should be zero' line1,
       'Increase the INIT.ora parameter ENQUEUE_RESOURCES'
  from v$sysstat
 where name  = 'enqueue timeouts'
   and value > 0;

prompt
select 'Incomplete Checkpoints             : '||to_char(sum(decode(a.name,'background checkpoints started',value,0)) - sum(decode(a.
       name,'background checkpoints completed',value,0))
       ,'999999999')||'     Ideal Target:  0' 
  from v$sysstat a;

select 'Rollback Segment Contention        : '||to_char(((a.undo_header+b.undo_block)/c.gets)*100,'990.99999')
       ||'     Ideal Target: < 1%'
  from (select max(decode(class,'undo header',count,0)) undo_header from v$waitstat) a,
       (select max(decode(class,'undo block',count,0)) undo_block from v$waitstat) b,
       (select sum(value) gets from v$sysstat where name in ('consistent gets','db block gets')) c;

select 'Table Fetch Continued Rows         : '||to_char(value,'999999999')
  from v$sysstat
 where name = 'table fetch continued row';

prompt
prompt =======================================================================================
prompt Wait Events
prompt =======================================================================================
prompt The following query displays information on wait contention for 
prompt an Oracle object. The two figures of particular importance are
prompt the 'data block' and the 'undo header' waits. The undo header 
prompt indicates a wait for rollback segment headers which can be solved by 
prompt adding rollback segments. 
prompt 
prompt The data block wait is a little harder to find the cause of and 
prompt a little harder to fix. Basically, transactions are contending for
prompt hot data blocks, because it is being held by another transaction, 
prompt or contending for shared resources within the block. e.g. transaction
prompt entries (set by the INITRANS parameter) and rows. The INITRANS  
prompt storage parameter sets the number of transaction slots set aside 
prompt within each table/index. The default INITRANS is 1. If more than
prompt one transaction is waiting to access a block, a second transaction
prompt slot will have to be created. Each transaction slot uses 23 bytes.
prompt 
prompt The ideal count on the data block waits is 0.   This is usually not
prompt achievable in the real world, because the storage overhead of increasing
prompt the INITRANS is usually not justified given the large amount of
prompt storage overhead that it will introduce. Data block contention can cause
prompt problems and enlarging INITRANS can improve performance, so don't
prompt dismiss the idea of enlarging INITRANS immediately.   Potential 
prompt performance improvements CAN be significant.
prompt 
prompt Identifying the blocks that are experiencing contention is quite
prompt difficult to catch. Your best chance is to examine the output from the
prompt query from the V$SESSION_WAIT table below. You may consider increasing
prompt the PCTFREE in the table to have fewer rows per block, or make a design
prompt change to your application to have fewer transactions accessing the same
prompt block. 
prompt
prompt All System Waits 
prompt
column count format 9999999;
select class, count 
  from v$waitstat;


prompt
prompt =======================================================================================
prompt ITL Waits
prompt
prompt Overly dense table block utilization can cause sessions to appear to lock as the table
prompt header is unable to extend the list of parallel transactions attempting to access the 
prmpt  table at a given time. 
prompt
prompt If tables appear in a list below, they can be fixed by re-orging them using larger 
prompt ini_trans values via Space Manager or Export Import.
prompt =======================================================================================
select owner,
object_name||' '||subobject_name object, value
from v$segment_statistics
where statistic_name='ITL waits'
and value >10;

prompt
prompt =======================================================================================
prompt Character Set Information
prompt =======================================================================================
select * from v$nls_parameters; 
prompt
prompt =========================================================================================================
prompt NLS Language Parameters (Metalink doc ID 241047.1)
prompt   NLS_DATABASE_PARAMETERS - Set in the init.ora during instance creation time
prompt   NLS_INSTANCE_PARAMETERS - Set in the init.ora at the moment the instance was started.
prompt =========================================================================================================

column x1 format a30 heading "PARAMETER"
column x2 format a35 heading "NLS_DATABASE_PARAMETERS"
column x3 format a35 heading "NLS_INSTANCE_PARAMETERS"

select a.parameter, a.value x2, b.value x3 
  from nls_database_parameters a,
       (select parameter, value from nls_instance_parameters) b
 where a.parameter = b.parameter
union
select a.parameter, a.value x2, '-----'
  from nls_database_parameters a
 where a.parameter in ( select parameter from nls_database_parameters
                        minus
                        select parameter from nls_instance_parameters);
prompt
prompt =======================================================================================
prompt SYS and SYSTEM Default Tablespaces
prompt Note: These should be set to SYSTEM.  If not, correct them.  
prompt   i.e.,  alter user sys default tablespace SYSTEM;
prompt =======================================================================================
Select username, default_tablespace from dba_users where username in ('SYS','SYSTEM');   
prompt
prompt =================================================================================================
prompt Resource Profiles
prompt ------------------------------
prompt Profile Columns and Descriptions
prompt ------------------------------
prompt  LIMIT CPU_PER_SESSION DEFAULT		Sec./100
prompt  CPU_PER_CALL DEFAULT				Sec./100
prompt  CONNECT_TIME DEFAULT				Minutes
prompt  IDLE_TIME DEFAULT				Minutes
prompt  SESSIONS_PER_USER DEFAULT			Per User
prompt  LOGICAL_READS_PER_SESSION DEFAULT		Blocks
prompt  LOGICAL_READS_PER_CALL DEFAULT		Block
prompt  PRIVATE_SGA DEFAULT				KBytes
prompt  COMPOSITE_LIMIT DEFAULT			Service Units
prompt  FAILED_LOGIN_ATTEMPTS DEFAULT		Number/Integer
prompt  PASSWORD_LOCK_TIME DEFAULT			Days
prompt  PASSWORD_GRACE_TIME DEFAULT			Days
prompt  PASSWORD_LIFE_TIME DEFAULT			Days
prompt  PASSWORD_REUSE_MAX DEFAULT			Number/Integer
prompt  PASSWORD_REUSE_TIME DEFAULT			Days
prompt ================================================================================================
column profile format a10;
column limit format a10;
SELECT * FROM DBA_PROFILES;
prompt
prompt =======================================================================================
prompt AUD Information.  
prompt Note: This should only return "SYSTEM"
prompt =======================================================================================
Select tablespace_name from dba_tables where table_name='AUD$';   
prompt
prompt =======================================================================================
prompt Privileged Access to the AUD$ Table.
prompt Fields: Grantee, Owner, Table_Name, Privilege
prompt =======================================================================================
SELECT GRANTEE, OWNER, TABLE_NAME, PRIVILEGE FROM DBA_TAB_PRIVS WHERE TABLE_NAME LIKE 'AUD%';

prompt
prompt =======================================================================================
prompt AUD Information.  
prompt Note: This should only return 0.  If not, consider truncating AUD$
prompt =======================================================================================
select count(*) from AUD$;
prompt
prompt =======================================================================================
prompt FGA Information.  
prompt Note: This should only return 0.  If not, consider truncating FGA$
prompt =======================================================================================
select count(*) from FGA$;
prompt
prompt =======================================================================================
prompt Database Resource Plans
prompt If this number is >3, then check DBA_RSRC_PLANS for current plans in effect.
prompt =======================================================================================
select count(*) from DBA_RSRC_PLANS;


prompt
prompt =======================================================================================
prompt SGA Total Size and Detail
prompt =======================================================================================
COLUMN name FORMAT A30 WRAP
COLUMN value FORMAT 999999999999 WRAP
BREAK ON REPORT SKIP 1
COMPUTE SUM OF value ON REPORT

set serveroutput on;
declare
  sga_size number;
begin
  select sum(value) into sga_size from v$sga;
  dbms_output.put_line('SGA Size             '||to_char(sga_size,'999999999999'));
end;
/
set serveroutput off;
prompt
prompt =======================================================================================
prompt CPU Utilization by Session
prompt =======================================================================================
select substr(name,1,30) parameter,
         ss.username||'('||se.sid||') ' user_process, value
  from v$session ss, v$sesstat se, v$statname sn
 where  se.statistic# = sn.statistic#
   and  name  like '%CPU used by this session%'
   and  se.sid = ss.sid
 order  by substr(name,1,25), value desc;

prompt
prompt =======================================================================================
prompt DBWR Process
prompt =======================================================================================
prompt The rows returned in the query below indicate the following:
prompt 
prompt DBWR Checkpoints: is the number of times that checkpoints were sent to the
prompt database writer process DBWR. The log writer process hands a list of modified 
prompt blocks that are to be written to disk. The "dirty" buffers to be written 
prompt are pinned and the DBWR commences writing the data out to the database.
prompt It is usually best to keep the DBWR checkpoints to a minimum, although 
prompt if there are too many dirty blocks to write out to disk at the one time
prompt due to a "lazy" DBWR, there may be a harmful effect on response times for
prompt the duration of the write.  See the parameters LOG_CHECKPOINT_INTERVAL and
prompt LOG_CHECKPOINT_TIMEOUT which have a direct effect on the regularity of 
prompt checkpoints. The size of your red logs  can also have an effect on the
prompt number of checkpoints if the LOG_CHECKPOINT_INTERVAL is set to a size 
prompt larger than your redo logs and the LOG_CHECKPOINT_TIMEOUT is longer than
prompt the time it takes fill a redo log or it has not been set. 
prompt 
prompt DBWR timeouts: the # times that the DBWR looked for dirty blocks to
prompt write to the database. Timeouts occur every 3 seconds if the DBWR is idle.           
prompt  
prompt DBWR make free requests: is the number of messages recieved requesting the
prompt database writer process to make the buffers free. This value is a key 
prompt indicator as to how effectively your DB_BLOCK_BUFFERS parameter is tuned.
prompt If you increase DB_BLOCK_BUFFERS and this value decreases markedly, there
prompt is a very high likelihood that the DB_BLOCK_BUFFERS was set too low.
prompt
prompt DBWR free buffers found: is the number of buffers that the DBWR found 
prompt on the lru chain that were already clean. You can divide this value by 
prompt the DBWR make free requests to obtain the number of buffers that were 
prompt found which were free and clean (i.e. did NOT have to be written to disk).
prompt
prompt DBWR lru scans: the number of times that the database writer scans the lru
prompt for more buffers to write. The scan can be invoked either by a make free
prompt request or by a checkpoint. 
prompt 
prompt DBWR summed scan depth: can be divided by DBWR lru scans to determine the
prompt length of the scans through the buffer cache. This is NOT the number of   
prompt buffers scanned. if the write batch is filled and a write takes place
prompt to disk, the scan depth halts. 
prompt 
prompt DBWR buffers scanned: is the total  number of buffers scanned when looking 
prompt for dirty buffers to write to disk and create free space. The count 
prompt includes both dirty and clean buffers.  It does NOT halt like the 
prompt DBWR summed scan depth.
prompt 
prompt The Amount of Times Buffers Have Had to Be Cleaned Out
column name format a50
select name , value 
  from v$sysstat
 where name like 'DBW%'; 

prompt
prompt =======================================================================================
prompt Segment-Level DB Buffer Busy Waits Where Wait Count > 20,000
prompt =======================================================================================
select object_name, value from v$segment_statistics where statistic_name like 'buffer busy%' and value > 20000;

prompt
prompt =======================================================================================
prompt Segment Class DB Buffer Busy Waits
prompt Note: A small number of waits for undo headers can cause a larger number of total waits.
prompt =======================================================================================
SELECT class, count FROM V$WAITSTAT 
WHERE count > 0 ORDER BY count DESC;


prompt
prompt =======================================================================================
prompt SGA Memory Usage
prompt =======================================================================================
column x1 format a20 heading "TYPE"
column x2 format a11 heading "POOL"

select name x1, pool x2, to_char(bytes,'999999999999') "        BYTES"
  from v$sgastat
 where name in ('db_block_buffers','dictionary cache','free memory','library cache','log_buffer','sql area')
 union
select 'other', substr(pool,1,11), to_char(sum(bytes),'999999999999')
  from v$sgastat
 where name not in ('db_block_buffers','dictionary cache','free memory','library cache','log_buffer','sql area')
 group by pool
 order by 2,1;

set echo off
set feedback on
create table javafree_bbmm (javafree number);
create table javaused_bbmm (javaused number);
insert into javafree_bbmm select bytes from v$sgastat where pool like '%java%' and name like '%free%';
insert into javaused_bbmm select bytes from v$sgastat where pool like '%java%' and name like '%memory in use%';
prompt =======================================================================================
prompt This number should be fractional and approach 0.  
prompt Otherwise the java pool parameter is set too high.
prompt =======================================================================================
select (s.javaused/p.javafree)*100  "Total java pool size as % of Actual Used" from javafree_bbmm p, javaused_bbmm s;
drop table javafree_bbmm;
drop table javaused_bbmm;
select * from v$sgastat
where pool like '%java%';

prompt
prompt =======================================================================================
prompt Shared Pool Utilization
prompt =======================================================================================
set serveroutput on;

declare
  object_mem number;
  cursor_mem number;
  mts_mem    number;
  mts_serv   number;
  used_pool  number;
  free_mem   number;
  pool_size  number;

begin
  select sum(sharable_mem) into object_mem from v$db_object_cache;
  select sum(250*users_opening) into cursor_mem from v$sqlarea;
  select sum(value) into mts_mem from v$sesstat a, v$statname b
   where a.statistic# = b.statistic#
     and b.name = 'session uga memory max';
  select to_number(value,'99') into mts_serv from v$parameter
   where name = 'mts_servers';
  select bytes into free_mem from v$sgastat
   where name = 'free memory'
     and pool = 'shared pool';  
  select to_number(value) into pool_size from v$parameter
   where name = 'shared_pool_size';
    
  if mts_serv = 0 then
    mts_mem := 0;
  end if;

  used_pool := round(1.2*(object_mem+cursor_mem+mts_mem));

  dbms_output.put_line('Object memory    :'||to_char(object_mem,'999999999999')||' bytes');
  dbms_output.put_line('Cursor memory    :'||to_char(cursor_mem,'999999999999')||' bytes');
  dbms_output.put_line('MTS memory       :'||to_char(mts_mem,'999999999999')||' bytes');
  dbms_output.put_line('Free memory      :'||to_char(free_mem,'999999999999')||' bytes');
  dbms_output.put_line('Shared Pool Used :'||to_char(used_pool,'999999999999')||' bytes');
  dbms_output.put_line('Shared Pool Size :'||to_char(pool_size,'999999999999')||' bytes');
  dbms_output.put_line('% Utilized       :'||to_char(round(used_pool/pool_size*100,0),'999999999999')||'%');

end;
/
set serveroutput off;

prompt
prompt =================================================================================================
prompt Buffer Cache Usages
prompt =================================================================================================
prompt The following query scans through the buffer cache and counts the number
prompt of buffers in the various states. The three main states are CUR which is
prompt blocks read but not dirtied, CR which are blocks that have been dirtied 
prompt and are remaining in cache with the intention of supplying the new values 
prompt to queries about to start up. FREE indicates buffers that are usable to 
prompt place new data being read into the buffer cache. You occasionally get 
prompt buffers in a status of READ which are those buffers currently being read 
prompt into the buffer cache. 
prompt 
prompt The major information from the query is if the FREE count is high, say
prompt > 50% of overall buffers, you may consider decreasing the DB_BLOCK_BUFFERS
prompt parameter. Note however, that Oracle attempts to maintain a free count > 
prompt 0, so consistently having free buffers does not automatically imply that
prompt you should have lower the parameter DB_BLOCK_BUFFERS.
prompt 
prompt Current Buffer Cache Usage   
select status, count(*) 
  from v$bh 
group by status;

prompt
prompt ==========================================================================================
prompt Database Buffer Tuning, II
prompt
PROMPT The value below is the number of buffers skipped to find a free buffer.
PROMPT If the value is larger than several hundred, increase the buffer cache (db_block_buffers).
prompt ==========================================================================================
select name, value from v$sysstat
where name='free buffer inspected';
prompt
prompt ==========================================================================================
prompt Database Buffer Tuning, III
prompt
PROMPT Free Buffer Waits are the number of times a server has waited b/c it cannot find a free buffer.
PROMPT Buffer Busy Waits are the number of times a process has waited for a buffer to become free.
PROMPT If the FBW is larger than 200, increase the buffer cache.
PROMPT If the BBW is larger than 1000, increase the buffer cache.
prompt ==========================================================================================
select event, total_waits from v$system_event
where event in ('free buffer waits','buffer busy waits');

prompt
prompt =======================================================================================
prompt User Session Hit Ratios
prompt =======================================================================================
prompt The following query breaks down hit ratios by user. The lower the hit ratio
prompt the more disk reads that have to be performed to find the data that the user 
prompt is requesting. If a user is getting a low hit ratio (say < 60%), it is often
prompt caused because  the user not using indexes effectively or an absence of 
prompt indexes. It can sometimes be quite OK to get a low hit ratio if the user
prompt is accessing data that has not been accessed before and cannot be shared
prompt amongst users. Note: OLTP applications ideally have a hit ratio in the mid
prompt to high 90s. 
prompt 
prompt The second query lists the tables that the user processes with a hit ratio
prompt less than 60% were accessing. Check the tables to ensure that there are no
prompt missing indexes.
prompt 
prompt User Hit Ratios
column "Hit Ratio" format 999.99
column  "User Session" format a15;
select se.username||'('|| se.sid||')' "User Session",
       sum(decode(name, 'consistent gets',value, 0))  "Consis Gets",
        sum(decode(name, 'db block gets',value, 0))  "DB Blk Gets",
        sum(decode(name, 'physical reads',value, 0))  "Phys Reads",
       (sum(decode(name, 'consistent gets',value, 0))  +
        sum(decode(name, 'db block gets',value, 0))  -
        sum(decode(name, 'physical reads',value, 0)))/
       (sum(decode(name, 'consistent gets',value, 0))  +
        sum(decode(name, 'db block gets',value, 0))  )  * 100 "Hit Ratio" 
  from  v$sesstat ss, v$statname sn, v$session se
where   ss.sid    = se.sid
  and   sn.statistic# = ss.statistic#
  and   value != 0
  and   sn.name in ('db block gets', 'consistent gets', 'physical reads')
group by se.username, se.sid;

prompt
prompt =======================================================================================
prompt Shared Pool SQL Contents
prompt =======================================================================================
prompt List Statements in Shared Pool with the Most Disk Reads
prompt 
select sql_text nl, 'Executions='|| executions  nl,
      'Expected Response Time in Seconds= ', 
     disk_reads / decode(executions, 0, 1, executions) / 50 "Response"  
  from v$sqlarea
where  disk_reads / decode(executions,0,1, executions) / 50 > 10 
order  by executions desc;

column "Response" format 999,999,999.99
prompt 
prompt List Statements in Shared Pool with the Buffer Scans   
prompt 
select sql_text nl, 'Executions='|| executions  nl,
            'Expected Response Time in Seconds= ', 
            buffer_gets / decode(executions, 0, 1, executions) / 500 "Response"  
  from v$sqlarea
where  buffer_gets / decode(executions, 0,1, executions) / 500 > 10 
order  by executions desc;

prompt 
prompt List Statements in Shared Pool with the Most Loads
prompt 
set long 1000
select sql_text, loads 
  from v$sqlarea a
where  loads > 100 
order  by loads desc;

prompt
prompt =======================================================================================
prompt Shared Pool Usage Patterns
prompt =======================================================================================
prompt The following figures are the reloads required for SQL, PL/SQL,
prompt packages and procedures. The ideal is to have zero reloads because 
prompt a reload by definitions is where the object could not be maintained 
prompt in memory and Oracle was forced to throw it out of memory, and then
prompt a request has been made for it to be brought back in. If your reloads
prompt are very high, try enlarging the SHARED_POOL_SIZE parameter and
prompt re-check the figures. If the figures continue to come down, continue 
prompt the SHARED_POOL_SIZE in increments of 5 Meg.
prompt 
prompt  Total Shared Pool Reload Stats
prompt  
select namespace, reloads 
  from v$librarycache;

prompt
prompt =======================================================================================
prompt Shared Pool Usage by Object
prompt =======================================================================================
prompt The following three queries obtain information on the SHARED_POOL_SIZE.
prompt 
prompt The first query lists the packages, procedures and functions in the 
prompt order of largest first.
prompt 
prompt The second query lists the number of reloads. Reloads can be very 
prompt damaging because memory has to be shuffled within the shared pool area
prompt to make way for a reload of the object.
prompt 
prompt The third parameter lists how many times each object has been executed.
prompt 
prompt Oracle has provided a procedure which is stored in $ORACLE_HOME/rdbms/admin
prompt called dbmspool.sql The SQL program produces 3 procedures. A procedure
prompt called keep (i.e. dbms_shared_pool.keep) can be run to pin a procedure in
prompt memory to ensure that it will not have to be re-loaded.    
prompt 
prompt Oracle offers 2 parameters that allow space to be reserved for
prompt procedures/packages above a selected size. This gives greater control 
prompt over the avoidance of fragmentation in the SHARED POOL.
prompt 
prompt See the parameters SHARED_POOL_RESERVED_SIZE and
prompt                            SHARED_POOL_RESERVED_MIN_ALLOC.
prompt 
prompt They are listed later in this report. 

column owner format a16
column name  format a36
column sharable_mem format 999,999,999
column executions   format 999,999,999
prompt 
prompt  Memory Usage of Shared Pool Order - Biggest First
prompt 
column name format 45
select  owner, name||' - '||type name, sharable_mem from v$db_object_cache
where sharable_mem > 10000
  and type in ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'PROCEDURE')
order by sharable_mem desc
/
prompt 
prompt  Loads into Shared Pool  - Most Loads First
prompt 
select  owner, name||' - '||type name, loads , sharable_mem from v$db_object_cache
where loads > 3 
  and type in ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'PROCEDURE')
order by loads desc
/
prompt 
prompt  Executions of Objects in the  Shared Pool  - Most Executions First
prompt 
select  owner, name||' - '||type name, executions from v$db_object_cache
where executions  > 100
  and type in ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'PROCEDURE')
order by executions  desc
/



prompt
prompt =======================================================================================
prompt Open Cursors
prompt =======================================================================================
prompt The next query lists the number of open cursors that each user is 
prompt currently utilising. Each SQL statement that is executed is stored
prompt partly in the Shared SQL Area and partly in the Private SQL Area.
prompt The private area is further broken into 2 parts, the persistent area
prompt and the runtime area. The persistent area is used for binding info. 
prompt The larger the number of columns in a query, the larger the persistent
prompt area. The size of the runtime area depends on the complexity of the
prompt statement. The type of statement is also a factor. An insert, update
prompt or delete statement will use more runtime area than a select. 
prompt 
prompt For insert, update and delete statements, the runtime area is freed
prompt immediately after the statement has been executed. For a query, the 
prompt runtime area is cleared only after all rows have been fetched or the
prompt query is cancelled. 
prompt 
prompt What has all this got to do with open cursors?
prompt 
prompt A private SQL area continues to exist until the corresponding cursor 
prompt is closed. Note: the runtime area is freed but the persistent (binding)
prompt area remains open. If the statement is re-used, leaving cursors open is
prompt not bad practice, if you have sufficient memory on your machine. Leaving
prompt cursors that are not likely to be used again is bad practice, once 
prompt again, particularly if you are short of memory. The number of private 
prompt areas is limited by the setting of OPEN_CURSORS init.ora parameter. The
prompt user process will continue to operate, despite having reached the OPEN_
prompt CURSOR limit. Cursors will be flushed and will need to be pe-parsed the
prompt next time they are accessed.
prompt 
prompt Recursive calls are used to handle the re-loading of the cursors if
prompt the have to be re-binded after being closed.
prompt 
prompt The data in the following query lists each user process, the number of
prompt recursive calls (the lower the better), the total opened cursors
prompt cumulative and the current opened cursors. If the number of current opened
prompt cursors is high (> 50), question why curors are not being closed. If the
prompt number of cumulative opened cursors and recursive calls is significantly 
prompt larger for some of the users, determine what transaction they are running
prompt and determine if they can leave cursors open to avoid having to re-bind
prompt the statements and avoid the associated CPU requirements.
drop view user_cursors;
create view user_cursors as
 select 
         ss.username||'('||se.sid||') ' user_process, 
          sum(decode(name,'recursive calls',value)) "Recursive Calls",
          sum(decode(name,'opened cursors cumulative',value)) "Opened Cursors",
          sum(decode(name,'opened cursors current',value)) "Current Cursors"
  from v$session ss, v$sesstat se, v$statname sn
 where  se.statistic# = sn.statistic#
   and (     name  like '%opened cursors current%'
          OR name  like '%recursive calls%'
          OR name  like '%opened cursors cumulative%')
   and  se.sid = ss.sid
   and   ss.username is not null
group by ss.username||'('||se.sid||') '
/


prompt 
prompt Per Session Current Cursor Usage 
prompt 
column USER_PROCESS format a25;
column "Recursive Calls" format 999,999,999;
column "Opened Cursors"  format 99,999;
column "Current Cursors"  format 99,999;
select * from user_cursors   
 order by "Recursive Calls" desc;
prompt
prompt 
prompt
column parameter format a29
column value     format a5
column usage     format a5

select
  'session_cached_cursors'  parameter,
  lpad(value, 5)  value,
  decode(value, 0, '  n/a', to_char(100 * used / value, '990') || '%')  usage
from
  ( select
      max(s.value)  used
    from
      sys.v_$statname  n,
      sys.v_$sesstat  s
    where
      n.name = 'session cursor cache count' and
      s.statistic# = n.statistic#
  ),
  ( select
      value
    from
      sys.v_$parameter
    where
      name = 'session_cached_cursors'
  )
union all
select
  'open_cursors',
  lpad(value, 5),
  to_char(100 * used / value,  '990') || '%'
from
  ( select
      max(sum(s.value))  used
    from
      sys.v_$statname  n,
      sys.v_$sesstat  s
    where
      n.name in ('opened cursors current', 'session cursor cache count') and
      s.statistic# = n.statistic#
    group by
      s.sid
  ),
  ( select
      value
    from
      sys.v_$parameter
    where
      name = 'open_cursors'
  )
/
prompt
prompt
prompt
column cursor_cache_hits format a17
column soft_parses format a11
column hard_parses format a11

select
  to_char(100 * sess / calls, '999999999990.00') || '%'  cursor_cache_hits,
  to_char(100 * (calls - sess - hard) / calls, '999990.00') || '%'  soft_parses,
  to_char(100 * hard / calls, '999990.00') || '%'  hard_parses
from
  ( select value calls from sys.v_$sysstat where name = 'parse count (total)' ),
  ( select value hard from sys.v_$sysstat where name = 'parse count (hard)' ),
  ( select value sess from sys.v_$sysstat where name = 'session cursor cache hits' )
/
prompt
prompt =======================================================================================
prompt Cached Object Information (Pinned)
prompt =======================================================================================
select namespace "NAME SPACE", to_char(sum(sharable_mem),'999999999999') "   TOTAL_SIZE"
  from v$db_object_cache
 where kept = 'YES'
 group by namespace;

prompt
prompt =======================================================================================
prompt Non-cached Object Information
prompt =======================================================================================
select namespace "NAME SPACE", to_char(sum(loads),'999999999999') " # OF RELOADS"
  from v$db_object_cache
 where kept = 'NO'
 group by namespace;

prompt
prompt =========================================================================================================
prompt Get Hit/Pin Hit Ratio
prompt =========================================================================================================

column x1 format a40      heading "NAME SPACE"
column x2 format 990.9999 heading "GET HIT RATIO"
column x3 format 990.9999 heading "PIN HIT RATIO"

select namespace x1, gets, gethits "GET HITS", pins, gethitratio x2, pinhitratio x3 from v$librarycache;

prompt
prompt =========================================================================================================
prompt Object Wait Status
prompt =========================================================================================================

select a.class, a.count "TIMES WAITED", a.time "TOTAL TIME"
  from v$waitstat a 
 where a.count > 0
 order by 1;
prompt
prompt =======================================================================================
prompt Disk/Memory Sorting Information
prompt =======================================================================================

set serveroutput on;

declare
     v_sort1   number;
     v_sort2   number;
     v_sort3   number;
     v_sort4   number;

begin
  select value into v_sort1 from v$parameter where name='sort_area_size';
  select sum(a.value) into v_sort2
    from v$sysstat a, v$statname b
   where a.statistic#=b.statistic#
     and b.name like 'sorts (memory)';
  select sum(a.value) into v_sort3
    from v$sysstat a, v$statname b
   where a.statistic#=b.statistic#
     and b.name like 'sorts (disk)';
  select sum(a.value) into v_sort4
    from v$sysstat a, v$statname b
   where a.statistic#=b.statistic#
     and b.name like 'sorts (rows)';

  dbms_output.put_line('Sort Area Size: '||to_char(v_sort1,'999999999'));
  dbms_output.put_line('Memory sorts  : '||to_char(v_sort2,'999999999'));
  dbms_output.put_line('Disk sorts    : '||to_char(v_sort3,'999999999'));
  dbms_output.put_line('Rows sorted   : '||to_char(v_sort4,'999999999'));
  dbms_output.put_line('%sort to disk : '||to_char((v_sort3/(v_sort3+v_sort2))*100,'999990D99'));
     
end;
/
set serveroutput off;

prompt
prompt =======================================================================================
prompt Redo Logfile Information
prompt Redo logs should switch between once and three times per hour.  If there are indications 
prompt that the redo logs are too small, run redo.sql and consider adding groups or resizing 
prompt the current members larger.
prompt Also make sure that the group members are multiplexed on different mount points that 
prompt correspond to different physical disks.
prompt =======================================================================================
select a.group#, b.sequence#, substr(member,1,40) "MEMBER", b.bytes/1048576 "Size", archived, b.status, b.first_time
  from v$logfile a, v$log b
 where a.group# = b.group#
 order by 1;

prompt
prompt =======================================================================================
prompt Control File Information
prompt NOTE: Make sure they are multiplexed.
prompt =======================================================================================
column x1 format a40 heading "NAME"
column x2 format a10 heading "STATUS"
select name x1, decode(status, NULL, 'OK', status) x2 from v$controlfile;
prompt 
prompt =======================================================================================
prompt Making a Backup of the Controlfile.  Please be sure to retrieve it from the udump destination.
prompt =======================================================================================
set feedback on;
alter database backup controlfile to trace noresetlogs;
set feedback on;
prompt
prompt ==================================================================================================
prompt System Events
prompt ==================================================================================================
column c1 format 9999990.99 heading "AVERAGE_WAIT"
select substr(event,1,40) "EVENT", total_waits, time_waited, total_timeouts, average_wait c1  
  from v$system_event;

prompt
prompt =======================================================================================
prompt Latch Contention
prompt Latch contention exists if the Hit Ratio is less than 95%.
prompt =======================================================================================
select substr(name,1,30) "LATCH NAME", gets, misses,
       round(100-(misses/decode(gets,0,1,gets)*100),0) hit_ratio, sleeps,
       round(sleeps/decode(misses,0,1,misses),0) sleep_ratio
  from v$latch
 where round(100-(misses/decode(gets,0,1,gets)*100),0) < 95
    or round(sleeps/decode(misses,0,1,misses),0) > 1;

prompt
prompt =======================================================================================
prompt Latch Contention
prompt =======================================================================================
prompt The following output lists latch contention. A latch is used to protect
prompt data structures inside the SGA and provide fast access to the database         
prompt buffers. A process that needs a latch has to own the latch which it must
prompt access from a hash table. If a process has problems obtaining a latch, it
prompt must wait until it is able to obtain one. Latch contention is more     
prompt predominant on multi CPU applications. Spinning on a latch avoids the 
prompt more costly operation of accessing the latch via conventional operating
prompt system queueing mechanism.
prompt 
prompt The output from the following report which can be tuned are the redo 
prompt latches.  The redo latches are the "redo allocation" and the "redo copy"
prompt latches. The redo allocation latch serially writes all changes to the 
prompt database to the log buffer. On a single CPU system, you cannot repair       
prompt contention on this latch, and in fact latches should be minimal on a 
prompt single CPU system. 
prompt 
prompt Latch contention tends to be much more evident on 
prompt multi CPU machines. If you have a multi-CPU machine, you must set the 
prompt INIT.ora parameter equal to the number of CPUs of your machine. Setting 
prompt this parameter allows a second latch (copy latch) to access the log buffer. 
prompt 
prompt All changed data which is written to the log buffer which is larger than the
prompt value specified in the parameter LOG_SMALL_ENTRY_MAX_SIZE is written to the
prompt copy latch and all those smaller that or equal to the size use the redo
prompt allocation latch. If you experience contention on the copy latch, you should
prompt decrease the  LOG_SMALL_ENTRY_MAX_SIZE to force more entries through the
prompt redo allocation latch. If the redo allocation latch has the problem, you
prompt can increase  LOG_SMALL_ENTRY_MAX_SIZE to force more entries through the 
prompt redo copy latch.
prompt 
prompt Another interesting latch contention figure is that for "cache buffer chains"
prompt and "cache buffer lru chains". This is latch waits on buffer cache accesses.
prompt The worst case I have seen on these waits was when a production DBA had 
prompt decided to turn on DB_LRU_EXTENDED_STATISTICS and DB_BLOCK_LRU_STATISTICS. 
prompt The DBA got some magnificent reports on the effect of increasing and 
prompt decreasing the DB_BLOCK_BUFFERS (buffer cache) but the production users
prompt weren't too happy with the significant response degradation. 
prompt 
prompt If you get latch contention on the a multi CPU computer, you can decrease
prompt the spin_count. The default spin count on most machines is set to 200. I 
prompt know of at least one benchmark on HP's where the spin_count was set to 1, 
prompt to achieve optimal throughput. I have been told that on single CPU machines
prompt you can increase a value "_Latch_Wait_postings" to say 20 and this will     
prompt provide a similar response improvement. Note: the _ in front of the parameter
prompt name indicates that it is a secret parameter. We are never totally sure if
prompt the secret parameters work. They appear to be on again/ off again from one
prompt version of Oracle to the next. See the output at the beginning of this report
prompt for a full list of undocumented parameters. 
prompt 
prompt Speaking of undocumented parameters, we used to be able to decrease the
prompt _DB_WRITER_MAX_SCAN_CNT and increase the _DB_BLOCK_WRITE_BATCH to avoid latch
prompt contention. Whether the parameters take effect will vary from one version of
prompt Oracle to the next. Try them out on your system only if you are experiencing
prompt latch contention.
prompt
prompt   Latch Gets and Misses 
prompt
prompt Latch name				Gets		  Misses      Imm Gets		     Imm Misses
prompt
set head on
select substr(name,1,25), gets, misses, 
       immediate_gets, immediate_misses
  from v$latch
 where misses > 0
    or immediate_misses > 0;

prompt
prompt =======================================================================================
prompt Rollback Information
prompt =======================================================================================
prompt
prompt Note:
prompt	9i uses Undo Segments, therefore this section should only normally list the SYSTEM 
prompt rollback segment.
prompt
prompt      If there are other rollback segments, confirm that the UNDO tablespace is created.
prompt
prompt =======================================================================================
prompt Undo Management
prompt AUTO   = undo
prompt MANUAL = rollback segments
select value from v$parameter where name ='undo_management';
prompt =======================================================================================
prompt Rollback Segments
select substr(b.segment_name,1,10) "SEGMENT", b.owner, substr(b.tablespace_name,1,11) "TABLESPACE", 
substr(b.status,1,8) "STATUS", a.bytes/1048576 seg_size_Megs, d.hwmsize "HWM", d.shrinks "SHRINKS",
       d.extends "EXTENDS", d.aveshrink "AVG SHRINK", a.initial_extent "INITIAL", a.next_extent "NEXT", a.min_extents,
       a.max_extents, to_char(a.pct_increase,'99999') " % INC"
  from dba_segments a, dba_rollback_segs b, v$rollname c, v$rollstat d
 where a.segment_name = b.segment_name
   and a.segment_name = c.name
   and c.usn          = d.usn
   and a.segment_type = 'ROLLBACK'
 order by 1, 2, 3;
prompt
prompt =========================================================================================================
prompt UNDO Management
prompt =========================================================================================================

column x1 format a40 heading "SEGMENT"
column x2 format a15 heading "TABLESPACE"
column x3 format a11 heading "STATUS"

select a.owner||'.'||a.segment_name x1, a.tablespace_name x2, to_char(a.bytes,'999999999999') "        BYTES",
       a.status x3
  from dba_undo_extents a
 order by 1, 2;

prompt
prompt =========================================================================================================
prompt UNDO Statistics (last 24 hours)
prompt =========================================================================================================

column x1 format a15       heading "BEGIN TIME"
column x2 format a15       heading "END TIME"
column x3 format 999999999 heading "UNEXPIRED|BLOCKS"
column x4 format 999999999 heading "ORACLE|ERRORS"
column x5 format 999999999 heading "SPACE|ERRORS"

select to_char(begin_time,'DD-MON-YY HH24:MI') x1, to_char(end_time,'DD-MON-YY HH24:MI') x2, 
       undoblks "BLOCKS", unxpstealcnt x3, ssolderrcnt x4, nospaceerrcnt x5
  from v$undostat;
prompt
prompt =======================================================================================
PROMPT Indications of Undo Segment Contention.
prompt
PROMPT NOTE:Non-zero WAITS values mean there is contention for that undo segment
prompt =======================================================================================
column name format a30;
select name, gets, waits,((waits/gets)*100) "Waits:Gets Ratio"
from v$rollstat a, v$rollname b
where a.usn=b.usn;
prompt
prompt =======================================================================================
prompt      The following query indicates the amount of rollbacks performed
prompt      on the transaction tables. 
prompt 
prompt (i)  'transaction tables consistent reads - undo records applied'
prompt        is the total # of undo records applied to rollback transaction
prompt        tables only
prompt 
prompt       It should be < 10% of the total number of consistent changes
prompt 
prompt (ii) 'transaction tables consistent read rollbacks'
prompt        is the number of times the transaction tables were rolled back
prompt 
prompt      It should be less than 0.1 % of the value of consistent gets
prompt 
prompt 
prompt      If either of these scenarios occur, consider creating more rollback
prompt      segments, or a greater number of extents in each rolback segment. A
prompt      rollback segment equates to a transaction table and an extent is like
prompt      a transaction slot in the table. 
prompt 
prompt Amount of Rollbacks on Transaction Tables
prompt ==========================================
prompt
select name, value      
  from v$sysstat
 where name in
   ('consistent gets',
    'consistent changes',
    'transaction tables consistent reads - undo records applied',
    'transaction tables consistent read rollbacks');
prompt 
prompt 
prompt 
prompt 
select 'Tran Table Consistent Read Rollbacks > 1% of Consistent Gets' aa,
       'Action: Create more Rollback Segments'
  from v$sysstat
 where decode (name,'transaction tables consistent read rollbacks',value)
                   * 100
                    /
       decode (name,'consistent gets',value) > 0.1
   and name in ('transaction tables consistent read rollbacks',
                     'consistent gets')
   and value > 0
;   
prompt 
prompt 
prompt 
prompt  
select 'Undo Records Applied > 10% of Consistent Changes' aa,
       'Action: Create more Rollback Segments'
  from v$sysstat
 where decode 
    (name,'transaction tables consistent reads - undo records applied',value)
                   * 100
                    /
       decode (name,'consistent changes',value) > 10  
   and name in 
         ('transaction tables consistent reads - undo records applied',
                     'consistent changes')
   and value > 0
;

prompt
prompt 
prompt The last two values returned in the following query are the number
prompt of times data blocks have been rolled back. If the number of rollbacks
prompt is continually growing, it can be due to inappropriate work practice.
prompt Try breaking long running queries into shorter queries, or find another
prompt method of querying hot blocks in tables that are continually changing. 
column name format a60;
select name , value
  from v$sysstat
 where name in
    ('data blocks consistent reads - undo records applied',
     'no work - consistent read gets',   
     'cleanouts only - consistent read gets',
     'rollbacks only - consistent read gets',
     'cleanouts and rollbacks - consistent read gets')
;
prompt 
prompt Each rollback segment has a transaction table that controls the 
prompt transactions accessing the rollback segment. Oracle documentation
prompt says that the transaction table has approximately 30 slots in the 
prompt table if your database has a 2k block size. The following query
prompt lists the number of waits on a slot in the transaction tables. The
prompt ideal is to have the waits zero, but in the real world this is not 
prompt always achievable. The should be as close to zero as possible.
prompt At the very worst, the ratio of gets to waits should be around 99%.
select usn "Rollback Table", Gets, Waits , xacts "Active Transactions"
  from v$rollstat;

prompt 
prompt It is important that rollback segments do not extend very often. 
prompt Dynamic extension is particularly  damaging to performance, because
prompt each extent used (or freed) is written to disk immediately. See the 
prompt uet$ and fet$ system tables. 
prompt 
prompt Some sites have a large amount of performance degradation when
prompt the optimal value is set, because the rollback is continually 
prompt shrinking and extending. This situation has been improved to 
prompt make the SMON less active where the PCTINCREASE is set to 0. 
prompt 
prompt Note: in this case, free extents will not be coalesced. When 
prompt a rollback throws extents after it has shrunk back, it will hopefully
prompt find an extent of the correct size. If you would like the coalescing
prompt to continue, set the PCTINCREASE on the tablespace to 1. 
prompt 
prompt We usually recommend NOT to use the OPTIMAL setting. 
prompt 
prompt The listing below provides figures on how many times each rollback
prompt segment has had to extend and shrink.
select usn, extends, shrinks, hwmsize, aveshrink
  from v$rollstat;


prompt
prompt =======================================================================================
PROMPT The SID and serial number for currently running SQL, which is useful when you want to 
prompt alter system kill session 'sid,serial#';
prompt =======================================================================================
column username format a10
column name format a6
set long 200
select a.name, b.xacts, c.sid, c.serial#, c.username, d.sql_text
from v$rollname a, v$rollstat b, v$session c, v$sqltext d, v$transaction e
where a.usn=b.usn
and b.usn=e.xidusn
and c.taddr=e.addr
and c.sql_address=d.address
and c.sql_hash_value=d.hash_value
order by a.name, c.sid, d.piece;
prompt
prompt =======================================================================================
prompt Database Link Information
prompt =======================================================================================

column name format a30 trunc;
column host format a20 trunc;
column userid format a15 trunc;
column password format a15 trunc;
This query will display passwords for database links..
select u.name, l.name, 
       l.userid,l.password, 
       l.host, l.ctime created
from sys.link$ l, sys.user$ u
where l.owner# = u.user#;

prompt
prompt =======================================================================================
prompt Database Outline Information
prompt =======================================================================================
prompt The total number of outlines in dba_outlines in this database are:
select count(*) from dba_outlines;
prompt
prompt =======================================================================================
prompt Database Outline Hints Information
prompt =======================================================================================
prompt The total number of outline hints in dba_outline_hints in this database are:
select count (*) from dba_outline_hints;
prompt
prompt =======================================================================================
prompt Database Resource Manager Plan Administrative Control Information
prompt You can also review DBA_RSRC_CONSUMER_GROUP_PRIVS, DBA_RSRC_MANAGER_SYSTEM_PRIVS,
PROMPT DBA_RSRC_PLANS, DBA_rSRC_PLAN_DIRECTIVES, DBA_RULESETS, and DBA_RSRC CONSUMER_GROUPS
prompt =======================================================================================
column comments format a40 trunc;
column cpu_method format a10 trunc;
column plan format a25 trunc;
select plan, cpu_method, comments, status from dba_rsrc_plans;
prompt
prompt =======================================================================================
prompt Current Database Resource Manager Plan Information
prompt =======================================================================================
select * from dba_rsrc_manager_system_privs
prompt
prompt =======================================================================================
prompt Database DBMS Alerts Information
prompt =======================================================================================
prompt The total number of DBMS Alerts in dbms_alert_info in this database are:
select count (*) from dbms_alert_info;

prompt
prompt ==========================================================================================
prompt Database Scheduled Jobs Information (DBMS_JOB)
prompt ==========================================================================================
set linesize 132
col job         format 99999;
col log_user    format a12;
col priv_user   format a12;
col schema_user format a12;
col interval    format a32;
col last        format a18;
col next        format a18;
col broken      format a6;
col what        format a80;
col interval    format a15 trunc;
col what        format a230;


select what, job JOB_NUMBER, log_user, priv_user, schema_user,
to_char(last_date, 'DD/MM/YY HH24:MI') "LAST (DD/MM/YY HH24:MI)", 
to_char(next_date, 'DD/MM/YY HH24:MI:SS') "NEXT (DD-MM-YY HH-Min-SS)",
interval, broken, failures
from dba_jobs
order by job;

prompt
prompt =======================================================================================
prompt Distributed Database Information
prompt =======================================================================================
select local_tran_id "LOCAL TRANSACTION", state "STATE", fail_time, retry_time
  from dba_2pc_pending;
prompt
prompt =========================================================================================================
prompt Database Properties
prompt =========================================================================================================

column x1 format a30 heading "PROPERTY NAME"
column x2 format a50 heading "PROPERTY VALUE"

select property_name x1, property_value x2 from database_properties;
prompt
prompt =======================================================================================
prompt Database Namespace Information
prompt =======================================================================================
select * from dba_context;

prompt
prompt =======================================================================================
prompt User Account Information
prompt
prompt NOTE: Confirm that the users' default and temp tablespaces are correct.
prompt =======================================================================================
column tq format A20 heading 'TABLESPACE_QUOTA'
column 'Tablespace Name' format a25 trunc;
column username format a15;
select substr(a.username,1,10) "Username", substr(default_tablespace,1,20) "Tablespace Name",
       bytes "Used Bytes", nvl(decode(max_bytes,'-1','UNLIMITED',max_bytes),' ') tq, b.max_bytes, b.max_blocks
  from dba_users a, dba_ts_quotas b
 where a.username           = b.username(+)
   and a.default_tablespace = b.tablespace_name(+)
 order by 1;

prompt
prompt =======================================================================================
prompt Read Only User Accounts
prompt
prompt =======================================================================================
select grantee from dba_tab_privs 
where grantee not like 'QUEST%'
minus
select grantee from dba_Tab_privs
where privilege !='SELECT';

prompt
prompt =======================================================================================
prompt Accounts to Consider Dropping
prompt     These accounts are locked and you might save space by dropping them.
prompt =======================================================================================
select owner, sum(bytes)/1024/1024 "Space Used (MB)" 
from dba_segments 
where owner in (select distinct username from dba_users where lock_date is not null)
group by owner;


prompt
prompt =======================================================================================
prompt Users' Roles
prompt
prompt NOTE: Confirm if Admin is granted whether this is appropriate.  Review YES in 3rd column.
prompt =======================================================================================
set echo off;
break on "USER" on "ROLE";
select substr(GRANTEE,1,10)		"USER",
       substr(GRANTED_ROLE,1,20)	"ROLE",
       substr(ADMIN_OPTION,1,3)		"ADM"
from dba_role_privs
order by 1,2;  

prompt
prompt =======================================================================================
prompt Table privileges granted to users with grantable option
prompt =======================================================================================

select	substr(grantee, 1, 10) grantee,
	substr(owner, 1, 15) owner,
	table_name,
	substr(grantor, 1, 10) grantor,
	substr(privilege, 1, 10) privilege,
	grantable
from	dba_tab_privs
where	grantable = 'YES';

select *
from dba_role_privs
where admin_option ='YES';
 
select	substr(grantor,1,10) "Grantor",	
	substr(grantee,1,10) "Grantee",
	ltrim(rtrim(substr(owner,1,15)))||'.'||substr(table_name,1,20) "Table",
	substr(privilege,1,10) "Privilege",
	substr(grantable,1,10) "Grantable" 
from	sys.dba_tab_privs
where	grantee not in ('SYS', 'SYSTEM', 'DBA')
and	owner not in ('SYS', 'SYSTEM')
order by 1,2,3;


select 	substr(grantee,1,10) "Grantee",
	substr(owner,1,10) "Owner",
	substr(table_name,1,50) "Table Name"
from 	sys.dba_tab_privs
where 	grantee not in (select role from sys.dba_roles); 

prompt
prompt =======================================================================================
prompt Table privileges granted to the Public user
prompt =======================================================================================

select	substr(grantor,1,10) "Grantor",
	ltrim(rtrim(substr(owner,1,10)))||'.'||substr(table_name,1,20) "Table",
	substr(privilege,1,10) "Privilege"
from	sys.dba_tab_privs
where	grantee = 'PUBLIC'
order by owner, table_name;

select	substr(grantor,1,10) "Grantor",
	ltrim(rtrim(substr(owner,1,10)))||'.'||substr(table_name,1,20) "Table",
	substr(privilege,1,10) "Privilege"
from	sys.dba_tab_privs
where	grantee = 'PUBLIC'
and privilege ='DELETE'
order by owner, table_name;


select	grantee "Grantee", 
	privilege
from	sys.dba_tab_privs
where	owner = 'SYS'
and	table_name = 'LINK$';

select 	substr(grantee,1,20) "Grantee", 
	ltrim(rtrim(substr(owner,1,10)))||'.'||substr(table_name,1,20) "Table",
	substr(privilege,1,10) "Privilege"
from	sys.dba_tab_privs
where	privilege in ('INSERT', 'UPDATE', 'DELETE')
and	grantee in (select role from sys.dba_roles);


prompt
prompt =======================================================================================
prompt Privileges on All_Source table granted to users
prompt =======================================================================================

select 	substr(grantee,1,20) "Grantee", 
	ltrim(rtrim(substr(owner,1,10)))||'.'||substr(table_name,1,20) "Table",
	substr(grantor,1,10) "Grantor",
	substr(privilege,1,10) "Privilege",
	grantable
from	sys.dba_tab_privs
where	table_name = 'ALL_SOURCE';

prompt
prompt =======================================================================================
prompt High level sys privileges granted to roles/users
prompt =======================================================================================

select 	substr(grantee,1,30) "Grantee",
       	substr(privilege,1,30) "Privilege"
from 	sys.dba_sys_privs
where 	(privilege like '%ANY%'
or 	privilege like '%CREATE%'
or 	privilege like '%DROP%'
or 	privilege like '%UNLIMITED%')
and 	grantee not in ('CONNECT', 'DBA', 'RESOURCE', 'SYS', 'SYSTEM');


SELECT	 * 
FROM 	SYS.DBA_SYS_PRIVS 
WHERE 	GRANTEE NOT IN 	(SELECT ROLE FROM SYS.DBA_ROLES);


select	grantee "Grantee",
	privilege,
	admin_option
from	sys.dba_sys_privs
where	admin_option = 'YES';

select	*
from	dba_sys_privs
where	privilege like 'ALTER%';

select	*
from	dba_sys_privs
where	admin_option = 'YES'
and 	privilege like 'ALTER%';


select	*
from	sys.dba_sys_privs
where	admin_option = 'YES'
and	grantee not in ('DBA', 'SYS', 'SYSTEM');


select	substr(grantee,1,30) "Grantee",
       	substr(privilege,1,30) "Privilege"
from 	sys.dba_sys_privs
where 	(privilege like 'ALTER%'
or	privilege like '%ANY%'
or 	privilege like '%CREATE%'
or 	privilege like '%DROP%'
or 	privilege like '%UNLIMITED%')
and 	grantee not in ('CONNECT', 'DBA', 'RESOURCE', 'SYS', 'SYSTEM');

select  substr(role,1,20) "Role",
        ltrim(rtrim(substr(owner,1,10)))||'.'||substr(table_name,1,20) "Owner",
        substr(privilege,1,9) "Privilege"
from 	sys.role_tab_privs
where 	owner not in ('SYS','SYSTEM') 
order by 1,2,3;


select	grantee "Grantee",
	granted_role,
	admin_option,
	default_role
from	sys.dba_role_privs
where	admin_option = 'YES';

select	granted_role
from	sys.dba_role_privs
where	grantee = 'PUBLIC';

select  substr(granted_role,1,30) "Granted Role",
        substr(grantee,1,20) "Grantee"
from 	sys.dba_role_privs
where 	granted_role not in ('RESOURCE','CONNECT')
and 	grantee not in ('SYS', 'SYSTEM', 'DBA')
order by 1,2;

select 	substr(granted_role,1,20) "Granted Role",
       	substr(grantee,1,20) "Grantee"
from 	sys.dba_role_privs
where	grantee not in ('SYS', 'SYSTEM', 'DBA')
order by 1,2;

select	substr(grantee,1,20) "Grantee",
	substr(granted_role,1,20) "Granted Role",
	default_role "Default"
from	sys.dba_role_privs
where 	grantee not in ('SYS', 'SYSTEM', 'DBA')
order by 1,2;

select	grantee, granted_role, default_role
from	sys.dba_role_privs 
where 	default_role = 'YES' 
and 	granted_role in	(select role from sys.dba_roles	where password_required = 'YES');

select	grantee, privilege
from	sys.dba_col_privs
where	owner = 'SYS'
and	table_name = 'LINK$';

prompt
prompt Key privileged IT functions 
prompt
SELECT  substr(grantee,1,30) "Grantee",	
	substr(privilege,1,20) "Privilege",
	substr(admin_option,1,3) "Admin_Option" 
FROM DBA_SYS_PRIVS 
WHERE 
	PRIVILEGE='CREATE USER' OR
	PRIVILEGE='BECOME USER' OR
	PRIVILEGE='ALTER USER' OR
	PRIVILEGE='DROP USER' OR
	PRIVILEGE='CREATE ROLE' OR
	PRIVILEGE='ALTER ANY ROLE' OR
	PRIVILEGE='DROP ANY ROLE' OR
	PRIVILEGE='GRANT ANY ROLE' OR
	PRIVILEGE='CREATE PROFILE' OR
	PRIVILEGE='ALTER PROFILE' OR
	PRIVILEGE='DROP PROFILE' OR
	PRIVILEGE='CREATE ANY TABLE' OR
	PRIVILEGE='ALTER ANY TABLE' OR
	PRIVILEGE='DROP ANY TABLE' OR
	PRIVILEGE='INSERT ANY TABLE' OR
	PRIVILEGE='UPDATE ANY TABLE' OR
	PRIVILEGE='DELETE ANY TABLE' OR
	PRIVILEGE='CREATE ANY PROCEDURE' OR
	PRIVILEGE='ALTER ANY PROCEDURE' OR
	PRIVILEGE='DROP ANY PROCEDURE' OR
	PRIVILEGE='CREATE ANY TRIGGER' OR
	PRIVILEGE='ALTER ANY TRIGGER' OR
	PRIVILEGE='DROP ANY TRIGGER' OR
	PRIVILEGE='CREATE TABLESPACE' OR
	PRIVILEGE='ALTER TABLESPACE' OR
	PRIVILEGE='DROP TABLESPACES' OR
	PRIVILEGE='ALTER DATABASE' OR
	PRIVILEGE='ALTER SYSTEM';


prompt
prompt =======================================================================================
prompt Current Users with DBA Role.  
prompt 
prompt NOTE: Confirm whether these are appropriate.
prompt        (alter user aabb account lock;)
prompt =======================================================================================
select grantee Username from dba_role_privs where granted_role='DBA';

prompt
prompt ==================================================================================================
prompt SYSDBA/SYSOPER Privilege users
prompt Users who have been granted SYSDBA and SYSOPER privileges as derived from the password file
prompt ==================================================================================================
select username, decode(sysdba,'TRUE','YES    ','NO     ') "SYSDBA?", decode(sysoper,'TRUE','YES     ','NO      ') "SYSOPER?"
  from V$PWFILE_USERS 
 order by 1;

prompt
prompt ==================================================================================================
prompt The following accounts can SELECT ANY TABLE
prompt They can query user password hashs
prompt And list out all database users
prompt ==================================================================================================
SELECT grantee
 FROM dba_role_privs
 WHERE granted_role in (
 SELECT grantee
  FROM dba_sys_privs
  WHERE privilege =
  'SELECT ANY TABLE')
  GROUP BY grantee
 INTERSECT 
 SELECT username
  FROM dba_users;


prompt
prompt ==================================================================================================
prompt The following accounts can ALTER USER.
prompt Users with this privilege can connect as SYS and assign themselves DBA.  
prompt Thus, these users can "own" the database
prompt ==================================================================================================

SELECT grantee
 FROM dba_role_privs
 WHERE granted_role in (
  SELECT grantee
   FROM dba_sys_privs
   WHERE privilege = 'ALTER USER')
   GROUP BY grantee
  INTERSECT 
  SELECT username
   FROM dba_users;



prompt
prompt ==================================================================================================
prompt Database Auditing
prompt ==================================================================================================
prompt 	Object Auditing
prompt 
select	*
from	sys.dba_obj_audit_opts
where	alt <> '-/-' 
or	aud <> '-/-' 
or	com <> '-/-' 
or	del <> '-/-' 
or	gra <> '-/-' 
or	ind <> '-/-' 
or	ins <> '-/-' 
or	loc <> '-/-' 
or	ren <> '-/-' 
or	sel <> '-/-' 
or	upd <> '-/-' 
or	ref <> '-/-' 
or	exe <> '-/-' ; 

prompt
prompt 	Link Auditing
prompt 
select	*
from	sys.dba_obj_audit_opts
where	object_name = 'LINK$';

prompt
prompt ==================================================================================================
prompt DBA_AUDIT_SESSION Information
prompt Lists all audit trail records concerning CONNECT and DISCONNECT.
prompt ==================================================================================================
select * from dba_audit_session;
prompt
prompt ==================================================================================================
prompt DBA_STMT_AUDIT_OPTS Information
prompt Current system auditing options performed across the system and by users.
prompt ==================================================================================================
select * from dba_stmt_audit_opts;

prompt
prompt ==================================================================================================
prompt DBA_AUDIT_TRAIL Information
prompt Lists all audit trail entries
prompt ==================================================================================================
select * from DBA_AUDIT_TRAIL;

prompt
prompt ==================================================================================================
prompt DBA_AUDIT_OBJECT Information
prompt Lists audit trail entries for all objects
prompt ==================================================================================================
select * from DBA_AUDIT_OBJECT;
prompt
prompt ==================================================================================================
prompt DBA_AUDIT_STATEMENT Information
prompt Lists audit trail entries for GRANT, REVOKE, AUDIT, NOAUDIT and ALTER SYSTEM statements.
prompt ==================================================================================================
select * from DBA_AUDIT_STATEMENT;
prompt
prompt ==================================================================================================
prompt DBA_AUDIT_POLICIES Information
prompt Lists all audit policies.
prompt ==================================================================================================
select * from DBA_AUDIT_POLICIES;

prompt
prompt =======================================================================================
PROMPT User Default Tablespace Settings
prompt =======================================================================================
COLUMN username HEADING  'User Name' FORMAT A15 WRAP
COLUMN default_tablespace    HEADING 'Default TS' FORMAT A15 WRAP
COLUMN temporary_tablespace    HEADING 'Temporary TS' FORMAT A15 WRAP
COLUMN created    HEADING 'Created' FORMAT A10
COLUMN profile    HEADING 'Profile' FORMAT A15 WRAP
SELECT username,
       default_tablespace,
       temporary_tablespace,
	substr(account_status,1,20) "Account Status",
       created,
	substr(Lock_date,1,11) "Lock date",
	substr(Expiry_date,1,11) "Expiry date",
       substr(Profile,1,10) "Assgn Profile",
substr(Initial_RSRC_Consumer_Group,1,20) "Consumer Grp"
  FROM dba_users
ORDER BY username;

prompt 
prompt =======================================================================================
PROMPT    Users Whose Temporary Tablespace are Not TEMP.
PROMPT****(NOTE: All users beside SYS and SYSTEM should have their temporary tablespaces set 
prompt     to TEMP to reduce tablespace fragmentation.)
prompt
PROMPT   To change a user XXXX's default temporary tablespace, use this syntax:
PROMPT 		alter user XXXX default tablespace TEMP;
prompt
prompt****(NOTE: If users do not have a temporary tablespace explicitly assigned, they default 
prompt     to the SYSTEM tablespace, which should not be allowed.  
prompt Modify and run tempmove.sql to correct the situation for large numbers of alter commands.  
prompt
prompt****(NOTE: In 9i, you can no longer assign a permanent locally managed tablespace 
prompt     as a users temporary tablespace, therefore pay attention to the first set of
prompt    information below
prompt =======================================================================================
prompt
select username from dba_users where temporary_Tablespace not in ('TEMP');
prompt
prompt =======================================================================================
prompt An Alternate Way to Find Which Users Do Not Use TEMP as Their Temporary Tablespace.
prompt =======================================================================================
select username, temporary_tablespace from dba_users a, dba_tablespaces b 
where a.temporary_tablespace=b.tablespace_name
and a.temporary_tablespace!='TEMP';

prompt
prompt =======================================================================================
prompt Multi-Threaded Server Information
prompt
prompt NOTE: If the number of SERVERS_STARTED is zero, then they are not running MTS.
prompt =======================================================================================
select * from v$mts;

prompt
prompt =======================================================================================
prompt Multi-Threaded Server Response Time
prompt
prompt If there is no information below, then they are not using MTS.  If they are,
prompt then you will have to significantly increase the size of the shared pool because 
prompt cursor-state and user-session-data components of the PGA are stored in shared pool in 
prompt MTS (configure large_pool_size init parameter).
prompt =======================================================================================
select b.network, 
       decode(sum(a.totalq),0,'NO RESPONSES',to_char((sum(wait)/sum(totalq))/100,'9999.999')||' secs') "AVERAGE WAIT"
  from v$queue a, v$dispatcher b
 where a.paddr = b.paddr
   and upper(a.type) = 'DISPATCHER'
 group by b.network;

prompt
prompt =======================================================================================
prompt Multi-Threaded Server Busy Time
prompt =======================================================================================
select network, sum(busy) / (sum(busy) + sum(idle)) "BUSY" 
  from v$dispatcher
 group by network;

prompt
prompt =======================================================================================
prompt Multi-Threaded Server Average Wait Time
prompt =======================================================================================
select decode(totalq,0,'NO REQUESTS',to_char((wait/totalq)/100,'99.999')||' secs') "AVERAGE WAIT"
  from v$queue
 where type = 'COMMON';

prompt
prompt =======================================================================================
prompt Init.ora Parameters
prompt =======================================================================================
select substr(name,1,30) "PARAMETER", substr(value,1,60) "VALUE" from v$parameter order by 1;

prompt
prompt =======================================================================================
prompt Storage Information
prompt =======================================================================================
prompt
select 'Total # of tablespaces   : '||to_char(count(*),'999990') from dba_tablespaces;
select 'Total # of data files    : '||to_char(count(*),'999990') from dba_data_files;
select 'Total # of temp files    : '||to_char(count(*),'999990') from dba_temp_files;
prompt
prompt Tablespace Size and Availability
prompt =======================================================================================
column total_size   format 9999999999
column total_free   format 9999999999 heading 'TOTAL_FREE'
column max_free     format 9999999999
column pct_free     format 999
column chunks_free  format 999999999
column sumb         format 999999999
column largest      format 999999999
column bytes        format 999999999
column max_extents  format 999999999999
select substr(x.tablespace_name,1,11) "TABLESPACE", x.status, sum(x.tots) total_size, sum(x.sumb) total_free, 
       sum(x.largest) max_free, sum(x.sumb)*100/sum(x.tots) pct_free, sum(x.chunks) chunks_free
  from (select a.tablespace_name, b.status, 0 tots, sum(a.bytes) sumb, max(a.bytes) largest, count(*) chunks
          from dba_free_space a, dba_tablespaces b
         where a.tablespace_name = b.tablespace_name
	 group by a.tablespace_name, b.status
        union
       select c.tablespace_name, d.status, sum(c.bytes) tots, 0, 0, 0
	 from dba_data_files c, dba_tablespaces d
	where c.tablespace_name = d.tablespace_name
	group by c.tablespace_name, d.status) x
  group by x.tablespace_name, x.status order by 6;

prompt
prompt Tablespace Tempfile Information
prompt =======================================================================================
column file_name format a40 trunc;
column file_name format a30 trunc;
SET LINESIZE 180
column bytes format a40;
column status format a15;
COLUMN TABLESPACE_name FORMAT A15 trunc;
select tablespace_name, file_name, status, bytes/1024/1024 as mb, maxbytes/1024/1024 max_mb from dba_temp_files;

prompt
prompt =======================================================================================
prompt Tablespace Storage Parameters
prompt * - Denotes PLUG-IN
prompt ==================================================================================================
column c1 format a11 heading "EXTENT MGMT"
column c2 format a10 heading "ALLOCATION"
column c3 format a13 heading "CONTENTS"
 column min format a15;
select substr(tablespace_name,1,15) "TABLESPACE", initial_extent "INITIAL", next_extent "NEXT",
       to_char(min_extents,'9999') " MIN", max_extents "MAX EXTENT", to_char(pct_increase,'9999') "% INC",
       decode(extent_management,'DICTIONARY','DICT     ',extent_management)||' ' c1, allocation_type||' ' c2,
       substr(contents,1,9)||decode(plugged_in,'NO','',' * ') c3
  from dba_tablespaces order by 1;
set echo      off
set feedback  off
set verify    off
set termout   on
set trimspool on
set linesize  150


prompt 
prompt =====================================================================================================
prompt Tablespace Estimated Growth
prompt =====================================================================================================
column c1 format '999999990' heading 'ADDITIONAL|EXTENTS'
column c2 format '999999990' heading '   ESTIMATED|      GROWTH'
select substr(tablespace_name,1,15) "TABLESPACE", count(*) "SEGMENTS", sum(extents)-count(*) c1,
       to_char((decode(sum(extents)-count(*),0,0,(sum(extents)-count(*))/count(*)))*100 ,'9999999990')||'%' c2
  from dba_segments
 group by tablespace_name
 order by 4 desc;

prompt
prompt ==================================================================================================
prompt Free Space Fragmentation Index
prompt ==================================================================================================
column total_free   format 9999999999 heading 'TOTAL_FREE'
column max_free     format 9999999999
column chunks_free  format 999999999
column sumb         format 999999999
column largest      format 999999999
column bytes        format 999999999
column fsfi_x       format 9999       heading 'FSFI'
select substr(x.tablespace_name,1,25) "TABLESPACE", sum(x.sumb) total_free, sum(x.largest) max_free, 
       sum(x.chunks) chunks_free, sum(x.fsfi) fsfi_x 
  from (select a.tablespace_name, sum(a.bytes) sumb, max(a.bytes) largest, count(*) chunks,
               round(sqrt(max(a.blocks)/sum(a.blocks))*(100/sqrt(sqrt(count(a.blocks)))),0) fsfi
          from dba_free_space a, dba_tablespaces b
         where a.tablespace_name = b.tablespace_name
         group by a.tablespace_name
        union
       select c.tablespace_name, 0, 0, 0, 0
         from dba_data_files c, dba_tablespaces d
        where c.tablespace_name = d.tablespace_name
        group by c.tablespace_name) x
  group by x.tablespace_name
 having sum(x.fsfi) < 30
  order by 5;

prompt
prompt =======================================================================================
PROMPT TEMP Tablespace Information  
prompt
prompt NOTE:If TEMP tablespace is Dictionary Managed, then make the size of the initial extent for 
prompt the TEMP tablespace match the value for sort_area_size as set in init.ora
prompt (reduces disk usage when sorts have to PI/PO to hardware).  
prompt
prompt NOTE:If TEMP tablespace is Locally Managed, then none of this applies because the space
prompt is not allocated on disk until, and as, needed.
prompt =======================================================================================
select tablespace_name, contents, extent_management from dba_tablespaces
where tablespace_name like '%TEMP%';
prompt Sort Area Size Information:
column name format a20;
column value format a20;
select name, value from v$parameter where name ='sort_area_size';

set echo off
set head on

prompt
prompt =======================================================================================
Prompt The following tablespaces contain both indexes and tables.
Prompt Where possible, separate the two segment types into distinct tablespaces.
prompt
prompt NOTE: Not all data tablespaces have companion index tablespaces, ie. Custom 3rd party 
prompt products or the CTXSYS schema.
prompt =======================================================================================
select distinct tablespace_name 
from dba_segments where segment_type ='INDEX' 
intersect
select distinct tablespace_name 
from dba_segments where segment_type ='TABLE';

prompt
prompt =======================================================================================
prompt Unindexed Tables
prompt =======================================================================================
prompt The following report lists tables without any indexes on then whatsoever.
prompt It is unusual for tables not to need an index. Even small tables require
prompt an index to guarantee uniqueness. Small tables also  require indexes for
prompt joining, because a full table scan will always drive a query (unless a 
prompt hint is used). If you are scanning through many rows in a large table
prompt using an index range scan and are looking up a reference table to expand 
prompt a code into the description stored in the smaller table, the query will 
prompt take considerably longer because the small table will be the driving 
prompt table. Larger tables can drag a machine to its knees if they are 
prompt continually accessed without going through an index. 
prompt 
prompt Report on all Tables Without Indexes
prompt 
select owner, table_name from all_tables
MINUS
select owner, table_name from all_indexes;

prompt
prompt =======================================================================================
prompt Unindexed Foreign Keys
prompt =======================================================================================
prompt The following output lists all foreign keys that do not have an index
prompt on the Child table, for example, we have a foreign key on the EMP table
prompt to make sure that it has a valid DEPT row existing. The foreign key is 
prompt placed on the EMP (deptno) column pointing to the DEPT (deptno) primary
prompt key.
prompt
prompt Obviously the parent table DEPT requires an index on deptno for the
prompt foreign key to point to. The effect of the foreign key that is not
prompt widely known is that unless an index is placed on the child table on
prompt the columns that are used in the foreign key, a share lock occurs on the 
prompt parent table for the duration of the insert, update or delete on the 
prompt child table. 
prompt 
prompt What is a share lock, you ask? The effect of a share lock is that all
prompt query users hoping to access the table have to wait until a single update
prompt user on the table completes his/her update. Update users cannot perform 
prompt their update until all query users complete their queries against the table.
prompt The bottom line is that if the parent table is a volatile table, the 
prompt share lock can cause the most incredible performance degradation. At a 
prompt recent benchmark, we had the entire benchmark grind to a halt because of this
prompt locking situation. If the parent table is a non-volatile table, you may
prompt be able to get away without the index on the child table, because the lock
prompt on the parent table is of no importance.
prompt
prompt The negative factor of the index on the child table is that I have observed
prompt tables with as many as 30 indexes on them and the performance degradation 
prompt has been caused by maintaining the excessive number of indexes. My advice 
prompt to these sites has been to only use foriegn key constraints on columns
prompt that have an index which can be used for other purposes (e.g. reporting)
prompt or that point to a non-volatile reference table.  Most tables have difficulty
prompt maintaining acceptable performance if they have > 10 indexes on them.
prompt 
prompt You may wish to take the foreign keys offline during the day and put them 
prompt online at night to report any errors into an exceptions table. You should 
prompt do this when the parent table is not being accessed.
prompt 
prompt  Foreign Constraints and Columns Without an Index on Child Table
prompt 
prompt =================================================================================================
prmopt ONLY INDEX NON-ORACLE SCHEMAS
prompt =================================================================================================
select acc.owner||'-> '||acc.constraint_name||'('||acc.column_name
               ||'['||acc.position||'])'||' ***** Missing Index'
from   all_cons_columns acc, all_constraints ac
where  ac.constraint_name = acc.constraint_name
 and   ac.constraint_type = 'R'
 and   (acc.owner, acc.table_name, acc.column_name, acc.position) in
 (select acc.owner, acc.table_name, acc.column_name, acc.position 
    from   all_cons_columns acc, all_constraints ac
   where  ac.constraint_name = acc.constraint_name
     and   ac.constraint_type = 'R'
  MINUS
  select table_owner, table_name, column_name, column_position
    from all_ind_columns)
order by acc.owner, acc.constraint_name, acc.column_name, acc.position;



prompt
prompt =======================================================================================
prompt List of un-analyzed indexes on analyzed tables.  
prompt
prompt !Analyze all indexes below!
prompt Sometimes indexes are re-built for performance and maintenance reasons, but the 
prompt associated tables and/or indexes are not re-ANALYZED, which  can cause servere 
prompt performance problems.
prompt
prompt This script will return tables with indexes that are not analyzed.
prompt You must then manually analyze all indexes below to have current statistics.
prompt =======================================================================================
set head on
select 'Index '||i.index_name||' not analyzed but table '||
       i.table_name||' is.'
  from dba_tables t, dba_indexes i
 where t.table_name    =      i.table_name
   and t.num_rows      is not null
   and i.distinct_keys is  null;


prompt
prompt =======================================================================================
prompt Reverse-Key Indexes
prompt These are very useful for RAC implementations
prompt =======================================================================================
select object_name from dba_objects where object_id in (select obj# from sys.ind$ where BITAND(property,4) =4);

prompt
prompt =======================================================================================
prompt Datafile Size and Availability
prompt =======================================================================================
select substr(file_name,1,40) "DATAFILE", substr(tablespace_name,1,11) "TABLESPACE",
       to_char(a.bytes,'999999999999') "        BYTES", 
       decode(b.status,'ONLINE',decode(a.status,'AVAILABLE','ONLINE','CHECK '),'SYSTEM',
       decode(a.status,'AVAILABLE','SYSTEM','CHECK '),'CHECK ') "STATUS",
       decode(c.time,null,'OK  ','CHK ')||' '||decode(d.status,'ACTIVE','ACT ','OK  ') "RCVY BKUP" 
  from dba_data_files a, v$datafile b, v$recover_file c, v$backup d
 where a.file_id = b.file#
   and a.file_id = c.file#(+)
   and a.file_id = d.file#(+)
 order by 1,2;

prompt
prompt =======================================================================================
prompt Datafile Remaining MB to Grow Into Maxbytes Allocation
prompt To Adjust maxbytes: alter database datafile '~~~' maxsize ~~~~M;
prompt =======================================================================================
column file_name format a40 trunc;
select tablespace_name, file_name, bytes, maxbytes, (maxbytes-bytes)/1024/1024 "Net Left (MB)" 
from dba_data_files
where tablespace_name not like '%UNDO%'
order by 1 asc;

prompt
prompt =======================================================================================
prompt Datafile Detail Information
prompt =======================================================================================
Select 	substr(FILE#,1,10) "File #" ,
	substr(CREATION_CHANGE#,1,10) "Creation#",
	substr(CREATION_TIME,1,10) "Time",
	substr(TS#,1,10) "TS#",
	substr(RFILE#,1,10) "RFile#",
	substr(STATUS,1,10) "Status",
	substr(ENABLED,1,10) "Enabled?",
	substr(CHECKPOINT_CHANGE#,1,10) "Checkpoint#",
	substr(CHECKPOINT_TIME,1,15) "Checkpt Time",
	substr(UNRECOVERABLE_CHANGE#,1,20) "Unrecoverable #",
	substr(UNRECOVERABLE_TIME,1,20) "Unrecoverable Time",
	substr(LAST_CHANGE#,1,10) "Last Change#",
	substr(LAST_TIME,1,10) "Time",
	substr(OFFLINE_CHANGE#,1,15) "Offline Change #",
	substr(ONLINE_CHANGE#,1,15) "Online change #",
	substr(ONLINE_TIME,1,15) "Online time",
	substr(BYTES,1,20) "Bytes",
	substr(BLOCKS,1,20) "Blocks",
	substr(CREATE_BYTES,1,20) "Create Bytes",
	substr(BLOCK_SIZE,1,20) "Block Size",
	substr(NAME,1,60) "Name",
	substr(PLUGGED_IN,1,20) "Plugged In?"
from	v$datafile
order by file#;

prompt
prompt =======================================================================================
prompt Datafile Creation Dates
prompt =======================================================================================
column name format a55 trunc;
set lines 200ed
select tablespace_name, name, creation_time 
from  v$datafile_header order by 3 asc;

prompt
prompt ==========================================================================================
prompt Key Database Data and File Locations:
prompt ==========================================================================================
column name format a40;
column value format a40;
Select name from v$datafile;
Select value from v$parameter where name like '%control%';
Select member from v$logfile;
select name, value from v$parameter where name like  'log_archive_d%';
column value format a50;
select name, value from v$parameter where name ='background_dump_dest';
select name, value from v$parameter where name ='user_dump_dest';
select name, value from v$parameter where name ='core_dump_dest';
select name, value from v$parameter where name like 'audit_f%';
prompt

prompt
prompt =======================================================================================
prompt Disk I/O Balancing - Deviation Target: <10%
prompt =======================================================================================
column name format a60;
select substr(b.name,1,40) "NAME", 
       to_char(sum(a.phyrds)+sum(a.phywrts),'9999999999') "      TOTAL", 
       to_char(sum(a.phyrds),'999999999') "     READS",
       to_char(sum(a.phywrts),'999999999') "    WRITES", 
       to_char((sum(a.phyrds) + sum(a.phywrts))/sum(c.total_io)*100,'999.9999') "DEVIATION"
  from v$filestat a, v$datafile b, (select sum(phyrds)+sum(phywrts) total_io from v$filestat) c
 where a.file#=b.file# group by substr(b.name,1,40) order by 5 desc;


prompt ==========================================================================================
prompt Disk I/O Balancing - Compare READ_PCT to WRITE_PCT to determine which datafiles
prompt 			    are read intensive, and which are write intensive.
prompt ==========================================================================================
column name format a45;
drop table tot_read_writes;
create table tot_read_writes
 as select sum(phyrds) phys_reads, sum(phywrts) phys_wrts
      from v$filestat;

column name format a35;
column phyrds format 999,999,999;
column phywrts format 999,999,999;
column read_pct format 999.99;         
column write_pct format 999.99;        
select name, phyrds, phyrds * 100 / trw.phys_reads read_pct, 
       phywrts,  phywrts * 100 / trw.phys_wrts write_pct
from  tot_read_writes trw, v$datafile df, v$filestat fs
where df.file# = fs.file# 
order by phyrds desc;

prompt
prompt =========================================================================================================
prompt Data Block Corruption
prompt =========================================================================================================

column x1 format a50 heading "DATA FILE"

select distinct a.block#, b.name x1
  from v$backup_corruption a, v$datafile b 
 where a.file# = b.file# 
union
select distinct a.block#, b.name x1
  from v$copy_corruption a, v$datafile b 
 where a.file# = b.file#
order by 1; 

prompt
prompt ==========================================================================================
prompt Table Scans
prompt ==========================================================================================
prompt The next group of figures are the those for table accesses.
prompt 
prompt The "table fetch row continued rows" have been accessed and the row has 
prompt either been chained or migrated. Both situations result from part of
prompt a row has been forced into another block. The distinction is for
prompt chained rows, a block is physically to large to fit in one physical 
prompt block. 
prompt 
prompt In these cases, you should look at increasing the db_block_size
prompt next time you re-build your database, and for other environments, e.g.
prompt when you move your application into production. Migrated rows are rows
prompt that have been expanded, and can no longer fit into the same block. In these
prompt cases, the index entries will point to the original block address, but the
prompt row will be moved to a new block. The end result is that FULL TABLE SCANS
prompt will run no slower, because the blocks are read in sequence regardless of
prompt where the rows are. Index selection of the row will cause some degradation
prompt to response times, because it continually has to read an additional block.
prompt To repair the migration problem, you need to increase the PCTFREE on the
prompt offending table.
prompt 
prompt The  other values include "table scans (long tables)" which is a scan 
prompt of a table that has > 5 database blocks and table scans (short tables)
prompt which is a count of Full Table Scans with 5 or less blocks. These values
prompt are for Full Table Scans only. Any Full Table Scan of a long table can
prompt be potentially crippling to your application's performance. If the number
prompt of long table scans is significant, there is a strong possibility that
prompt SQL statements in your application  need tuning or indexes need to be added.
prompt 
prompt To get an appreciation of how many rows and blocks are being accessed on
prompt average for the long full table scans:                           
prompt 
prompt Average Long Table Scan Blocks = 
prompt              table scan blocks gotten - (short table scans * 5) 
prompt                                   / long table scans
prompt 
prompt 
prompt Average Long Table Scan Rows = 
prompt              table scan rows gotten - (short table scans * 5) 
prompt                                   / long table scans
prompt 
prompt The output also includes values for "table scan (direct read)" which
prompt are those reads that have bypassed the buffer cache, table scans 
prompt (rowid ranges) and table scans (cache partitions).
prompt 
prompt 
select name, value 
  from v$sysstat
where  name like '%table %';

drop view Full_Table_Scans;

create view Full_Table_Scans as
 select 
       ss.username||'('||se.sid||') ' "User Process", 
       sum(decode(name,'table scans (short tables)',value)) "Short Scans",
       sum(decode(name,'table scans (long tables)', value)) "Long Scans",
          sum(decode(name,'table scan rows gotten',value)) "Rows Retreived"
  from v$session ss, v$sesstat se, v$statname sn
 where  se.statistic# = sn.statistic#
   and (     name  like '%table scans (short tables)%'
          OR name  like '%table scans (long tables)%'
          OR name  like '%table scan rows gotten%'     )
   and  se.sid = ss.sid
   and   ss.username is not null
group by ss.username||'('||se.sid||') ';

column  "User Process"     format a20;  
column  "Long Scans"       format 999,999,999;   
column  "Short Scans"      format 999,999,999;   
column  "Rows Retreived"   format 999,999,999;   
column  "Average Long Scan Length" format 999,999,999;   
prompt 
prompt Table Access Activity By User 
select "User Process", "Long Scans", "Short Scans", "Rows Retreived"
  from Full_Table_Scans 
 order by "Long Scans" desc; 
prompt 
prompt Average Scan Length of Full Table Scans by User 
select "User Process", ( "Rows Retreived" - ("Short Scans" * 5))
                            / ( "Long Scans" ) "Average Long Scan Length"
  from Full_Table_Scans 
 where "Long Scans" != 0
 order by "Long Scans" desc; 

prompt
prompt =======================================================================================
prompt Segment and Object Information
prompt ==================================================================================================
prompt Summary of Objects excluding SYS and SYSTEM
prompt ==================================================================================================
select rpad(a.obj_name,35,'.') "Objects", a.obj_count "     Count"
  from ( select 0 c1,'Oracle Users' obj_name, to_char(count(*) ,'999999999') obj_count
           from dba_users
          where username not in ('SYS','SYSTEM')
          group by 'Oracle Users'
          UNION
         select decode(object_type,'TABLE',1,'INDEX',2,'TRIGGER',3 ,'VIEW',5,'SYNONYM',6,'PACKAGE',7,'PACKAGE BODY',
                8,'PROCEDURE',9,'FUNCTION',10 ,100),
                decode(object_type,'INDEX','     INDEX','TRIGGER','     TRIGGER',object_type), to_char(count(*) ,'999999999')
           from dba_objects
          where owner not in ('SYS','SYSTEM')
          group by object_type
          UNION
         select 4 , '     CONSTRAINT('||decode(constraint_type,'C','Check)','P','Primary)','U','Unique)','R','Referential)',
                                       'V','Check View)',constraint_type||')'), to_char(count(*) ,'999999999')
           from dba_constraints
          where owner not in ('SYS','SYSTEM')
          group by constraint_type ) a
  order by a.c1;

prompt
prompt =======================================================================================
prompt Database Materialized Views 
prompt =======================================================================================
set lines 300;
set long 3000;
column owner format a10 trunc;
column name format a20 trunc;
column query format a70 wrap;
column staleness format a10;
select owner, mview_name, last_refresh_date, query  from dba_mviews
order by owner asc;

prompt
prompt =======================================================================================
prompt Database Nested Tables
prompt =======================================================================================
select * from dba_nested_tables;

prompt
prompt =======================================================================================
prompt Database Collection Types
prompt =======================================================================================
select owner, type_name, coll_type from dba_coll_types
order by 1 desc;

prompt
prompt =======================================================================================
prompt Database External Tables Registered
prompt =======================================================================================
select * from dba_external_tables;
prompt 
column x1 format a40 heading "TABLE"
column x2 format a7  heading "ACCESS"
column x3 format a50 heading "LOCATION"

select a.owner||'.'||a.table_name x1, a.access_type x2, b.location x3
  from dba_external_tables a, dba_external_locations b
 where a.owner      = b.owner
   and a.table_name = b.table_name
 order by a.owner, a.table_name;

prompt
prompt =======================================================================================
prompt Database Datatypes Available
prompt =======================================================================================
select type_name from dba_types order by 1 asc;

prompt =======================================================================================
prompt Analyzed Table Objects
prompt =======================================================================================
prompt
prompt NOTE: Review/Analyze schemas with a "CHECK" value in the last column.
prompt =======================================================================================
column c1 format 99999999999 heading "LAST 10 DAYS"
column c2 format 99999999999 heading "LAST 30 DAYS"
column c3 format     9999999 heading "31+ DAYS"
select substr(owner,1,20) "OWNER", count(*) "OBJECTS",
       nvl(sum(decode(nvl(num_rows,9999),9999,0,1)),0) "ANALYZED",
       nvl(sum(decode(temporary,'Y',1,0)),0) "TEMPORARY",
       nvl(sum(decode(greatest( 0,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),
       least(10,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c1,
       nvl(sum(decode(greatest(11,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),
       least(30,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c2,
       nvl(sum(decode(greatest(31,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c3,
       decode(count(*) - (sum(decode(nvl(num_rows,9999),9999,0,1))+sum(decode(temporary,'Y',1,0))),0,
       'OK      ','CHECK  ') "COMMENT"
  from dba_tables
 where owner not in ('SYS','SYSTEM','AURORA$JIS$UTILITY$','DBSNMP','CTXSYS','MDSYS','ORDSYS','OSE$HTTP$ADMIN','OUTLN')
 group by owner;

prompt
prompt =======================================================================================
prompt Analyzed Index Objects
prompt
prompt NOTE: Review/Analyze schemas with a "CHECK" value in the last column.
prompt =======================================================================================
select substr(owner,1,20) "OWNER", count(*) "OBJECTS",
       nvl(sum(decode(nvl(num_rows,9999),9999,0,1)),0) "ANALYZED",
       nvl(sum(decode(temporary,'Y',1,decode(index_type,'LOB',1,'DOMAIN',1,0))),0) "OTHER",
       nvl(sum(decode(greatest( 0,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),
       least(10,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c1,
       nvl(sum(decode(greatest(11,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),
       least(30,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c2,
       nvl(sum(decode(greatest(31,ceil(sysdate - decode(last_analyzed,null,sysdate+1,last_analyzed))),1,0)),0) c3,
       decode(count(*) - 
       (sum(decode(nvl(num_rows,9999),9999,0,1))+sum(decode(temporary,'Y',1,decode(index_type,'LOB',1,'DOMAIN',1,0)))),0,
       'OK      ','CHECK  ') "COMMENT"
  from dba_indexes
 where owner not in ('SYS','SYSTEM','AURORA$JIS$UTILITY$','DBSNMP','CTXSYS','MDSYS','ORDSYS','OSE$HTTP$ADMIN','OUTLN')
 group by owner;


prompt
prompt =======================================================================================
prompt Analyzed Index Objects
prompt
prompt Analyze the following index objects to check for block corruption:
prompt --use this syntax:
prompt --analyze index owner.inde_name validate structure;
prompt
prompt 	The INDEX_STATS dict view shows you the number of index entries in leaf nodes in the 
prompt 	LF_ROWS column compared to the number of deleted entries in the DEL_LF_ROWS column.  
prompt 	Oracle recommends that if the number of deleted entries is over 30 percent, you should rebuild the index.
prompt 
prompt =======================================================================================

select owner, index_name, table_owner, table_name, last_analyzed 
from dba_indexes 
where last_analyzed < sysdate -12



prompt
prompt =======================================================================================
prompt Segments above 20 Extents
prompt =======================================================================================
column max_extents  format 9999999999 heading 'MAX_EXTENT'
column next_extent  format 999999999
column extents      format 99999 heading 'EXTENT'
column pct_used     format 999 heading 'PCT_USED'
select substr(owner||'.'||segment_name,1,40) "SEGMENT NAME", substr(segment_type,1,5) "TYPE ",
       extents, to_char(bytes,'999999999999') "        BYTES", max_extents, next_extent
  from dba_segments
 where segment_type in ('TABLE','INDEX') and extents > 20
 order by 3 desc, owner, segment_name;

prompt
prompt =======================================================================================
prompt Segments exceeding next extent space allocation
prompt =======================================================================================
select substr(owner||'.'||segment_name,1,40) "SEGMENT NAME", 
       substr(a.tablespace_name,1,11) "TABLESPACE"
  from dba_segments a, sys.sm$ts_free b
 where a.tablespace_name = b.tablespace_name
   and a.next_extent > b.bytes
 order by 1;

prompt
prompt =======================================================================================
prompt Segments exceeding 50 percent used
prompt =======================================================================================
column p_used      format 999 heading '% USED'
select substr(owner||'.'||segment_name,1,40) "SEGMENT NAME", substr(segment_type,1,5) "TYPE ",
       extents, bytes, max_extents, next_extent, ((extents/max_extents)*100) p_used
  from dba_segments
 where segment_type in ('TABLE','INDEX')
   and extents > 20
   and (extents/DECODE(max_extents,0,1,max_extents))* 100 >= 50
 order by 7 desc, owner, segment_name;

prompt
prompt =======================================================================================
prompt Invalid Objects
prompt Use maincomp.sql to recompile repeatedly.
prompt =======================================================================================
set echo off
column owner format a10;
column object_name format a30;
column object_type format a30;

PROMPT
PROMPT  Invalid Count by Owner
PROMPT  ______________________
select owner, count(*) 
from dba_objects 
where status='INVALID'
group by owner
order by 1,2;

PROMPT
PROMPT Total Number of Invalids
PROMPT ________________________
select count(*)
from dba_objects 
where status='INVALID';

prompt
prompt Invalids by Owner
PROMPT ________________________
select substr(owner||'.'||object_name,1,40) "OBJECT", substr(object_type,1,20) "TYPE"
  from dba_objects where status ='INVALID';






prompt
prompt =======================================================================================
prompt Non-Base Install Simple Partitioned Tables 
prompt =======================================================================================
set lines 600;
col owner format a15 trunc;
select owner, table_name, partitioning_type, subpartitioning_type, partition_count from DBA_PART_TABLES
where owner not in ('SYS','SYSTEM','APPS','APPLSYS','MSC');

prompt
prompt =======================================================================================
prompt Non-Base Install Partitioned Tables PARTITIONS
prompt =======================================================================================
col high_value format a20 trunc;
col tablespace_name format a30 trunc;
col table_owner format a11 trunc;
col partition_name format a15 trunc;
col tablespace_name format a7 trunc;
col last_analyzed format a9 trunc;
select table_owner, table_name, composite, partition_name, subpartition_count, high_value, tablespace_name, num_rows, last_analyzed
from dba_tab_partitions
where table_owner not in ('SYS','SYSTEM','APPS','APPLSYS','MSC');


prompt
prompt =======================================================================================
prompt Non-Base Install Partitioned Tables SUBPARTITIONS
prompt
prompt If there is nothing listed below, then subpartitioning is not used in this database.
prompt
prompt =======================================================================================
select table_owner, table_name, partition_name, subpartition_name, high_value, tablespace_name, num_rows, last_analyzed
from dba_tab_subpartitions
where table_owner not in ('SYS','SYSTEM','APPS','APPLSYS','MSC');



prompt
prompt =======================================================================================
prompt Chained/Migrated Rows
prompt
prompt LEGEND:
prompt PART - Partitioned, TEMP - Temporary, IOT  - Index Organized Table
prompt LONG - Long Data Type, XARL - AVG_ROW_LEN exceeds db block size
prompt =======================================================================================
column c1 format a18 head "COMMENT"
select substr(a.owner||'.'||a.table_name,1,35) "TABLE", to_char(a.pct_free,'99999') "% FREE",
       to_char(a.pct_used,'99999') "% USED", a.chain_cnt "CHAINS", a.num_rows "ROWS", 
       to_char(round((a.chain_cnt/a.num_rows)*100,0),'99999') " RATIO",
       decode(a.partitioned,'YES',decode(a.temporary,'Y',decode(a.iot_type,NULL,'PART TEMP ','PART TEMP IOT '),
       decode(a.iot_type,NULL,'PART ','PART IOT ')),decode(a.temporary,'Y',
       decode(a.iot_type,NULL,'TEMP ','TEMP IOT '),decode(a.iot_type,NULL,'','IOT ')))||
       decode(nvl(b.l_cnt,0),0,decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'','XARL'),
       decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'LONG','LONG XARL')) c1
  from dba_tables a,
       (select table_name, sum(decode(data_type,'LONG',1,'LONG RAW',1,0)) l_cnt
          from dba_tab_columns
         where data_type in ('LONG','LONG RAW')
         group by table_name) b,
       (select to_number(value) blk_sz from v$parameter where name = 'db_block_size') c
 where a.table_name = b.table_name(+)
   and a.owner not in ('SYSTEM','SYS')
   and round((nvl(a.chain_cnt,0)/decode(a.num_rows,0,1,a.num_rows))*100,0) >= 10
 order by 2 desc;
prompt
prompt =========================================================================================================
prompt Index-Organized Table Chained/Migrated Rows
prompt
prompt LEGEND:
prompt PART - Partitioned, TEMP - Temporary, IOT  - Index Organized Table
prompt LONG - Long Data Type, XARL - AVG_ROW_LEN exceeds db block size
prompt =========================================================================================================

column x1 format a35 heading "TABLE"
column x2 format a18 heading "COMMENT"

select a.owner||'.'||a.table_name x1, to_char(d.pct_threshold,'99999') "% THRESHOLD",
       to_char(d.include_column,'99999') "INCLUDING", a.chain_cnt "CHAINS", a.num_rows "ROWS", 
       to_char(round((a.chain_cnt/a.num_rows)*100,0),'99999') " RATIO",
       decode(a.partitioned,'YES',decode(a.temporary,'Y',decode(a.iot_type,NULL,'PART TEMP ','PART TEMP IOT '),
       decode(a.iot_type,NULL,'PART ','PART IOT ')),decode(a.temporary,'Y',
       decode(a.iot_type,NULL,'TEMP ','TEMP IOT '),decode(a.iot_type,NULL,'','IOT ')))||
       decode(nvl(b.l_cnt,0),0,decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'','XARL'),
       decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'LONG','LONG XARL')) x2
  from dba_tables a,
       (select table_name, sum(decode(data_type,'LONG',1,'LONG RAW',1,0)) l_cnt
          from dba_tab_columns
         where data_type in ('LONG','LONG RAW')
         group by table_name) b,
       (select to_number(value) blk_sz from v$parameter where name = 'db_block_size') c,
       dba_indexes d
 where a.table_name = b.table_name(+)
   and a.owner      = d.owner
   and a.table_name = d.table_name
   and a.owner not in ('SYSTEM','SYS')
   and a.iot_type  is not null
   and round((nvl(a.chain_cnt,0)/decode(a.num_rows,0,1,a.num_rows))*100,0) >= 10
 order by 2 desc;
prompt ============================================================================================
prompt ALL TABLES WITH PERCENTAGE OF CHAINED ROWS > 0.1% (acceptable < 3%)
prompt ============================================================================================
set linesize 132
select owner||'.'||table_name "Table",
       nvl(chain_cnt,0)/(nvl(num_rows,0)+1)*100 chained_rows_percent,
       nvl(chain_cnt,0)/1000 num_chained_rows,
       nvl(num_rows,0)/1000 num_rows
  from dba_tables
 where owner not in ('SYS', 'SYSTEM', 'MHSYS', 'OEM16', 'OEM204', 'OEM21', 'OEM22', 'SPC_DEMO_USER')
   and nvl(chain_cnt,0)/(nvl(num_rows,0)+1)*100 > 0.1
 order by 2 desc, 1;
prompt
prompt
prompt

prompt ============================================================================================
prompt ALL TABLES WITH PERCENTAGE OF CHAINED ROWS > 0.1% (acceptable < 3%)
prompt ============================================================================================
select owner||'.'||table_name,
       nvl(chain_cnt,0)/(nvl(num_rows,0)+1)*100 chained_rows_percent,
       nvl(chain_cnt,0)/1000 num_chained_rows,
       nvl(num_rows,0)/1000 num_rows
  from dba_tables
 where owner not in ('SYS', 'SYSTEM', 'MHSYS', 'OEM16', 'OEM204', 'OEM21', 'OEM22', 'SPC_DEMO_USER')
   and nvl(chain_cnt,0)/(nvl(num_rows,0)+1)*100 > 0.1
 order by 2 desc, 1;
prompt
prompt
prompt

prompt ============================================================================================
prompt ALL TABLES WITH FREESPACE/BLOCK > 2*PCTFREE
prompt ============================================================================================
select owner||'.'||table_name,
       nvl(avg_space,0)/p.value*100 avg_space_percent,  -- avg_space is average free space in a block below HWM
       nvl(pct_free,0) percent_free,
       nvl(pct_used,0) percent_used,
       nvl(avg_row_len,0) avg_row_len,
       nvl(num_rows,0)/1000 num_rows
  from dba_tables, v$parameter p
 where owner not in ('SYS', 'SYSTEM', 'MHSYS', 'OEM16', 'OEM204', 'OEM21', 'OEM22', 'SPC_DEMO_USER')
   and p.name = 'db_block_size'
   and num_rows > 1000
   and nvl(avg_space,0)/p.value*100 > 2*pct_free
 order by 2 desc, 5 desc;
prompt
prompt
prompt

prompt ============================================================================================
prompt ALL TABLES WITH PERCENTAGE OF EMPTY BLOCKS (ABOVE HWM) > 50% (waisted space)
prompt ============================================================================================
select owner||'.'||table_name,
       nvl(t.empty_blocks,0)/(nvl(t.empty_blocks+t.blocks,0)+1)*100 empty_blocks_percent, -- empty blocks above  HWM
       nvl(t.empty_blocks,0)/(nvl(t.empty_blocks+t.blocks,0)+1)
           *(nvl(t.empty_blocks+t.blocks,0)*p.value/1024/1024) waisted_space_mb,
       nvl(t.empty_blocks+t.blocks,0)*p.value/1024/1024 table_size_mb,
       nvl(t.avg_row_len,0) avg_row_len,
       nvl(t.num_rows,0)/1000 num_rows
  from dba_tables t, v$parameter p
 where owner not in ('SYS', 'SYSTEM', 'MHSYS', 'OEM16', 'OEM204', 'OEM21', 'OEM22', 'SPC_DEMO_USER')
   and p.name = 'db_block_size'
   and t.num_rows > 1000
   and nvl(t.empty_blocks,0)/(nvl(t.empty_blocks+t.blocks,0)+1)*100 > 50
 order by 2 desc, 3 desc, 5 desc;
prompt
prompt
prompt


prompt
prompt =======================================================================================
prompt Unused Columns
prompt DO NOT DROP COLUMNS ON ORACLE EBUSINESS SUITE SCHEMAS
PROMPT
prompt Note: Marking a column unused does not remove the data.
prompt 		alter table table_name set unused column column_name;  
prompt	Use of the drop column syntax rewrites the whole table online. 
prompt	Plan to perform this operation during a maintenance weekend
prompt 		alter table table_name drop column column_name;  (SPECIFIC TO ONE COLUMN) 
prompt 	     OR
prompt 		alter table table_name drop unused columns;   	 (ALL)
prompt =======================================================================================
col owner format a10 trunc;
column count       format 9999      heading "Total Unused Columns" 
select owner, table_name, count from dba_unused_col_tabs;
prompt
prompt
prompt


prompt
prompt =======================================================================================
prompt IOT Chained Rows
prompt =======================================================================================
select substr(a.owner||'.'||a.table_name,1,35) "TABLE", to_char(d.pct_threshold,'99999') "% THRESHOLD",
       to_char(d.include_column,'99999') "INCLUDING", a.chain_cnt "CHAINS", a.num_rows "ROWS", 
       to_char(round((a.chain_cnt/a.num_rows)*100,0),'99999') " RATIO",
       decode(a.partitioned,'YES',decode(a.temporary,'Y',decode(a.iot_type,NULL,'PART TEMP ','PART TEMP IOT '),
       decode(a.iot_type,NULL,'PART ','PART IOT ')),decode(a.temporary,'Y',
       decode(a.iot_type,NULL,'TEMP ','TEMP IOT '),decode(a.iot_type,NULL,'','IOT ')))||
       decode(nvl(b.l_cnt,0),0,decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'','XARL'),
       decode(greatest(a.avg_row_len,c.blk_sz),c.blk_sz,'LONG','LONG XARL')) c1
  from dba_tables a,
       (select table_name, sum(decode(data_type,'LONG',1,'LONG RAW',1,0)) l_cnt
          from dba_tab_columns
         where data_type in ('LONG','LONG RAW')
         group by table_name) b,
       (select to_number(value) blk_sz from v$parameter where name = 'db_block_size') c,
       dba_indexes d
 where a.table_name = b.table_name(+)
   and a.owner      = d.owner
   and a.table_name = d.table_name
   and a.owner not in ('SYSTEM','SYS')
   and a.iot_type  is not null
   and round((nvl(a.chain_cnt,0)/decode(a.num_rows,0,1,a.num_rows))*100,0) >= 10
 order by 2 desc;

prompt
prompt LEGEND:
prompt  PART - Partitioned
prompt  TEMP - Temporary
prompt  IOT  - Index Organized Table
prompt  LONG - Long Data Type
prompt  XARL - AVG_ROW_LEN exceeds db block size
prompt
prompt =======================================================================================
prompt Disabled Constraints
prompt =======================================================================================
select substr(owner||'.'||constraint_name,1,40) "CONSTRAINT", 
       decode(constraint_type,'C','CHECK','P','PRIMARY','R','REFERENTIAL','U','UNIQUE',
       'V','VIEW W/CHECK','O','VIEW READ ONLY','UNKNOWN') "TYPE",
       substr(table_name,1,40) "TABLE_NAME"
 from dba_constraints where status ='DISABLED';

prompt
prompt =======================================================================================
prompt Disabled Triggers
prompt =======================================================================================
prompt
prompt NOTE: Confirm with the Developer or Client whether these are appropriately deactivated.
prompt DO NOT ENABLE TRIGGERS unless you've carefully tested their effects.
prompt =======================================================================================
select substr(owner||'.'||trigger_name,1,40) "TRIGGER", substr(trigger_type,1,15) "TYPE",
       substr(table_owner||'.'||table_name,1,40) "TABLE_NAME"
  from dba_triggers where status ='DISABLED';
prompt
prompt =================================================================================================
prompt Obsolete Synonyms
prompt
prompt The following public synonyms refer to an object that no longer exists,
prompt and may be deleted.
prompt =================================================================================================
select synonym_name
from dba_synonyms s, dba_objects o
where s.table_name=object_name (+)
and object_name is null
and s.owner='PUBLIC'
and db_link is null;
prompt
prompt =======================================================================================
prompt Disabled Function-Based Indexes
prompt
prompt Queries on disabled function-based indexes will fail.
prompt 	alter index ... enable;
prompt =======================================================================================
select owner||'.'||index_name from dba_indexes
where funcidx_status !='ENABLED';

prompt
prompt =======================================================================================
prompt Tablespace Fragmentation
prompt
prompt NOTE: Tablespace level fragmentation is only an issue if the number of fragments is in 
prompt the order of magnitude of 1000.  High transaction tablespaces like UNDO and TEMP are OK
prompt to be heavily fragmented.
prompt
prompt However, TEMP can be corrected by making it permanent, coalescing, then returning it 
prompt to a temporary tablespace.  Do not try to defrag the UNDO tablespaces.  Discoverer
prompt tablespaces tend to heavily fragment, especially if there are datamart/datawarehouse 
prompt builds there.  This is best corrected by only annually reviewing the possibility of 
prompt exp/imp the whole schema.
prompt =======================================================================================
set head on
column total_free   format 9999999999 heading 'TOTAL_FREE'
column max_free     format 9999999999
column chunks_free  format 999999999
column sumb         format 999999999
column largest      format 999999999
column bytes        format 999999999
select substr(x.tablespace_name,1,11) "TABLESPACE", sum(x.sumb) total_free, sum(x.largest) max_free, 
       sum(x.chunks) chunks_free
  from (select a.tablespace_name, sum(a.bytes) sumb, max(a.bytes) largest, count(*) chunks
          from dba_free_space a, dba_tablespaces b
         where a.tablespace_name = b.tablespace_name
	 group by a.tablespace_name
        union
       select c.tablespace_name, 0, 0, 0
	 from dba_data_files c, dba_tablespaces d
	where c.tablespace_name = d.tablespace_name
	group by c.tablespace_name) x
  group by x.tablespace_name
 having sum(x.chunks) > 20
  order by 4 desc;



prompt
prompt =======================================================================================
prompt Indexes-by-Schema Information
prompt =======================================================================================
select index_type "INDEX TYPE", substr(tablespace_name,1,11) "TABLESPACE", substr(owner,1,15) "OWNER", 
       decode(partitioned,'YES','YES ','NO  ') "PART", decode(temporary,'Y','YES ','NO  ') "TEMP",
       count(*) "COUNT", sum(decode(greatest(3,decode(blevel,null,0,blevel+1)),3,0,1)) "HEIGHT > 3" 
  from dba_indexes
 group by index_type, tablespace_name, owner, partitioned, temporary
 order by 1,2,3,4,5;

prompt
prompt =========================================================================================================
prompt Index Pending Synchronization
prompt =========================================================================================================

column x1 format a30        heading 'OWNER'
column x2 format a30        heading 'INDEX NAME'
column x3 format 999999999  heading 'FREQUENCY'

break on x1 skip 1

select pnd_index_owner x1, pnd_index_name x2, count(*) x3
  from ctxsys.ctx_pending
 group by pnd_index_owner, pnd_index_name
 order by 1,2;

prompt
prompt =========================================================================================================
prompt User Pending Synchronization
prompt =========================================================================================================

column x1 format a30        heading 'OWNER'
column x2 format 999999999  heading 'FREQUENCY'
column x3 format a15        heading 'TIMESTAMP'

select pnd_index_name x1, to_char(pnd_timestamp,'DD-MON-YY HH24:MI') x3, count(*) x2
  from ctxsys.ctx_user_pending
 group by pnd_index_name, to_char(pnd_timestamp,'DD-MON-YY HH24:MI')
 order by 1,2;

prompt
prompt =========================================================================================================
prompt Miscellaneous Pending Counts
prompt =========================================================================================================
prompt

set serveroutput on;

declare
  pending_count number;
  wait_count    number;
  index_count   number;

begin
  select count(*) into pending_count from ctxsys.dr$pending;
  select count(*) into wait_count    from ctxsys.dr$waiting;
  select count(*) into index_count   from ctxsys.dr$index where idx_opt_count > 1000;

  dbms_output.put_line('DR$PENDING rows  :'||to_char(pending_count,'999999999999'));
  dbms_output.put_line('DR$WAITING rows  :'||to_char(wait_count,'999999999999'));
  dbms_output.put_line('DR$INDEX > 1000  :'||to_char(index_count,'999999999999'));
end;
/
set serveroutput off 


prompt
prompt =======================================================================================
prompt Function-Based Index Column Function Information
prompt =======================================================================================
column column_expression format a30 trunc;
column table_owner format a11 trunc; 
column index_owner format a11 trunc;
set lines 150;
select * from dba_ind_expressions;
prompt
prompt =======================================================================================
prompt Rebuild the following function-based indexes:
prompt 	alter index owner.index_name rebuild online;
select owner, index_name from dba_indexes where index_type like 'FUNCTION%';



prompt
prompt =======================================================================================
prompt Tablespace Pctincrease
prompt =======================================================================================
prompt
prompt ! Locally Managed tablespaces do not benefit from smon autocoalescence via pctincrease.
prompt
prompt NOTE: Change pctincrease to 1 if not already ONLY for Dictionary Managed tablespace. 
prompt This enables the smon process to automatically coalesce the tablespace as needed.
prompt
prompt****NOTE: Do NOT change the pctincrease for the RBS or UNDO tablespaces.
prompt
prompt =======================================================================================
SELECT t.tablespace_name,
       SUM(d.bytes/1048576) ts_size,
       t.initial_extent,
       t.next_extent,
       t.pct_increase,
       t.status, t.extent_management
  FROM dba_tablespaces t, dba_data_files d
 WHERE t.tablespace_name = d.tablespace_name
 GROUP BY t.tablespace_name, 
       t.initial_extent,
       t.next_extent,
       t.pct_increase,
       t.status
 ORDER BY ts_size asc;


PROMPT
prompt =======================================================================================
PROMPT    Temporary Tablespace Defaults
prompt
PROMPT NOTE:The values for Initial/Next are in bytes.  If these are less than 1M, increase 
prompt them to 1M or higher to reduce tablespace fragmentation.
prompt =======================================================================================
      clear breaks
      clear computes
      clear columns
      column init/next format a20
           column pct format 999 heading "Pct|Inc"
      column tablespace_name format a12 heading "Tablespace"

      select  tablespace_name,
              initial_extent||'/'||next_extent "Init/Next",
              pct_increase pct_inc,
              status
      from    sys.dba_tablespaces
      where   tablespace_name in ('TEMP','SYSTEM','USERS');

PROMPT
prompt =======================================================================================
PROMPT    Distinct Percent Increase Value in the Database:
prompt =======================================================================================
select distinct pct_increase from dba_tablespaces;

PROMPT
prompt =======================================================================================
prompt   Tablespaces where the Percent Increase is ZERO, if any.
PROMPT NOTE: If the TEMP tablespace is locally-managed (in the case, usually, for Oracle 9i), 
PROMPT it is important to leave its pctincrease at zero.
PROMPT
PROMPT   If there are any set to Zero and modifiable, therefore they are not Locally 
prompt Managed and not the RBS or UNDO tablespace, then use this syntax to alter the 
prompt tablespace to set the pctincrease value to one:
PROMPT     alter tablespace POD default storage (pctincrease 1);
prompt =======================================================================================
select tablespace_name from dba_tablespaces where pct_increase =0;

prompt
prompt =======================================================================================
prompt Log Buffer Tuning
prompt =======================================================================================
prompt The following output assists you with tuning the LOG_BUFFER. The size of the
prompt log buffer is set by assigning a value to the INIT.ora parameter LOG_BUFFER.
prompt 
prompt All changes are written to your redo logs via the log buffer. If your log 
prompt buffer is too small it can cause excessive disk I/Os on the disks that 
prompt contain your redo logs. The problem can be made worse if you have archiving
prompt turned on because as well as writing to the redo logs, Oracle has to also 
prompt read from the redo logs and copy the file to the archive logs. To overcome 
prompt this problem, I suggest that you have 4 redo logs, typically 5 Meg or larger
prompt in size  and alternate the redo logs from one disk to another, that  is
prompt redo log 1 is on disk 1 , redo log 2 is on disk 2, redo log 3 is on disk 1
prompt and redo log 4 is on disk 2.
prompt 
prompt This will ensure that the previous log being archived will be on a different
prompt disk to the redo log being written to.
prompt 
prompt The following statistics also indicate inefficiencies with the log buffer
prompt being too small. Typically a large site will have the LOG_BUFFER 500k or
prompt larger.
prompt 
prompt The "redo log space wait time" indicates that the user process had to wait to 
prompt get space in the redo file. This indicates that the current log buffer was
prompt being written from and the process would have to wait. Enlarging the log 
prompt buffer usually overcomes this problem. The closer the value is to zero, the
prompt better your log buffer is tuned.
prompt 
prompt The "redo log space request" indicates the number of times a user process has
prompt to wait for space in redo log buffer. It is often caused by the archiver being 
prompt lazy and the log writer can't write from the log buffer to the redo log 
prompt because the redo log has not been copied by the ARCH process. One possible
prompt cause of this problem is where Hot Backups are taking place on files that are
prompt being written to heavily. Note: for the duration of the hot backups, an 
prompt entire block is written out to the log buffer and the redo logs for each
prompt change to the database, as compared to just the  writing the characters that
prompt have been modified.
prompt 
prompt There is a parameter _LOG_BLOCKS_DURING_BACKUP which is supposed to overcome
prompt the Hot backup problem. It will pay to check if the parameter is functional
prompt for your version of the RDBMS with Oracle. It can avoid severe bottlenecks.
prompt 
prompt A sensible approach for overnight processing is to time your Hot Backups, if
prompt they are really required, (a lot of sites have them just for the sake of saying
prompt that they are running them) to occur when the datafiles being backed up have
prompt very little or preferably NO activity occurring against them.
prompt 
prompt The "redo buffer allocation retries" are where the redo writer is waiting for 
prompt the log writer to complete the clearing out of all of the dirty buffers from 
prompt the buffer cache. Only then, can the redo writer continue onto the next
prompt redo log. This problem is usually caused by having the LOG_BUFFER parameter
prompt too small, but can also be caused by having the buffer cache too small (see
prompt the DB_BLOCK_BUFFERS parameter).
prompt 
prompt Extra LOG_BUFFER and Redo Log Tuning Information 

select  substr(name, 1,25) , value 
  from v$sysstat
 where  name like 'redo%'                     
   and  value > 0;

prompt
prompt =======================================================================================
prompt Redo Log Switching
prompt =======================================================================================
alter session set nls_date_format = 'DD.MM.YYYY:HH24:MI';
prompt
Prompt Redolog File Status from V$LOG' 
prompt =======================================================================================
select group#, sequence#,Members, archived, status, first_time from v$log;
prompt
prompt Number of Logswitches per Hour:
prompt =======================================================================================
select substr(completion_time,1,5) day,
       to_char(sum(decode(substr(completion_time,12,2),'00',1,0)),'99') "00",
       to_char(sum(decode(substr(completion_time,12,2),'01',1,0)),'99') "01",
       to_char(sum(decode(substr(completion_time,12,2),'02',1,0)),'99') "02",
       to_char(sum(decode(substr(completion_time,12,2),'03',1,0)),'99') "03",
       to_char(sum(decode(substr(completion_time,12,2),'04',1,0)),'99') "04",
       to_char(sum(decode(substr(completion_time,12,2),'05',1,0)),'99') "05",
       to_char(sum(decode(substr(completion_time,12,2),'06',1,0)),'99') "06",
       to_char(sum(decode(substr(completion_time,12,2),'07',1,0)),'99') "07",
       to_char(sum(decode(substr(completion_time,12,2),'08',1,0)),'99') "08",
       to_char(sum(decode(substr(completion_time,12,2),'09',1,0)),'99') "09",
       to_char(sum(decode(substr(completion_time,12,2),'10',1,0)),'99') "10",
       to_char(sum(decode(substr(completion_time,12,2),'11',1,0)),'99') "11",
       to_char(sum(decode(substr(completion_time,12,2),'12',1,0)),'99') "12",
       to_char(sum(decode(substr(completion_time,12,2),'13',1,0)),'99') "13",
       to_char(sum(decode(substr(completion_time,12,2),'14',1,0)),'99') "14",
       to_char(sum(decode(substr(completion_time,12,2),'15',1,0)),'99') "15",
       to_char(sum(decode(substr(completion_time,12,2),'16',1,0)),'99') "16",
       to_char(sum(decode(substr(completion_time,12,2),'17',1,0)),'99') "17",
       to_char(sum(decode(substr(completion_time,12,2),'18',1,0)),'99') "18",
       to_char(sum(decode(substr(completion_time,12,2),'19',1,0)),'99') "19",
       to_char(sum(decode(substr(completion_time,12,2),'20',1,0)),'99') "20",
       to_char(sum(decode(substr(completion_time,12,2),'21',1,0)),'99') "21",
       to_char(sum(decode(substr(completion_time,12,2),'22',1,0)),'99') "22",
       to_char(sum(decode(substr(completion_time,12,2),'23',1,0)),'99') "23"
  from V$ARCHIVED_LOG
 group by substr(completion_time,1,5);
prompt
Prompt Redolog Switches Graphically Over the Last Day
set linesize 380;

column chng_no heading '# OF LOG|CHANGES' format a10;
column TIME format a30;
column graph heading 'Number of Log Switches'
column graph format a25
set serveroutput on size 1000000 format wrapped;
DECLARE
v_log_disp number(6);
v_logc NUMBER(6);
v_logs NUMBER(6);
v_count INTEGER :=1;
v_lower_date DATE;
v_upper_date DATE;
BEGIN
-- Determine Number of hours
SELECT
(ROUND(SYSDATE,'HH24')-(TRUNC(SYSDATE)-1))*24,ROUND(TRUNC(SYSDATE-1))
INTO v_logc,v_lower_date
from dual;
v_lower_date := trunc(v_lower_date);
DBMS_OUTPUT.PUT_LINE(LPAD(' ',27)||'Log');
DBMS_OUTPUT.PUT_LINE(LPAD(' ',27)||'Switch');
DBMS_OUTPUT.PUT_LINE('Hourly Time Range          Count| Graph');
DBMS_OUTPUT.PUT_LINE('--------------------------------------->');
WHILE (v_count < v_logc) LOOP
v_upper_date := v_lower_date+1/24;
SELECT COUNT(sequence#)
INTO v_logs
FROM v$log_history
WHERE ROUND(first_time,'HH24') BETWEEN v_lower_date AND v_upper_date;

-- DBMS_OUTPUT.PUT_LINE(to_char(v_logs,'999'));
if v_logs > 50 then
  v_log_disp := 50;
else
  v_log_disp := v_logs;
end if;


DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_lower_date,'MON-DD HH12 AM')||' -
'||TO_CHAR(v_upper_date,'MON-DD HH12 AM')||TO_CHAR(v_logs,'999')||' |'||LPAD('x',v_log_disp,'.'));

v_count := v_count + 1;
v_lower_date := v_lower_date+1/24;
END LOOP;
END;
/

prompt
prompt =======================================================================================
prompt =======================================================================================
prompt Recommended System Changes
prompt =======================================================================================
prompt =======================================================================================
prompt

prompt Change non-LMT, non-SYSTEM tablespaces to LMT:
prompt It is highly recommended to migrate all of the following tablespace to LMT using the
prompt following syntax:
prompt	execute sys.DBMS_SPACE_ADMIN.TABLESPACE_MIGRATE_TO_LOCAL('~~~'); 
prompt Note: For TEMP, you will have to create a meta temp tablespace.  See notes for this.
select tablespace_name, extent_management from dba_tablespaces where extent_management !='LOCAL';



prompt
prompt =======================================================================================
prompt Table Pctincrease Change
prompt The following SQL commands must be run to change the default pctincrease value for all
prompt non-SYS/SYSTEM tables to zero.  This limits unnecessary object-level extent size growth,
prompt while making allocated extents generally more usable by not allowing them to create in
prompt odd sizes that do not coalesce well.
prompt =======================================================================================
set echo off
set feedback on
set head on
select 'alter table '||owner||'.'|| table_name||' storage (pctincrease 0);'
from dba_tables
where pct_increase !=0 and owner not in ('SYS','SYSTEM') and table_name not like 'SYS_%';;

prompt
prompt =======================================================================================
prompt Index Pctincrease Change
prompt The following SQL commands must be run to change the default pctincrease value for all
prompt non-SYS/SYSTEM indexes to zero.  This limits unnecessary object-level extent size
prompt growth, while making allocated extents generally more usable by not allowing them to
prompt create in odd sizes that do not coalesce well.
prompt =======================================================================================
set echo off
set feedback on
set head on
select 'alter index '||owner||'.'|| index_name||' storage (pctincrease 0);'
from dba_indexes
where pct_increase !=0 and owner not in ('SYS','SYSTEM') and index_name not like 'SYS_%';;


prompt
prompt =======================================================================================
prompt Table Freelists Change
prompt The following SQL commands must be run to increase Freelists to 4 for all tables with
prompt less than this value.  Increasing Freelists uses a bit more space, but for an OLTP
prompt environment, will decrease db block buffer cache waits.
prompt =======================================================================================
set echo off
set feedback on
set head on
SELECT 'alter table '||owner||'.'||table_name||' storage (freelists 4);'
FROM  dba_tables
where owner not in ('SYS','SYSTEM') and table_name not like 'SYS_%';
and freelists<4;

prompt
prompt =======================================================================================
prompt Index Freelists Change
prompt The following SQL commands must be run to increase Freelists to 4 for all indexs with
prompt less than this value.  Increasing Freelists uses a bit more space, but for an OLTP
prompt environment, will decrease db block buffer cache waits.
prompt =======================================================================================
set echo off
set feedback on
set head on
SELECT 'alter index '||owner||'.'||index_name||' storage (freelists 4);'
FROM  dba_indexes
where owner not in ('SYS','SYSTEM') and index_name not like 'SYS_%';
and freelists<4;


prompt
prompt =======================================================================================
prompt The following SQL commands must be run to cache sequences.  Forcing the database to 
prompt cache more sequences makes it call for them less frequently.
prompt
prompt Even though you could risk losing sequence numbers, sequences can always be reset.
prompt =======================================================================================
select 'alter sequence '||sequence_owner||'.'||sequence_name||' cache 30;' from dba_sequences 
where sequence_owner not in ('SYS','SYSTEM')
and cache_size<20;


prompt
prompt =======================================================================================
prompt The following SQL commands must be run to redefine sequences to allow them to be 
prompt created in no order.  Make sure that your sequences do not have an ORDER clause unless 
prompt they are using Oracle parallel server.  Forcing the database to create sequences is 
prompt order takes excess overhead.
prompt =======================================================================================
select 'alter sequence '||sequence_owner||'.'||sequence_name||' noorder;' from dba_sequences 
where  sequence_owner not in ('SYS','SYSTEM')
and order_flag='Y';


prompt
prompt =======================================================================================
prompt The following SQL commands must be run to coalesce free extents in current indexes.
prompt =======================================================================================
select 'alter index '||owner||'.'|| index_name||' coalesce;'
from dba_indexes
where owner not in ('SYS','SYSTEM');

prompt
prompt =======================================================================================
prompt List of Analyzed Tables with Unanalyzed Indexes:
prompt 
prompt This script will return tables with indexes that are not analyzed.    
prompt You must then manually analyze all indexes on these tables.
prompt
prompt !Analyze all indexes on these tables!
prompt
prompt Sometimes indexes are re-built for performance and maintenance reasons, but the 
prompt associated table/index is not re-ANALYZED, which can cause servere performance problems.
prompt =======================================================================================
set head on
select 'Index '||i.index_name||' not analyzed but table '||
       i.table_name||' is.'
  from dba_tables t, dba_indexes i
 where t.table_name    =      i.table_name
   and t.num_rows      is not null
   and i.distinct_keys is     null;

prompt
prompt =======================================================================================
prompt This Query returns the name of all non-system tables in the Data Dictionary.
prompt
prompt NOTE: Some objects that are fetched back by this query are in fact system objects...
prompt 	 be VERY careful how you proceed moving or deleting objects in the SYSTEM 
prompt       tablespace (Data Dictionary).
prompt
prompt POTENTIAL BENEFIT: It is a good idea to move these out of the Data Dictionary because 
prompt they can degrade performance.
prompt =======================================================================================
select tname from tab where tname not in 
(select tname from tab where tname like 'DBA%' union 
select tname from tab where tname like 'ALL%' union 
select tname from tab where tname like 'USER%' union 
select tname from tab where tname like '%$' union 
select tname from tab where tname like 'V_$%');

prompt
prompt =======================================================================================
prompt Delete stats on SYS and SYSTEM objects because these can impare the optimizer.
SELECT 'analyze table '||owner||'.'||table_name||' delete statistics;'
  FROM  dba_tables
       WHERE owner in ('SYS','SYSTEM') and last_analyzed is not null and table_name !='DUAL';
spool off
alter database backup controlfile to trace noresetlogs;
alter system switch logfile;
PROMPT
prompt
prompt =======================================================================================
PROMPT Current DB Recylce Contents
prompt =======================================================================================
SELECT object_name,original_name,droptime,dropscn
FROM recyclebin;