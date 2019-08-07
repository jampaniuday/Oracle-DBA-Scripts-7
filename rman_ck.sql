-- script will report on all backups - full, incremental and archivelog
col status format a9
col hrs format 999.99
select session_key, input_type, status,
to_char(start_time,'mm/dd/yy hh24:mi') start_time,
to_char(end_time,'mm/dd/yy hh24:mi') end_time,
elapsed_seconds/3600 hrs
from v$rman_backup_job_details
order by session_key ; 
