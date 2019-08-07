/* Formatted on 4/27/2010 1:33:13 PM (QP5 v5.139.911.3011) */
-- High LIO
-- Scott Washburn
-- April 30, 2010


WITH inst
        AS (SELECT (SYSDATE - startup_time) * 24 * 60 * 60 AS secs_running
              FROM v$instance)
  SELECT sql_id "sql_id",
         gv_sqlarea.inst_id "Inst",
         disk_reads "pio",
         buffer_gets "lio",
         parse_calls "parse",
         executions "execute",
         fetches "fetch",
         rows_processed "rows",
         ROUND (executions / secs_running, 2) "ex/sec",
         ROUND (executions / (secs_running / 3600)) "ex/hr",
         ROUND (buffer_gets / GREATEST (executions, 1)) "lio/ex",
         TO_CHAR (percent_lio, '00.00') "%lio",
         CASE
            WHEN command_type = 3
            THEN
               CASE
                  WHEN fetches > 0 THEN ROUND (rows_processed / fetches, 2)
               END
            ELSE
               CASE
                  WHEN executions > 0
                  THEN
                     ROUND (rows_processed / executions, 2)
               END
         END
            "rows/ex",
         sql_text "sql_text",
            TO_CHAR (FLOOR ( (cpu_time / 1000000) / 3600), 'fm9900')
         || ':'
         || TO_CHAR (FLOOR (MOD ( (cpu_time / 1000000), 3600) / 60), 'fm00')
         || ':'
         || TO_CHAR (TRUNC (MOD (MOD ( (cpu_time / 1000000), 3600), 60), 2),
                     'fm00.00')
            "cpu",
         TO_CHAR (FLOOR ( (elapsed_time / 1000000) / 3600), 'fm9900') || ':'
         || TO_CHAR (FLOOR (MOD ( (elapsed_time / 1000000), 3600) / 60),
                     'fm00')
         || ':'
         || TO_CHAR (
               TRUNC (MOD (MOD ( (elapsed_time / 1000000), 3600), 60), 2),
               'fm00.00')
            "elapsed",
         TO_CHAR (
            FLOOR (
               ( (elapsed_time
                  / CASE WHEN executions > 0 THEN executions ELSE 1 END)
                / 1000000)
               / 3600),
            'fm9900')
         || ':'
         || TO_CHAR (
               FLOOR (
                  MOD (
                     ( (elapsed_time
                        / CASE WHEN executions > 0 THEN executions ELSE 1 END)
                      / 1000000),
                     3600)
                  / 60),
               'fm00')
         || ':'
         || TO_CHAR (
               FLOOR (
                  MOD (
                     MOD (
                        ( (elapsed_time
                           / CASE
                                WHEN executions > 0 THEN executions
                                ELSE 1
                             END)
                         / 1000000),
                        3600),
                     60)),
               'fm00')
         || '.'
         || TO_CHAR (
               ROUND (
                  MOD (
                     (elapsed_time
                      / CASE WHEN executions > 0 THEN executions ELSE 1 END),
                     1000000)
                  / 1000000,
                  3)
               * 1000,
               'fm000')
            "Elapsed/exec",
            TO_CHAR (FLOOR (inst.secs_running / 3600), 'fm9900')
         || ':'
         || TO_CHAR (FLOOR (MOD (inst.secs_running, 3600) / 60), 'fm00')
         || ':'
         || TO_CHAR (MOD (MOD (inst.secs_running, 3600), 60), 'fm00')
            "db uptime",
         users_executing "users_executing",
         version_count "version_count",
         TO_CHAR (FLOOR ( (cluster_wait_time / 1000000) / 3600), 'fm9900')
         || ':'
         || TO_CHAR (FLOOR (MOD ( (cluster_wait_time / 1000000), 3600) / 60),
                     'fm00')
         || ':'
         || TO_CHAR (
               TRUNC (MOD (MOD ( (cluster_wait_time / 1000000), 3600), 60), 2),
               'fm00.00')
            "cluster_wait_time",
         TO_CHAR (FLOOR ( (user_io_wait_time / 1000000) / 3600), 'fm9900')
         || ':'
         || TO_CHAR (FLOOR (MOD ( (user_io_wait_time / 1000000), 3600) / 60),
                     'fm00')
         || ':'
         || TO_CHAR (
               TRUNC (MOD (MOD ( (user_io_wait_time / 1000000), 3600), 60), 2),
               'fm00.00')
            "user_io_wait_time",
         CASE
            WHEN elapsed_time > 0
            THEN
               ROUND ( (user_io_wait_time / elapsed_time) * 100, 2)
         END
            "user_io_wt/elapsed",
         hash_value "hash",
         module,
         action,
         program_id,
         (SELECT username
            FROM all_users
           WHERE user_id = parsing_schema_id)
            parsing_schema
    FROM (SELECT gv_sql.sql_id,
                 gv_sql.inst_id,
                 gv_sql.disk_reads,
                 gv_sql.buffer_gets,
                 gv_sql.parse_calls,
                 gv_sql.executions,
                 gv_sql.fetches,
                 gv_sql.rows_processed,
                 TO_CHAR (
                    ROUND (100 * ratio_to_report (gv_sql.buffer_gets) OVER (),
                           2),
                    'fm90.00')
                    AS percent_lio,
                 gv_sql.sql_text,
                 gv_sql.cpu_time,
                 gv_sql.elapsed_time,
                 gv_sql.users_executing,
                 gv_sql.version_count,
                 gv_sql.cluster_wait_time,
                 gv_sql.user_io_wait_time,
                 gv_sql.hash_value,
                 gv_sql.command_type,
                 gv_sql.module,
                 gv_sql.action,
                 gv_sql.program_id,
                 gv_sql.parsing_schema_id
            FROM sys.gv_$sqlarea gv_sql
           WHERE command_type IN (2, 3, 6, 7) AND buffer_gets > 1000--and sql_text not like '%SELECT%FROM TABLE%'
         ) gv_sqlarea,
         inst
   WHERE percent_lio >= 0.5
ORDER BY 4 DESC                      -- 4 = lio, 9 = execs/sec, 10 = gets/exec
;