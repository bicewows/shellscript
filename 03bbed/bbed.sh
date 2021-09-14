#!/bin/bash
#select file#||chr(9)||name||chr(9)||bytes from v$datafile;
#select listagg(file_id||','||t.bytes/1024/8,' ') within group(order by file_id) from dba_data_files t;

file_list="1,94720 2,98560 3,5760 4,640 5,12800"
#file_list="3,5760 4,640"
pwd_script=$(
    cd "$(dirname "$0")" || exit
    pwd
)
function bbed_map(){
    v_file_id=$1
    v_block_id=$2
    v_bbed_map_tmp=$3
 /usr/bin/expect -c "
 set timeout -1
 spawn  bbed parfile=/home/oracle/bbed/par.txt  
 expect {
     \"Password:\" {send \"blockedit\r\"}
     }  
 expect {
     \"BBED> \" {send \"set dba $v_file_id,$v_block_id\r\"}
     } 
 expect {
     \"BBED> \" {send \"map /v\r\"}
     }
 expect {
     \"BBED> \" {send \"exit\r\"}
     }
 ">"$v_bbed_map_tmp"
 ##interact
}
function format_log(){
    v_file_id=$1
    v_block_id=$2
    v_bbed_map_tmp=$3
    v_bbed_map_final=$4
    bbed_result=$(sed -n 17p "$v_bbed_map_tmp")
    echo "file :$v_file_id block_id:$v_block_id --> bbed :$bbed_result">> "$v_bbed_map_final"
}

function get_block_list(){
    v_file_id=$1
    v_file_block=$2
    v_bbed_map_tmp=$3
    v_bbed_map_final=$4
    for ((i=1; i<=v_file_block; i++))
    do
        bbed_map "$v_file_id" "$i" "$v_bbed_map_tmp"
        format_log "$v_file_id" "$i" "$v_bbed_map_tmp" "$v_bbed_map_final"
    done 
}

function get_file_list(){
    args=($1)
    for i in ${!args[*]}
    do
        local v_file_block=${args[$i]}
        v_file_id=${v_file_block%,*}
        v_file_block=${v_file_block#*,}
        v_i=$((i + 1))
        # echo "$((i + 1))"
        # echo "$v_file_id"
        # echo "$v_file_block"
        bbed_map_tmp="$pwd_script/bbed_tmp_$v_i.log"
        bbed_map_final="$pwd_script/bbed_final_$v_i.log"
        get_block_list "$v_file_id" "$v_file_block" "$bbed_map_tmp" "$bbed_map_final" &
    done
}
function main(){
    get_file_list "$file_list"
}
main

# cat bbed_final_1.log |grep -v 'BBED-00400'|awk -F'>' '{print $2}'|sort|uniq
# cat bbed_final_2.log |grep -v 'BBED-00400'|awk -F'>' '{print $2}'|sort|uniq
# cat bbed_final_3.log |grep -v 'BBED-00400'|awk -F'>' '{print $2}'|sort|uniq
# cat bbed_final_4.log |grep -v 'BBED-00400'|awk -F'>' '{print $2}'|sort|uniq
# cat bbed_final_5.log |grep -v 'BBED-00400'|awk -F'>' '{print $2}'|sort|uniq