#!/bin/bash
set -x

if ! [[ -d obj ]]; then
  mkdir obj
fi

cd "src"
../dasm applz.s -l../obj/applz.lst -f3 -o../obj/applz
cd ".."

#---------------------------------------
# Copy all project files
# (needed for RPW65 debugger)
#---------------------------------------

ROOT=`pwd`
PROJECTS="$ROOT/../dbug/projects"

if ! [[ -d "$PROJECTS" ]]; then
  mkdir $PROJECTS
fi

PROJ="$PROJECTS/applz"

if ! [[ -d "$PROJ" ]]; then
  mkdir $PROJ
fi

cp obj/applz $PROJ
cp obj/applz.lst $PROJ
cp project-applz.json $PROJ

#---------------------------------------
