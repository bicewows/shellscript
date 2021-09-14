#!/bin/bash
# 在所有节点执行
v_inst=$1
# v_inst='three'
v_insts=($(ps -ef|grep ora_pmon|grep -v grep|awk -F_ '{print $3}'|cut -d1 -f1))
v_flag='true'
for i in "${v_insts[@]}"
do
    if [[ "$i" = "$v_inst" ]]; then
        v_flag='false'
        break
    fi
done
echo "$v_flag"
# 输出样例
# true 检测通过，没有数据库相同的
# false 检测不通过，存在数据库相同的
