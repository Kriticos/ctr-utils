# ctr-utils

## Banco de dados (ctr-mysql)
O script de importacao CSV **nao cria** o banco nem a tabela. A criacao deve ser feita no container `ctr-mysql` antes de rodar o import.

### Criar database e tabela
Use o SQL do projeto:
- Script: `/bskp-des/ctr-utils-DES/scripts/odbc/create_test_table.sql`

Exemplo (ajuste usuario/senha conforme seu ambiente):
```
docker exec -i ctr-mysql mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS login_domain;"
docker exec -i ctr-mysql mysql -u root -p login_domain < /bskp-des/ctr-utils-DES/scripts/odbc/create_test_table.sql
```

### Dependencias do cliente
Para rodar `/bskp-des/ctr-utils-DES/scripts/odbc/import_csv.sh` na maquina host, e necessario ter o cliente `mysql` instalado e acessivel no `PATH`.

### Notas de seguranca
- Evite passar senha em linha de comando. O script usa `MYSQL_PASSWORD` via variavel de ambiente (nao aparece no `ps`).
- Recomenda-se criar um usuario dedicado com privilegios minimos ao inves de usar `root`.
- O script usa `LOAD DATA LOCAL INFILE`, que deve ser permitido apenas para servidores confiaveis.
