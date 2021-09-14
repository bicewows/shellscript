#!/bin/bash
anynowtime="date +'%Y-%m-%d %H:%M:%S'"
NOW="echo [\`$anynowtime\`]"

function recho() {
    msg=$*
    echo "$(eval "$NOW") $msg"
}
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/db
function get_ctlfile_backup(){
    "$ORACLE_HOME"/bin/sqlplus -S cxh/123456@192.168.20.131:1521/orcl <<EOF
set linesize 200
set heading off
set pagesize 0
set trimspool on
set trimout on
set termout off
select sysdate from dual;
exit;
EOF
}

function main () {
    for((i=0;i<100;i++)); do
        recho "conn $i times"
        get_ctlfile_backup
    done
    
}

main
