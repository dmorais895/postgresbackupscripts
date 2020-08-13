# Postgres Backup Scripts
Esse projeto contem os scripts utilizados no processo de backup e restore dos ambientes de producao e testes do projeto Sapiencia (Dashinfra).

---
## Estrutura do projeto

```
├── README.md               # Documentacao do projeto.
├── backup.sh               # Script que realiza o dump das bases de producao diariamente.
└── rotate_databases.sh     # Script que realiza a rotacao dos bancos em testes.
```
---
## Diretorios

Na vm que ira realizar o dump é preciso ter a seguinte estrutura de diretorios. Sendo essa apenas uma sujestao, cabe o administrador, caso deseje alterar esses nomes, alterar tambem a sua referencia nos scripts.

```
.
├── backup                  # Diretorio raiz dos backups.
│   ├── databases           # Diretorio onde ficam os dumps.
│   ├── logs                # Diretorio onde ficam os logs das rotinas.
│   └── scripts             # Diretorio onde ficam os scripts do projeto.
```
----
## Scripts

* backup
* rotate_databases

### [backup.sh](#https://projetos.imd.ufrn.br/projectdashinfra/devops/postgresbackupscripts/-/blob/7de39b86034f1ac63fe709c16bad2cb3701bd0b7/backup.sh) 

Este script realiza o dump da base de dados postgres do projeto projeto sapiencia. Para sua execucao eh preciso que sejam configuradas as seguintes as seguintes variaveis:

Variavel | Descrição | Exemplo (Valor padrão)
--------- | --------- | ----------------------
BACKUP_DIR | Caminho do diretorio aonde serao armazendado os dumps. | /data/backup/databases
PGBIN | Caminho do diretorio estao instalados os binarios do postgres. | /usr/pgsql-12/bin
PGUSER | Usuario com acesso para realizar o dump. | postgres
PGPASSWORD | Senha do usuario $PGUSER. | SENHA_SEGURA

Obs. 1: **O diretorio /backup citado na secao _diretorios_ e seus arquivos filhos devem ter como proprietario o $PGUSER**

Obs. 2: **Ao realizar uma alteracao no script, nunca deve ser commitado a alteracao com a senha real salva no arquivo. Se isto acontecer, a senha do usuario deve ser trocada.**

### [rotate_databases.sh](#https://projetos.imd.ufrn.br/projectdashinfra/devops/postgresbackupscripts/-/blob/master/rotate_databases.sh) 

Este script realiza a rotacao das bases de dados no ambiente de testes (bd-sapiencia-testes). Utilizando os dumps gerados pelo pelo **backup**, esse script mantem os bancos de dois dias anteriores. Sendo:

* sapiencia: Base de dados geradas no dia anterior (dump mais recente).
* sapiencia_YYYYMMDD: Base de dados de dois dias atras.

Para execucao do mesmo, e necessarios que as seguintes variaveis estejam corretamente configuradas:

Variavel | Descrição | Exemplo (Valor padrão)
--------- | --------- | ----------------------
BACKUP_DIR | Caminho do diretorio aonde serao armazendado os dumps. | /data/backup/databases
LOG_DIR | Caminho do diretorio aonde serao armazendado os logs da rotina. | /data/backup/logs.
PGBIN | Caminho do diretorio estao instalados os binarios do postgres. | /usr/pgsql-12/bin
HOST | Host aonde a rotina ira executar a rotacao. | localhost
PORT | Porta de servico do PostgreSQL em $HOST. | 5432
PGUSER | Usuario com acesso para realizar o dump. | postgres
PGPASSWORD | Senha do usuario $PGUSER. | SENHA_SEGURA

Obs. 1: **O diretorio /backup citado na secao _diretorios_ e seus arquivos filhos devem ter como proprietario o $PGUSER**

Obs. 2: **Ao realizar uma alteracao no script, nunca deve ser commitado a alteracao com a senha real salva no arquivo. Se isto acontecer, a senha do usuario deve ser trocada.**

---

## Como ficam os dumps?

Apos executada a rotina [backup.sh](#https://projetos.imd.ufrn.br/projectdashinfra/devops/postgresbackupscripts/-/blob/master/backup.sh), os dumps ficam organizados seguinte forma:

```
databases
├── sapiencia_20200811              # Diretorio raiz do dump identificado pela data referente aos dados.
│   ├── databases.sql               # Consulta SQL que cria o banco de dados da data especificada. Utilizado na rotina de rotacao dos bancos em testes.
│   ├── roles.sql                   # Consulta SQL com a criacao das roles utilizadas no banco do sapiencia. Utilizada caso seja necessario recriar os banco em um PostgreSQL novo.
│   ├── sapiencia                   # Dump do dia no formato diretorio fornecido pelo PostgreSQL.
│   ├── sapiencia_dump.log          # Arquivo de log no binario de dump. Normalmente estara vazio, signiicando que nenhum erro ocorreu durante o processo.
│   └── sapiencia_report.log        # Arquivo com informacoes da rotina de backup.
```

---

### Autores
* **David Morais** - *Engenheiro DevOps* - [moraidavid8@gmail.com](mailto:moraidavid8@gmail.com)


