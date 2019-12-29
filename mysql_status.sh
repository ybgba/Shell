#!/bin/bash
 
#Get InnoDB Row Lock Details and InnoDB Transcation Lock Memory
#mysql> SELECT SUM(trx_rows_locked) AS rows_locked, SUM(trx_rows_modified) AS rows_modified, SUM(trx_lock_memory_bytes) AS lock_memory FROM information_schema.INNODB_TRX;
#+-------------+---------------+-------------+
#| rows_locked | rows_modified | lock_memory |
#+-------------+---------------+-------------+
#|        NULL |          NULL |        NULL |
#+-------------+---------------+-------------+
#1 row in set (0.00 sec)
 
#+-------------+---------------+-------------+
#| rows_locked | rows_modified | lock_memory |
#+-------------+---------------+-------------+
#|           0 |             0 |         376 |
#+-------------+---------------+-------------+
 
#Get InnoDB Compression Time
#mysql> SELECT SUM(compress_time) AS compress_time, SUM(uncompress_time) AS uncompress_time FROM information_schema.INNODB_CMP;
#+---------------+-----------------+
#| compress_time | uncompress_time |
#+---------------+-----------------+
#|             0 |               0 |
#+---------------+-----------------+
#1 row in set (0.00 sec)
 
 
#Get InnoDB Transaction states
 
#TRX_STATE  Transaction execution state. One of RUNNING, LOCK WAIT, ROLLING BACK or COMMITTING.
 
#mysql> SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state;
#+---------+-----+
#| state   | cnt |
#+---------+-----+
#| running |   1 |
#+---------+-----+
#1 row in set (0.00 sec)

mysql=$(which mysql)
#注意，如果你的mysql是非标准安装，请写mysql的绝对路径
#mysql=/usr/bin/mysql

if [ "$1" = "" ];then
    echo "Error variables"
else
    echo "status|variables"|grep "$1" > /dev/null 2>&1
fi

if [ "$?" = 0 ];then
    MYSQL_USER=$3
    MYSQL_PASSWORD=$4
    MYSQL_Host=$5 
else
    MYSQL_USER=$2
    MYSQL_PASSWORD=$3
    MYSQL_Host=$4
fi
[ "${MYSQL_USER}"     = '' ] &&  MYSQL_USER=rep_check
[ "${MYSQL_PASSWORD}" = '' ] &&  MYSQL_PASSWORD=0vAFoJF7bRlZgs
[ "${MYSQL_Host}"     = '' ] &&  MYSQL_Host=localhost
TMP_MYSQL_STATUS="/var/log/zabbix/${MYSQL_Host}_mysql_stats.txt"
TMP_MYSQL_BINLOG="/var/log/zabbix/${MYSQL_Host}_mysql_binlog.txt"
TMP_MYSQL_TABLE_ROWS="/var/log/zabbix/${MYSQL_Host}_mysql_table_rows.txt"

