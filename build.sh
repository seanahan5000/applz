#!/bin/bash
set -x

if ! [[ -d obj ]]; then
  mkdir obj
fi

./dasm applz.s -lobj/applz.lst -f3 -oobj/applz

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
