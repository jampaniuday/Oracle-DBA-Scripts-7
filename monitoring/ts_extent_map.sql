-- -----------------------------------------------------------------------------------
-- File Name    : http://www.oracle-base.com/dba/monitoring/ts_extent_map.sql
-- Author       : DR Timothy S Hall
-- Description  : Displays extents and their locations within the tablespace allowing identification of tablespace fragmentation.
-- Requirements : Access to the DBA views.
-- Call Syntax  : @ts_extent_map (tablespace-name)
-- Last Modified: 25/01/2003
-- -----------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE 1000000
SET FEEDBACK OFF
SET TRIMOUT ON
SET VERIFY OFF

DECLARE
  CURSOR c_extents IS
    SELECT owner,
           segment_name,
           block_id AS start_block,
           block_id + blocks - 1 AS end_block
    FROM   dba_extents
    WHERE  tablespace_name = Upper('&1')
    ORDER BY block_id;
    
  v_last_block_id NUMBER := 0;
BEGIN
  FOR cur_rec IN c_extents LOOP
    IF cur_rec.start_block > v_last_block_id + 1 THEN
      DBMS_OUTPUT.PUT_LINE('*** GAP ***');
    END IF;
    v_last_block_id := cur_rec.end_block;
    DBMS_OUTPUT.PUT_LINE(RPAD(cur_rec.owner || '.' || cur_rec.segment_name, 40, ' ') || 
                         ' (' || cur_rec.start_block || ' -> ' || cur_rec.end_block || ')');
  END LOOP;
END;
/

PROMPT
SET FEEDBACK ON
SET PAGESIZE 18


