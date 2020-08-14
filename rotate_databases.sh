#!/bin/bash

###############################################################################################
# Author: David Morais - DevOps Egineer
# Email: moraisdavid8@gmail.com
# Description: Script que realiza o rotacao diaria dos banco no servidor bd-sapiencia-testes.
# Version: 0.0.1
###############################################################################################

#PARAMETROS
BACKUP_DIR=/data/backup/databases
LOG_DIR=/data/backup/logs
PGBIN=/usr/pgsql-12/bin
HOST=localhost
PORT=5432
YESTERDAY=$(date -d '-1 day' '+%Y%m%d')
BEFOREYSTERDAY=$(date -d '-2 day' '+%Y%m%d')

# CREDENCIAIS
PGUSER=USUARIO_AQUI
export PGPASSWORD=SENHA_AQUI

terminate_connections () {

       for datname in $(get_db_list)
       do
               echo "TERMINANDO CONEXOES DE $datname" >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
	       echo $datname	
               $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$datname';"
               wait
       done

}

delete_old () {

       DBLIST=$(get_db_list)
       datname=$(echo $DBLIST | tr " " "\n" | grep '_')

       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "DROP DATABASE $datname;" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       wait

}

rename_late () {

       datname=sapiencia

       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "ALTER DATABASE $datname RENAME TO ${datname}_${BEFOREYSTERDAY};" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       wait

}

restore_new_db () {

       DATNAME=sapiencia_${YESTERDAY}
       DUMPDIR=${DATNAME}/sapiencia
       JOBS=4

       echo "- - - Criando base de dados de $YESTERDAY" >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -f ${BACKUP_DIR}/${DATNAME}/databases.sql

       #Limitando conexoes no novo banco antes do restore
       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "ALTER DATABASE $DATNAME WITH CONNECTION LIMIT 0;" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs

       #Restaurando novo banco
       $PGBIN/pg_restore -h $HOST -p $PORT -U $PGUSER -j $JOBS -Fd -d $DATNAME ${BACKUP_DIR}/${DUMPDIR} &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs

       # Renomeando novo banco
       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "ALTER DATABASE $DATNAME RENAME TO sapiencia;" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs

       # Libera conexoes
       $PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "ALTER DATABASE sapiencia WITH CONNECTION LIMIT -1;" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs

}

get_db_list () {

       #CONSULTA O BANCO E PEGA A VERSAO MAIS ANTIGA DO BANCO (DOIS DIAS ATRAS)
       GET_OLD_DB_SQL="SELECT datname from pg_database where datistemplate = 'f' AND datname <> 'postgres' and datname like 'sapiencia%';"
       DBLIST="$($PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -t -c "$GET_OLD_DB_SQL")"

       echo $DBLIST

}

main () {

       DATNAME=sapiencia

       echo "PROCESSO INICIADO - HORA: $(date +"%Hh%Mm")" > ${LOG_DIR}/${YESTERDAY}/rotate_database.report

       echo "Terminando conexoes..." >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       if terminate_connections &> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       then
               echo "Conexoes terminadas como sucesso"
       else
               echo "Erro ao terminar conexoes, mais informacoes: ${LOG_DIR}/${YESTERDAY}/rotate_database.logs" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
               exit 1
       fi

       echo "Deletando versao mais antiga do banco - ${DATNAME}_${BEFOREYSTERDAY}"
       if delete_old &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       then
               echo "${DATNAME}_${BEFOREYSTERDAY} deletado com sucesso" >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       else
               echo "Erro ao deletar ${DATNAME}_${BEFOREYSTERDAY}, mais informacoes: ${LOG_DIR}/${YESTERDAY}/rotate_database.logs" >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
               exit 2
       fi

       echo "Renomeando versao mais recente para data de $BEFOREYSTERDAY..." >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       if rename_late &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       then
               echo "Banco renomeado de $DATNAME para ${datname}_${BEFOREYSTERDAY}" >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       else
               echo "Erro ao renomear o banco $DATNAME, mais informacoes: ${LOG_DIR}/${YESTERDAY}/rotate_database.logs" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
               exit 3
       fi

       echo "Restaurando versao mais recente - $DATNAME..." >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       if restore_new_db &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.logs
       then
               echo "Banco $DATNAME restaurado com sucesso." >> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
       else
               echo "Erro ao restaurar o banco $DATNAME, mais informacoes: ${LOG_DIR}/${YESTERDAY}/rotate_database.logs" &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.report
               exit 4
       fi

       DBLIST=$(get_db_list)

       echo "LISTA DE BANCO EM TESTES"
       echo $($DBLIST | tr " " "\n") &>> ${LOG_DIR}/${YESTERDAY}/rotate_database.report

       echo "PROCESSO FINALIZADO - HORA: $(date +"%Hh%Mm")" > ${LOG_DIR}/${YESTERDAY}/rotate_database.report
}

if [ $USER != $PGUSER ];then
       echo "Permissao negada para usuario diferente de $PGUSER"
       echo "Encerrando..."
       exit 1
else
       # CRIA DIRETORIO DE LOGS PARA O DIA DE ONTEM (DATA DO DUMP MAIS RECENTE DO BANCO)
       mkdir -p ${LOG_DIR}/${YESTERDAY}

       if main > /dev/null
       then	
               exit 0
       else
               exit 1
       fi
fi
