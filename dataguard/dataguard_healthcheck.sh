#!/bin/ksh
###        NAME
###       check_dataguard.sh v1.0
###
###    DESCRIPTION
###       Checks the physical standby database and the dgbroker configuration.
###
###    RETURNS
###      0 - OK
###      1 - Incorrect
###    NOTES
###
###    MODIFIED           (DD/MM/YY)
###       Oracle           10/11/2010     - Creation
###

V_DATE=`/bin/date +%Y%m%d_%H%M%S`
if [ "${1}" != 'no_trace' ]; then
  V_FICH_LOG=`dirname $0`/logs/`basename $0`.${V_DATE}.log
  exec 4>&1
  tee ${V_FICH_LOG} >&4 |&
  exec 1>&p 2>&1
fi

V_ADMIN_DIR=`dirname $0`
. ${V_ADMIN_DIR}/setenv_instance.sh --- This script set the env. vars. for the primary database like $OH, $ORACLE_SID, $PATH
if [ $? -ne 0 ]
then
  echo "Error loading the environment"
  exit 1
fi
V_DB_PWD=<SYS_PASSWORD>
V_DB_SID_RMT=<TNS_ENTRY_OF_THE_PHYSICAL_STANDBY_SITE>
V_RET=0
V_SLEEP=90
V_LOOP=20
V_TRAZAS=${V_ADMIN_DIR}/logs
V_TMP_OUT1=${V_TRAZAS}/_tmp_out1.lst
V_TMP_OUT2=${V_TRAZAS}/_tmp_out2.lst
V_TMP_OUT3=${V_TRAZAS}/_tmp_out3.lst
> $V_TMP_OUT1
> $V_TMP_OUT2
> $V_TMP_OUT3

sqlplus -s /nolog <<EOF
  connect / as sysdba
  set pages 0
  set lines 100
  set feedback off
  spool ${V_TMP_OUT1}
  select value from v\$parameter
   where name = 'user_dump_dest';
EOF

cat ${V_TMP_OUT1} | read V_LOG_DEST

echo "LOG_DEST: $V_LOG_DEST"
echo "***********************"
echo "Starting process  `date` "
echo "***********************"
echo "LOOPS (V_LOOP) : $V_LOOP" >>${V_FICH_LOG}
echo "Wait time  (V_SLEEP): $V_SLEEP" >>${V_FICH_LOG}

sqlplus -s /nolog <<EOF
   connect / as sysdba
   set pages 0
   set lines 100
   set feedback off
   spool ${V_TMP_OUT2}
   select max(sequence#) from v\$archived_log
    where resetlogs_change# = (select resetlogs_change# from v\$database);
EOF

cat ${V_TMP_OUT2} | read V_PRIMER_LOG

echo "FIRST LOG: $V_PRIMER_LOG"

sqlplus -s /nolog <<EOF
  connect / as sysdba
  alter system switch logfile;
  alter system switch logfile;
  alter system switch logfile;
EOF
ok_flag=0
i=0
while [ $i -le $V_LOOP ] && [ $ok_flag -eq 0 ]
do
   echo "Bucle: $i (`date`)"

   sqlplus -s /nolog <<EOF
    connect ${V_DB_USR}/${V_DB_PWD}@${V_DB_SID_RMT} as sysdba
    set pages 0
    set lines 100
    set feedback off
    spool ${V_TMP_OUT3}
    select max(sequence#) from v\$archived_log where applied <> 'NO' and
    resetlogs_change# = (select resetlogs_change# from v\$database);
EOF
   cat ${V_TMP_OUT3} | read V_SIGUIENTE_LOG

   echo $V_SIGUIENTE_LOG >>${V_FICH_LOG}

   if [ $V_SIGUIENTE_LOG -gt $V_PRIMER_LOG ]
   then
      echo "*****************************"
      echo "Archive redo log successfully applied: "
      echo "Ending process: `date`"
      echo "*****************************"
   fi
   ok_flag=1
   sleep $V_SLEEP
   i=`expr $i + 1`
done

if [ $ok_flag -eq 0 ]
then
echo "**************************************"
echo "CRITICAL:  Could not apply redo information"
echo "**************************************"
exit 1
fi
echo "** Checking the Data Guard Broker status ...."
dgmgrl <<-! | grep SUCCESS
    connect /
    show configuration verbose;
!
  if [ $? -ne 0 ] ; then
    echo "\n\n ERROR: The Data Guard Broker status is not SUCCESS\n"
    V_RET=1
  fi

  V_DATE=`/bin/date +%Y%m%d_%H%M%S`

  if [ ${V_RET} -ne 0 ]
  then
    echo
    echo "${V_DATE} - CRITICAL: The Data Guard Broker configuration is not correct."
    echo "####################################################################"
    echo
  else
    echo
    echo "${V_DATE} - Data Guard Broker seems to be ok."
    echo "####################################################################"
    echo
  fi
exit 0