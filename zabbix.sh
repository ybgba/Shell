#!/bin/bash


## 检索mysql的路径，也可以使用绝对路径表示
mysql=$(which mysql)

## 传递的第一个参数，监控名
if [ "$1" = "" ];then
    echo "Error variables"
else
    echo "status|variables"|grep "$1" > /dev/null 2>&1
fi

## 传递的第3,4,5参数，分别为user,pwd,host,如果第一个参数下无子参数，则2,3,4参数为user,pwd,host
if [ "$?" = 0 ];then
    MYSQL_USER=$3
    MYSQL_PASSWORD=$4
    MYSQL_Host=$5 
else
    MYSQL_USER=$2
    MYSQL_PASSWORD=$3
    MYSQL_Host=$4
fi

## zabbix数据库的用户密码和host以及临存放数据的临时文件
[ "${MYSQL_USER}"     = '' ] &&  MYSQL_USER='root'
[ "${MYSQL_PASSWORD}" = '' ] &&  MYSQL_PASSWORD='Ane#56!kygis'
[ "${MYSQL_Host}"     = '' ] &&  MYSQL_Host=localhost
TMP_MYSQL_STATUS="/var/log/zabbix/${MYSQL_Host}_mysql_stats.txt"
TMP_MYSQL_BINLOG="/var/log/zabbix/${MYSQL_Host}_mysql_binlog.txt"
TMP_MYSQL_TABLE_ROWS="/var/log/zabbix/${MYSQL_Host}_mysql_table_rows.txt"

## 连接zabbix数据库
${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "select version();" >/dev/null 2>&1
[ "$?" != 0 ] && echo "Login Error" && exit 1

CMD () {
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW GLOBAL STATUS;"|grep -v "Variable_name"> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW GLOBAL VARIABLES"|grep -v "Variable_name" >>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW ENGINE INNODB STATUS\G;" |egrep '(\bHistory list length\b|\bLast checkpoint at\b|\bLog sequence number\b|\bLog flushed up to\b|\bread views open inside InnoDB\b|\bqueries inside InnoDB\b|\bqueries in queue\b|\bhash searches\b|\bnon-hash searches/s\b|\bnode heap\b|\bMutex spin waits\b|\bMutex spin waits\b|\bMutex spin waits\b)'>>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW SLAVE STATUS\G;" >> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW MASTER STATUS\G;">> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(compress_time) AS compress_time, SUM(uncompress_time) AS uncompress_time FROM information_schema.INNODB_CMP\G" >>${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SELECT SUM(trx_rows_locked) AS rows_locked, SUM(trx_rows_modified) AS rows_modified, SUM(trx_lock_memory_bytes) AS lock_memory FROM information_schema.INNODB_TRX\G;" >> ${TMP_MYSQL_STATUS}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "SHOW  BINARY LOGS;" |grep -v "Log_name">> ${TMP_MYSQL_BINLOG}
    ${mysql} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_Host} -e "select table_name,table_rows,(DATA_LENGTH+INDEX_LENGTH)/1024/1024 as total_mb from information_schema.tables where table_schema not in ('information_schema','mysql','performance_schema','test');"|grep -v table_name > ${TMP_MYSQL_TABLE_ROWS}
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
        echo $value
        ;;  
    Innodb_uncompress_time)
        value=$(grep "uncompress_time" ${TMP_MYSQL_STATUS}|head -1| awk '{print $2}')
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
## innodb status 
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
## mysql运行状态 < 1报警
    Mysql_Status)
	Mysql_Status=`mysqladmin -h${MYSQL_Host} ping | grep alive | wc -l`
	;;
## slave 相关参数
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
## 表大小
    Table_size)
	while read -r line
	do
  		TABLE_NAME=`echo $line | awk '{print $1}'`
  		ROW=`echo $line | awk '{print $2}'`
  		SIZE=`echo $line | awk '{print $3}'`
  		echo $TABLE_NAME $ROW $SIZE
	done < ${TMP_MYSQL_TABLE_ROWS}
	;;
