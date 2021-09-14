#!/bin/bash
# 运行此shell需要提前编辑2个txt配置文件

# 一、设置清理碎片表的列表，通过编辑tab_conf.txt 格式如下
# [oracle@zstest tablefrag]$ cat tab_conf.txt 
# 1,MYTHREE,T_3
# 2,MYTHREE,T_OBJECTS
# 3,MYTHREE,T_BAK
# 4,MYTHREE,T
# 二、设置脚本启动标志，可以停止脚本，通过编辑tab_clean_flag.txt，
# flag=continue 继续运行
# flag=stop 停止运行
# [oracle@zstest tablefrag]$ cat tab_clean_flag.txt
# flag=stop
  
pwd_script=$(
    cd "$(dirname "$0")" || exit
    pwd
)
anynowtime="date +'%Y-%m-%d %H:%M:%S'"
NOW="echo [\`$anynowtime\`]"
sqlresult="$pwd_script"/sqlresult.log
cleanlog="$pwd_script"/clean.log
tab_conf="$pwd_script"/tab_conf.txt
tab_clean_flag="$pwd_script"/tab_clean_flag.txt

clean_table_total=88
clean_table_owner=
clean_table_name=
clean_table_id=

clean_before_time=
clean_before_formattime=
clean_before_num_rows=
clean_before_blocks=
clean_before_row_movement=
clean_before_tab_size=
clean_before_objects_invalid=

clean_after_time=
clean_after_formattime=
clean_after_num_rows=
clean_after_blocks=
clean_after_row_movement=
clean_after_tab_size=
clean_after_objects_invalid=

export ORACLE_SID=three
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/db
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
function recho() {
    msg=$*
    echo "$(eval "$NOW") $msg"
}
function recho_thickened() {
    msg=$*
    echo -e "$(eval "$NOW") \033[033;1m$msg\033[0m"
}
function get_db_info() {
    v_owner=$1
    v_table_name=$2
    "$ORACLE_HOME"/bin/sqlplus -S " / as sysdba" <<EOF >/dev/null 2>&1
set linesize 200
set heading on
set pagesize 0
set trimspool on
set trimout on
col tab_size_gb for 999,990.99
alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
spool $sqlresult
select 'Timing' note,sysdate as time from dual;
select 'Tab_info' note,t.num_rows,t.blocks,t.row_movement from dba_tables t where t.owner = '$v_owner' and t.table_name = '$v_table_name';
select 'Tab_size_gb' note ,round(sum(t.bytes)/1024/1024/1024,2) as tab_size_gb from dba_segments t where t.owner = '$v_owner' and t.segment_name = '$v_table_name';
select 'Objects' note,COUNT(1) as c_cnt from dba_objects t where t.status <> 'VALID';
spool off
exit;
EOF
}
function clean_tab(){
    v_owner=$1
    v_table_name=$2
    "$ORACLE_HOME"/bin/sqlplus -S " / as sysdba" <<EOF 
set linesize 200
set heading on
set pagesize 0
set trimspool on
set trimout on
alter table $v_owner.$v_table_name enable row movement;
alter table $v_owner.$v_table_name shrink space compact;
alter table $v_owner.$v_table_name shrink space cascade;
alter table $v_owner.$v_table_name disable row movement;
exit;
EOF
}
function gather_table_stats(){
    v_owner=$1
    v_table_name=$2
    "$ORACLE_HOME"/bin/sqlplus -S " / as sysdba" <<EOF
set linesize 200
set heading on
set pagesize 0
set trimspool on
set trimout on
exec dbms_stats.gather_table_stats('$v_owner','$v_table_name',cascade => true,method_opt => 'for all columns size auto',no_invalidate => false,degree=>16);
exit;
EOF
}
function get_clean_start(){
    clean_before_time=$(grep Timing "$sqlresult" |awk '{print $2,$3}')
    clean_before_formattime=$(date +%s -d "$clean_before_time")
    clean_before_num_rows=$(grep Tab_info "$sqlresult" |awk '{print $2}')
    clean_before_blocks=$(grep Tab_info "$sqlresult" |awk '{print $3}')
    clean_before_row_movement=$(grep Tab_info "$sqlresult" |awk '{print $4}')
    clean_before_tab_size=$(grep Tab_size_gb "$sqlresult" |awk '{print $2}')
    clean_before_objects_invalid=$(grep Objects "$sqlresult" |awk '{print $2}') 
}
function get_clean_end(){
    clean_after_time=$(grep Timing "$sqlresult" |awk '{print $2,$3}')
    clean_after_formattime=$(date +%s -d "$clean_after_time")
    clean_after_num_rows=$(grep Tab_info "$sqlresult" |awk '{print $2}')
    clean_after_blocks=$(grep Tab_info "$sqlresult" |awk '{print $3}')
    clean_after_row_movement=$(grep Tab_info "$sqlresult" |awk '{print $4}')
    clean_after_tab_size=$(grep Tab_size_gb "$sqlresult" |awk '{print $2}')
    clean_after_objects_invalid=$(grep Objects "$sqlresult" |awk '{print $2}') 
}

