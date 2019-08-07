

SET TERMOUT OFF

SPOOL &spool_dir.&instance_name._asm.txt

SELECT group_number, name, sector_size, block_size, allocation_unit_size, state, type, total_mb, free_mb
  FROM v$asm_diskgroup
/

SELECT group_number, disk_number, mount_status, header_status, mode_status, state, redundancy, total_mb, free_mb, name,
       repair_timer, read_errs, write_errs, read_time, write_time, bytes_read, bytes_written
  FROM v$asm_disk
/

spool off



