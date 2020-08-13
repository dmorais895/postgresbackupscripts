#!/bin/bash

#PARAMETROS
BACKUP_DIR=/data/backup/databases
PGBIN=/usr/pgsql-12/bin
PGUSER=postgres

#PASSWORD
export PGPASSWORD=SENHA_AQUI

#CONFIGURA DATA DO DIA ANTERIOR
DUMPDATE=$(date -d +"yesterday" +'%Y%m%d')

#VERIFICA O USUARIO QUE ESTA EXECUTANDO O SCRIPT
if [ $USER != $PGUSER ];then
	echo "Execute $0 como usuario postgres"
	exit 1
fi

backup_roles() {

	HOST=$1
	PORT=$2
	DATABASE=$3
	BACKUP_NAME=$4

	$PGBIN/pg_dumpall -h $HOST -p $PORT -U $PGUSER --roles-only > $BACKUP_NAME/roles.sql 2> /dev/null

	SQL="SELECT ' CREATE DATABASE ' || datname || ' WITH OWNER ' || rolname || ' TABLESPACE = pg_default LC_COLLATE = "pt_BR.UTF8" LC_CTYPE = "pt_BR.UTF8"  CONNECTION LIMIT = -1;' from pg_database d inner join pg_roles r on r.oid = d.datdba where datistemplate = 'f' AND datname <> 'postgres';"

	RESULT_SQL="$($PGBIN/psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "$SQL" | grep CREATE)"

	# Executa o backup dos bancos do cluster postgresql
        echo "${RESULT_SQL}" | sed s/?/--/g | sed s/\(/--/g | sed s/\)/--/g | sed s/pt_BR.UTF8/\'pt_BR.UTF8\'/g | sed "s/ WITH/_$DUMPDATE WITH/g" > $BACKUP_NAME/databases.sql

}

backup_database () {
	
	HOST=$1
        PORT=$2
        DATABASE=$3
        BACKUP_NAME=$4
	
	if $PGBIN/pg_dump -h $HOST -p $PORT -U $PGUSER -j 2 -Fd -b -f "$BACKUP_NAME/${DATABASE}" -d $DATABASE 2&> ${BACKUP_NAME}/${DATABASE}_dump.log
	then
		echo "BACKUP FINALIZADO COM SUCESSO" >> ${BACKUP_NAME}/${DATABASE}_report.log
	else
		echo "ERROS OCORRERAM DURANTE O BACKUP" >> ${BACKUP_NAME}/${DATABASE}_report.log
		echo "MAIS INFORMACOES EM ${BACKUP_NAME}/${DATABASE}_dump.log " >> ${BACKUP_NAME}/${DATABASE}_report.log
		exit 1
	fi

}

do_backup() {

	HOST=bd-sapiencia-producao.info.ufrn.br
	PORT=5432
	DATABASE=sapiencia
	BACKUP_NAME=${BACKUP_DIR}/${DATABASE}_${DUMPDATE}

	if [ ! -d $BACKUP_NAME ];then
		mkdir -p $BACKUP_NAME
	else
		rm -r $BACKUP_NAME
	fi
	
	echo "INICIANDO BACKUP - HORA: $(date +"%Hh%Mm")"
	echo "REALIZANDO BACKUP DAS ROLES"
	backup_roles $HOST $PORT $DATABASE $BACKUP_NAME
	wait
	echo "REALIZANDO DUMP DA BASE DA DADOS"
	backup_database $HOST $PORT $DATABASE $BACKUP_NAME
	wait
	echo "FINALIZANDO BACKUP - HORA: $(date +"%Hh%Mm")"

}

do_backup

exit 0