function display_head_info(){
    v_owner=$1
    v_table_name=$2
    v_table_id=$3
    recho "------------------------------------------$v_table_id/$clean_table_total"|tee -a "$cleanlog"
    recho "Table Owner :$v_owner  Table Name :$v_table_name"|tee -a "$cleanlog"    
}

function display_clean_start_info(){
    recho 'Clean start...'|tee -a "$cleanlog"
    recho "clean start time:$clean_before_time"|tee -a "$cleanlog"
    recho "Clean start num rows:$clean_before_num_rows"|tee -a "$cleanlog"
    recho "Clean start table blocks:$clean_before_blocks"|tee -a "$cleanlog"
    recho "Clean start row_movement:$clean_before_row_movement"|tee -a "$cleanlog"
    recho "Clean start tab_size:$clean_before_tab_size GB"|tee -a "$cleanlog"
    recho "Clean start objects_invalid:$clean_before_objects_invalid"|tee -a "$cleanlog"
}
function display_clean_runing_info(){
    recho "Clean sql running..."|tee -a "$cleanlog"
}
function display_gather_info(){
    recho "Clean table stat gathering..."|tee -a "$cleanlog"
}
function display_clean_end_info(){
    recho "Clean end..."|tee -a "$cleanlog"
    recho "Clean end time:$clean_after_time"|tee -a "$cleanlog"
    recho "Clean end num rows:$clean_after_num_rows"|tee -a "$cleanlog"
    recho "Clean end table blocks:$clean_after_blocks"|tee -a "$cleanlog"
    recho "Clean end row_movement:$clean_after_row_movement"|tee -a "$cleanlog"
    recho "Clean end tab_size:$clean_after_tab_size GB"|tee -a "$cleanlog"
    recho "Clean end objects_invalid:$clean_after_objects_invalid"|tee -a "$cleanlog"
}
function display_clean_summary_info(){
    v_size=$(echo "$clean_before_tab_size - $clean_after_tab_size"|bc)
    v_time=$((clean_after_formattime-clean_before_formattime))
    v_invaild_object=$(echo "$clean_after_objects_invalid - $clean_before_objects_invalid"|bc)
    recho "Clean summary..."|tee -a "$cleanlog"
    recho_thickened "Clean generate new invaild_object: $v_invaild_object"|tee -a "$cleanlog"
    recho_thickened "Clean Table Size: $v_size GB"|tee -a "$cleanlog"
    recho_thickened "Clean Elapsed: $v_time s"|tee -a "$cleanlog"
}
function display_clean_complete_info(){
    recho "Clean Complete..."|tee -a "$cleanlog"
}
function time_countdown(){
    for i in $(seq -w 10 -1 0)
    do
        recho "you have $i second to stop shell by edit tab_clean_flag.txt set flag=stop"
        sleep 1
    done
    v_clean_flag=$(cat "$tab_clean_flag"|grep 'flag'|awk -F'=' '{print $2}')
    if [[ "$v_clean_flag" = "stop" ]]
    then
        recho "Check the config file tab_clean_flag.txt flag=stop,the shell will exit!!!"
        exit
    else
        recho "Check the config file tab_clean_flag.txt flag=continue,The shell will continue!!!"
    fi
}

function check_configfile(){
    if [[ ! -f "$tab_conf" ]]
    then
        recho "The config file tab_conf.txt not found,please create it"
        exit
    fi
    if [[ ! -f "$tab_clean_flag" ]]
    then
        recho "The config file tab_clean_flag.txt file not found,please create it"
        exit
    fi  
}

function main(){
    check_configfile
    grep -v '^ *#' < "$tab_conf" | while IFS= read -r line
    do
        clean_table_id=$(echo "$line"|awk -F, '{print $1}')
        clean_table_owner=$(echo "$line"|awk -F, '{print $2}')
        clean_table_name=$(echo "$line"|awk -F, '{print $3}')
        display_head_info "$clean_table_owner" "$clean_table_name" "$clean_table_id"
        get_db_info "$clean_table_owner" "$clean_table_name"
        get_clean_start
        display_clean_start_info
        display_clean_runing_info
        clean_tab "$clean_table_owner" "$clean_table_name"
        display_gather_info
        gather_table_stats "$clean_table_owner" "$clean_table_name"
        get_db_info "$clean_table_owner" "$clean_table_name"
        get_clean_end
        display_clean_end_info
        display_clean_summary_info
        display_clean_complete_info
        time_countdown
    done
}
main

# display_head_info 'MYTHREE' 'T_OBJECTS'
# get_db_info 'MYTHREE' 'T_OBJECTS'
# get_clean_before
# display_clean_before_info
# display_clean_runing_info
# clean_tab  'MYTHREE' 'T_OBJECTS'    
# get_db_info 'MYTHREE' 'T_OBJECTS'
# get_clean_after
# display_clean_after_info
# display_clean_summary_info
# display_clean_end_info