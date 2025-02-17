#!/bin/bash

APP_NAME=moodle
PATH_ROOT=/app
COMMAND=""

# Seta o diretório do moodle
DIR_MOODLE=$PATH_ROOT/$APP_NAME

# Altera proprietários das pastas
chown customuser:docker -R $DIR_MOODLE

# Array de subpastas que precisam de permissão de escrita
FOLDERS=("availability" "blocks" "course" "enrol" "filter" "grade" "lib" "local" "mod" "plagiarism" "question" "report" "theme" "user" "admin/tool")

# Aplica permissões gerais nas pastas
chmod 2770 -R $DIR_MDATA
chmod 2750 -R $DIR_MOODLE
chmod 2740 -R $DIR_MOODLE/admin/cli

# Retorna a quantidade de subpastas
NUMBER_FOLDERS=${#FOLDERS[@]}

# Cria linha de comando para aplicar permissão de escrita
for ((i=0; i<$NUMBER_FOLDERS; i++))
do
  LINE="chmod 770 -R $DIR_MOODLE/${FOLDERS[i]}"
  if test $i -eq 0
  then
    COMMAND+=$LINE
  else
    COMMAND+=" && $LINE"
  fi
  LINE=""
done

# Executa a linha de comando para atribuir permissões nas subpastas
echo $($COMMAND)