## INNODB BUFFER READ HITS ## < 90报警
    Innodb_Buffer_Read_Hits)
	Innodb_buffer_pool_read_requests=`grep "Innodb_buffer_pool_read_requests" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Innodb_buffer_pool_reads=`grep "Innodb_buffer_pool_reads" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Innodb_buffer_pool_read_ahead=`grep "Innodb_buffer_pool_read_ahead" ${TMP_MYSQL_STATUS} | awk '{print $2}'`	
	INNODB_BUFFER_READ_HITS=`echo $Innodb_buffer_pool_read_requests $Innodb_buffer_pool_reads $Innodb_buffer_pool_read_ahead | awk "{print ($Innodb_buffer_pool_read_requests-$Innodb_buffer_pool_reads-$Innodb_buffer_pool_read_ahead)/$Innodb_buffer_pool_read_requests*100}" | awk -F '.' '{print $1}'`
	;;
## Connections  TOTAL_CONN > 300报警  Conn_usage_Rate>75报警
    Connections)
	ACTIVE_CONN=`grep "Threads_running" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        TOTAL_CONN=`grep "Threads_connected" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        Threads_created=`grep "Threads_created" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        Threads_cached=`grep "Threads_cached" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Connections=`grep "Connections" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Max_Connections=`grep -w "max_connections" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Aborted_connects=`grep "Aborted_connects" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        Max_used_connections=`grep "Max_used_connections" ${TMP_MYSQL_STATUS} | awk '{print $2}'`	
	Conn_usage_Rate=`echo $TOTAL_CONN $Max_Connections | awk "print $TOTAL_CONN/$Max_Connections*100"`
	Conn_Response=`echo $Max_used_connections $Max_Connections | awk "print $Max_used_connections/$Max_Connections*100"`
	;;
## Log wait
    Log_Wait)
	grep "Innodb_log_waits" ${TMP_MYSQL_STATUS} | awk '{print $2}'
	;;
## Slow query
    Slow_Queries)
	grep "Slow_queries" ${TMP_MYSQL_STATUS} | awk '{print $2}'  
	;;
## Lock < 5000 报警
    Table_Locks)
	Table_locks_immediate=`grep "Table_locks_immediate" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Table_locks_waited=`grep "Table_locks_waited" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	if [ $Table_locks_waited != 0 ]; then
		 Table_Locks=$[$Table_locks_immediate/$Table_locks_waited]
	fi
	;;
## Rows lock 当前等待超过10报警，平均时间超过10秒报警
    Rows_Lock)
	Innodb_row_lock_current_waits=`grep "Innodb_row_lock_current_waits" | awk '{print $2}'`
	Innodb_row_lock_time_avg=`grep "Innodb_row_lock_time_avg" | awk '{print $2}'`
	;; 
## Table scan > 5000报警
    Table_Scan)
	Handler_read_rnd_next=`grep "Handler_read_rnd_next" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Com_select=`grep "Com_select" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Table_Scan=$[$Handler_read_rnd_next/$Com_select]
	;;
## Open File > 75 报警
    Open_file)
	Open_files=`grep "Open_files" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	open_files_limit=`grep "open_files_limit" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Open_file=`echo $Open_files $open_files_limit | awk "{print $Open_files/$open_files_limit*100}"`
	;;
## Open Table 命中率<80,使用率>80报警
    Open_Table)
        Open_tables=`grep "Open_tables" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        Opened_tables=`grep "Opened_tables" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
        table_open_cache=`grep "table_open_cache" ${TMP_MYSQL_STATUS} | awk '{print $2}'`
	Open_Table_hit_rate=`echo $Open_tables $Opened_tables | awk "{print $Open_tables/$Opened_tables*100}"`
	Open_Table_rate=`echo $Open_tables $table_open_cache | awk "{print $Open_tables/$table_open_cache*100}"`
	;;
## Create tmp table > 30 报警
    Create_Tmp_Table)
	Created_tmp_disk_tables=`grep "Created_tmp_disk_tables" mysql_status.txt | awk '{print $2}'`
	Created_tmp_tables=`grep "Created_tmp_tables" mysql_status.txt | awk '{print $2}'`  
	Create_Tmp_Table=`echo $Created_tmp_disk_tables $Created_tmp_tables | awk "{print $Created_tmp_disk_tables/$Created_tmp_tables*100}"`
	;;

esac