${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "select version();" >/dev/null 2>&1
[ "$?" != 0 ] && echo "Login Error" && exit 1

CMD () {
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW GLOBAL STATUS;"|grep -v "Variable_name"> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW GLOBAL VARIABLES"|grep -v "Variable_name" >>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW ENGINE INNODB STATUS\G;" |egrep '(\bHistory list length\b|\bLast checkpoint at\b|\bLog sequence number\b|\bLog flushed up to\b|\bread views open inside InnoDB\b|\bqueries inside InnoDB\b|\bqueries in queue\b|\bhash searches\b|\bnon-hash searches/s\b|\bnode heap\b|\bMutex spin waits\b|\bMutex spin waits\b|\bMutex spin waits\b)'>>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW SLAVE STATUS\G;" >> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW MASTER STATUS\G;">> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(compress_time) AS compress_time, SUM(uncompress_time) AS uncompress_time FROM information_schema.INNODB_CMP\G" >>${TMP_MYSQL_STATUS}
    #${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state\G;" >>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(trx_rows_locked) AS rows_locked, SUM(trx_rows_modified) AS rows_modified, SUM(trx_lock_memory_bytes) AS lock_memory FROM information_schema.INNODB_TRX\G;" >> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW  BINARY LOGS;" |grep -v "Log_name">> ${TMP_MYSQL_BINLOG}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "select table_name,(DATA_LENGTH+INDEX_LENGTH)/1024/1024 as total_mb, table_rows from information_schema.tables where table_rows is not  NULL"|grep -v table_name > ${TMP_MYSQL_TABLE_ROWS}
}

#给获取状态加锁，防止重复执行
if [ -e ${TMP_MYSQL_STATUS} ]; then
    # Check and run the script
    TIMEFROM=`stat -c %Y ${TMP_MYSQL_STATUS}`
    TIMENOW=`date +%s`
    if [ `expr $TIMENOW - $TIMEFROM` -gt 30 ]; then
        rm -f ${TMP_MYSQL_STATUS}
        rm -f ${TMP_MYSQL_BINLOG}
        rm -f ${TMP_MYSQL_TABLE_ROWS}
        CMD
    fi
else
    CMD
fi

case $1 in
    Innodb_rows_locked)
        value=$(grep "rows_locked" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
        [ "$value" == "NULL" ] && echo 0 || echo $value
        ;;
    Innodb_rows_modified)
        value=$(grep "rows_modified" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
        [ "$value" == "NULL" ] && echo 0 || echo $value
        ;;
    Innodb_trx_lock_memory)
        value=$(grep "lock_memory" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
        [ "$value" == "NULL" ] && echo 0 || echo $value
        ;;
    Innodb_compress_time)
        value=$(grep "compress_time" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
        #${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(compress_time) AS compress_time, SUM(uncompress_time) AS uncompress_time FROM information_schema.INNODB_CMP;"|awk '{print $1}')
        echo $value
        ;;  
    Innodb_uncompress_time)
        value=$(grep "uncompress_time" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
        #${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(compress_time) AS compress_time, SUM(uncompress_time) AS uncompress_time FROM information_schema.INNODB_CMP;"|awk '{print $2}')
        echo $value
        ;;   
    Innodb_trx_running)
        value=$(${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e 'SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state;'|grep running|awk '{print $2}')
        [ "$value" == "" ] && echo 0 || echo $value
        ;;
    Innodb_trx_lock_wait)
        value=$(${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e 'SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state;'|grep lock_wait|awk '{print $2}')
        [ "$value" == "" ] && echo 0 || echo $value
        ;;
    Innodb_trx_rolling_back)
        value=$(${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e 'SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state;'|grep rolling_back|awk '{print $2}')
        [ "$value" == "" ] && echo 0 || echo $value
        ;;
    Innodb_trx_committing)
        value=$(${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e 'SELECT LOWER(REPLACE(trx_state, " ", "_")) AS state, count(*) AS cnt from information_schema.INNODB_TRX GROUP BY state;'|grep committing|awk '{print $2}')
        [ "$value" == "" ] && echo 0 || echo $value
        ;;
    Innodb_trx_history_list_length)
        grep "History list length" ${TMP_MYSQL_STATUS}|head -1|awk '{print $4}'
        ;;
    Innodb_last_checkpoint_at)
        grep "Last checkpoint at" ${TMP_MYSQL_STATUS}|head -1|awk '{print $4}'
        ;;
    Innodb_log_sequence_number)
        grep "Log sequence number" ${TMP_MYSQL_STATUS}|head -1|awk '{print $4}'
        ;;
    Innodb_log_flushed_up_to)
        grep "Log flushed up to" ${TMP_MYSQL_STATUS}|head -1|awk '{print $5}'
        ;;
    Innodb_open_read_views_inside_innodb)
        grep "read views open inside InnoDB" ${TMP_MYSQL_STATUS}|head -1|awk '{print $1}'
        ;;
    Innodb_queries_inside_innodb)
        grep "queries inside InnoDB" ${TMP_MYSQL_STATUS}|head -1|awk '{print $1}'
        ;;
    Innodb_queries_in_queue)
        grep "queries in queue" ${TMP_MYSQL_STATUS}|head -1|awk '{print $5}'
        ;;
    Innodb_hash_seaches)
        grep "hash searches" ${TMP_MYSQL_STATUS}|head -1|awk '{print $1}'
        ;;
    Innodb_non_hash_searches)
        grep "non-hash searches/s" ${TMP_MYSQL_STATUS}|head -1|awk '{print $4}'
        ;;
    Innodb_node_heap_buffers)
        grep "node heap" ${TMP_MYSQL_STATUS}|head -1|awk '{print $8}'
        ;;
    Innodb_mutex_os_waits)
        grep "Mutex spin waits" ${TMP_MYSQL_STATUS}|head -1|awk '{print $9}'
        ;;
    Innodb_mutex_spin_rounds)
        grep "Mutex spin waits" ${TMP_MYSQL_STATUS}|head -1|awk '{print $6}'|tr -d ','
        ;;
    Innodb_mutex_spin_waits)
        grep "Mutex spin waits" ${TMP_MYSQL_STATUS}|head -1|awk '{print $4}'|tr -d ','
        ;;  
    Slave_IO_Running)
        grep "Slave_IO_Running" ${TMP_MYSQL_STATUS}>/dev/null 2>&1 
        if [ "$?" != 0 ];then
            RET=0.1 
        else       
            RET=$(egrep '(Slave_IO_Running):' ${TMP_MYSQL_STATUS}|sort|uniq| grep -ci "Yes")
        fi         
        echo ${RET}
        ;;
    Slave_SQL_Running)
        grep "Slave_SQL_Running" ${TMP_MYSQL_STATUS}|sort|uniq
        if [ "$?" != 0 ];then
            RET=0.1 
        else       
            RET=$(egrep '(Slave_SQL_Running):' ${TMP_MYSQL_STATUS}|sort|uniq| grep -ci "Yes")
        fi         
        echo ${RET}
        ;;   
    Exec_Master_Log_Pos)
        grep "Relay_Log_Pos" ${TMP_MYSQL_STATUS}|awk '{print $2}'
        ;;
    Seconds_Behind_Master)
        grep "Seconds_Behind_Master" ${TMP_MYSQL_STATUS}|awk '{print $2}'
        ;;
    Read_Master_Log_Pos)
        grep "Read_Master_Log_Pos" ${TMP_MYSQL_STATUS}|awk '{print $2}'
        ;;
    Exec_Master_Log_Pos)
        grep "Exec_Master_Log_Pos" ${TMP_MYSQL_STATUS}|awk '{print $2}'
        ;;
    Relay_Log_Pos)    
        grep "Relay_Log_Pos" ${TMP_MYSQL_STATUS}|awk '{print $2}'
        ;;
    status)
        grep "\b$2\b" ${TMP_MYSQL_STATUS}|head -1|awk '{print $2}'
        ;;
    variables)
        grep "\b$2\b" ${TMP_MYSQL_STATUS}|head -1|awk '{print $2}'
        ;;
    version)
        ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "select version();"|grep -v "version()"
        ;;
    ping)
        /usr/bin/mysqladmin -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} ping|grep -c alive
        ;;
    Binlog_file)
	grep "File:" ${TMP_MYSQL_STATUS}|uniq|awk '{print $2}'
        ;;
    Binlog_position)
	grep "Position:" ${TMP_MYSQL_STATUS}|uniq|awk '{print $2}'
        ;;
    Binlog_count)
	sort ${TMP_MYSQL_BINLOG}|uniq|wc -l
        ;;
    Binlog_total_size)
        awk '{sum+=$NF}END{print  sum}' ${TMP_MYSQL_BINLOG}
        ;;
    Slave_count)
	${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "show slave hosts;"|grep -v "Server_id"|wc -l
        ;;
    Table_dicovery)
        awk 'BEGIN{printf "{\n    \"data\":[\n"};$1 {printf c"        {\"{#TABLE}\":\""$1"\"}";c=",\n"};END{print "\n    ]\n}"}' ${TMP_MYSQL_TABLE_ROWS}
        ;;
    Table_size)
        grep  "\b$5\b"  ${TMP_MYSQL_TABLE_ROWS}|awk "{print $$5}"
        ;;
    *)
        echo "Error Variable"
        ;;
esac
