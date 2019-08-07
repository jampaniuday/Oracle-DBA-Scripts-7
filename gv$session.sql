/* Formatted on 4/29/2010 10:42:35 AM (QP5 v5.139.911.3011) */
--gv$session

WITH slo AS (SELECT inst_id,
                    sid,
                    serial#,
                    target,
                    opname,
                    time_remaining
               FROM gv$session_longops sl
              WHERE time_remaining > 0)
  SELECT    TO_CHAR (FLOOR (s.last_call_et / 3600), 'fm9900')
         || ':'
         || TO_CHAR (FLOOR (MOD (s.last_call_et, 3600) / 60), 'fm00')
         || ':'
         || TO_CHAR (MOD (MOD (s.last_call_et, 3600), 60), 'fm00')
            "Idle",
            TO_CHAR (FLOOR (s.seconds_in_wait / 3600), 'fm9000')
         || ':'
         || TO_CHAR (FLOOR (MOD (s.seconds_in_wait, 3600) / 60), 'fm00')
         || ':'
         || TO_CHAR (MOD (MOD (s.seconds_in_wait, 3600), 60), 'fm00')
            "Wait",
         s.inst_id || ' ' || RPAD (SUBSTR (s.username, 1, 8), 8) "Inst/User",
         SUBSTR (
            CASE
               WHEN SUBSTR (s.program, -1) = ')'
               THEN
                  CASE
                     WHEN SUBSTR (s.program, -6, 1) = '('
                     THEN
                        SUBSTR (s.program, -6)
                     ELSE
                        SUBSTR (s.program, 1, 7)
                  END
               ELSE
                  NVL (SUBSTR (s.program, INSTR (s.program, '/', -1) + 1),
                       SUBSTR (s.module, INSTR (s.module, '/', -1) + 1, 15))
            END,
            1,
            16)
            "program/mod",
         SUBSTR (s.event, 1, 31) event,
         CASE
            WHEN s.wait_time = 0
            THEN
               s.state
            WHEN s.wait_time < 0
            THEN
               CASE WHEN s.command = 0 THEN 'WAITING' ELSE 'On CPU ' END
            WHEN s.wait_time > 0
            THEN
               CASE
                  WHEN s.status = 'INACTIVE' THEN 'WAITING'
                  ELSE 'On CPU '
               END
         --||to_char(s.seconds_in_wait-(s.wait_time/100),'fm90.00')
         END
            AS state--,s.state, s.wait_time, s.command--, s.seconds_in_wait
         ,
         s.status,
         q.disk_reads pio,
         q.buffer_gets lio,
         q.parse_calls prs,
         q.executions exe,
         ROUND (q.buffer_gets / GREATEST (q.executions, 1)) "lio/ex",
         CASE
            WHEN q.command_type = 3
            THEN
               CASE
                  WHEN q.fetches > 0 THEN ROUND (q.rows_processed / q.fetches)
               END
            ELSE
               CASE
                  WHEN q.executions > 0
                  THEN
                     ROUND (q.rows_processed / q.executions)
               END
         END
            "array",
         ROUND (p.pga_alloc_mem / 1024 / 1024) "pga"--,    s.p3
                                                    --,    decode(s.sql_trace,'ENABLED','Y','') tr
         ,
         q.rows_processed "rows"--,    ss.value  commits
         ,
         CASE
            WHEN (SYSDATE - s.logon_time) > 0
            THEN
               TO_CHAR (ss.VALUE / ( (SYSDATE - s.logon_time) * 86400),
                        'fm9990')
         END
            "tps",
         s.sid
         || NVL2 (blocking_session,
                  '/' || blocking_instance || '-' || blocking_session,
                  NULL)
            "Sid(/bl)",
         CASE
            WHEN sl.opname IS NOT NULL
            THEN
               sl.opname || ': ' || sl.time_remaining
            ELSE
               ' '
         END
            AS opname,
         q.sql_text,
         q.hash_value,
         q.sql_id,
         sl.target,
         DECODE (aa.name, 'UNKNOWN', '', LOWER (aa.name)) cmd,
         s.*,
            'alter system kill session '''
         || s.sid
         || ','
         || s.serial#
         || ''' immediate;'
            AS kill_session,
            'sys.dbms_system.set_ev('
         || s.sid
         || ','
         || s.serial#
         || ',10046,12,'''');'
            AS trace_session,
            'dbms_monitor.session_trace_enable('
         || s.sid
         || ','
         || s.serial#
         || ',true,false);',
            'dbms_monitor.session_trace_disable('
         || s.sid
         || ','
         || s.serial#
         || ');',
         p.pid,
         p.spid "OS pid",
         p.pga_used_mem,
         p.pga_alloc_mem,
         CASE
            WHEN s.p2text = 'object #'
            THEN
               (SELECT object_name
                  FROM dba_objects
                 WHERE object_id = s.p2)
         END
            AS object_name
    FROM gv$process p,
         gv$session s,
         gv$sql q,
         slo sl,
         audit_actions aa,
         gv$sesstat ss
   WHERE q.sql_id(+) = DECODE (s.sql_id, NULL, s.prev_sql_id, s.sql_id)
         AND q.child_number(+) =
                DECODE (s.sql_id,
                        NULL, s.prev_child_number,
                        s.sql_child_number)
         AND q.inst_id(+) = s.inst_id
         AND s.paddr = p.addr(+)
         AND s.inst_id = p.inst_id(+)
         AND sl.sid(+) = s.sid
         AND sl.serial#(+) = s.serial#
         AND sl.inst_id(+) = s.inst_id
         AND s.command = aa.action
         AND ss.sid = s.sid
         AND ss.inst_id = s.inst_id
         AND ss.statistic# = 4 -- (select sn.statistic# from v$statname sn where sn.name = 'user commits')
--and s.username     = 'HJS'
--and osuser         = 'llng'
--and s.sid         in (2141)
--and event  not in ('SQL*Net message from client','rdbms ipc message')
--and s.status       = 'ACTIVE'
--and client_info like '%PSQRYSRV%'
--and s.program     in ('ldc.exe','crystalras.exe')
--and s.module       = 'MSGMGR.EXE'
--and service_name   = 'SYS$BACKGROUND'
ORDER BY blocking_session,
         DECODE (s.username, NULL, 99, 0),
         6,
         s.status,
         DECODE (s.status, 'ACTIVE', s.last_call_et, s.last_call_et * -1) DESC,
         s.username,
         s.sid;