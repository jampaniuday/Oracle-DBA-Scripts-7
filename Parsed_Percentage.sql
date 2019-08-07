/* Formatted on 4/27/2010 3:06:44 PM (QP5 v5.139.911.3011) */
--Parsed Percentage

  SELECT NVL ( (SELECT username
                  FROM all_users
                 WHERE user_id = parsing_schema_id),
              '(Totals)')
            parsing_schema,
         SUM (disk_reads) "PIO",
         SUM (buffer_gets) "LIO",
         SUM (parse_calls) "Parse",
         SUM (executions) "Execute",
         ROUND (200 * ratio_to_report (SUM (executions)) OVER ()) "%exe",
         ROUND (SUM (parse_calls) / SUM (executions) * 100) "%Parsed",
         SUM (fetches) "KFetch",
         SUM (rows_processed) "Rows"
    FROM (SELECT gv_sql.inst_id,
                 gv_sql.disk_reads,
                 gv_sql.buffer_gets,
                 gv_sql.parse_calls,
                 gv_sql.executions,
                 gv_sql.fetches,
                 gv_sql.rows_processed,
                 gv_sql.parsing_schema_id
            FROM sys.gv_$sqlarea gv_sql--where command_type in (2,3,6,7,47)
         ) gv_sqlarea
GROUP BY CUBE (parsing_schema_id)
ORDER BY "Execute" DESC;