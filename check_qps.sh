#!/bin/bash

mysqladmin -h127.0.0.1 -uroot -p'111111' extended-status -i1|awk 'BEGIN{local_switch=0;print "QPS   Commit Rollback   select   insert   update   delete   TPS    Threads_con Threads_run  Slow_sql   read   write   InnodbR   InnodbU   InnodbI   InnodbD \n----------------------------------------------------------------------------------------------------------------------------------- "}

     $2 ~ /Queries$/            {q=$4-lq;lq=$4;}

     $2 ~ /Com_commit$/         {c=$4-lc;lc=$4;}

     $2 ~ /Com_rollback$/       {r=$4-lr;lr=$4;}

     $2 ~ /Com_select$/         {cs=$4-so;so=$4;}

     $2 ~ /Com_insert$/         {ci=$4-io;io=$4;}

     $2 ~ /Com_update$/         {cu=$4-uo;uo=$4;}

     $2 ~ /Com_delete$/         {cd=$4-cdo;cdo=$4;}

     $2 ~ /Threads_connected$/  {tc=$4;}

     $2 ~ /Threads_running$/    {tr=$4;}

     $2 ~ /Innodb_rows_read$/    {irr=$4-oirr;oirr=$4;}

     $2 ~ /Innodb_rows_updated$/    {iru=$4-oiru;oiru=$4;}

     $2 ~ /Innodb_rows_inserted$/    {iri=$4-oiri;oiri=$4;}

     $2 ~ /Innodb_rows_deleted$/    {ird=$4-oird;oird=$4;}

     $2 ~ /Slow_queries$/       {s=$4-sq;sq=$4;

        if(local_switch==0) 

                {local_switch=1; count=0}

        else {

                if(count>48) 

                        {count=0;print "-------------------------------------------------------------------------------------------------------------------- \nQPS   Commit Rollback   select   insert   update   delete   TPS    Threads_con Threads_run  Slow_sql   read   write   InnodbR   InnodbU   InnodbI   InnodbD \n----------------------------------------------------------------------------------------------------------------------------------- ";}

                else{ 

                        count+=1;

                        printf "%-6d %-8d %-9d %-8d %-7d %-9d %-6d %-10d %-12d %-10d %-8d %-7d %-6d %-11d %-9d %-9d %d \n", q,c,r,cs,ci,cu,cd,cs+ci+cu+cd,tc,tr,s,cs,ci+cu+cd,irr,iru,iri,ird;

                }

        }

}'
