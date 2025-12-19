#!/bin/bash

# Remove todos os arquivos .log em /var/log (não recursivo)
find /var/log -maxdepth 1 -type f -name "*.log" -exec rm -f {} \;

# Opcional: limpa arquivos .log também em subpastas
# find /var/log -type f -name "*.log" -exec rm -f {} \;

exit 0
