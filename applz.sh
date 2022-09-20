#!/bin/bash
set -x
./dasm applz.s -lapplz.lst -f3 -oapplz
cp applz ../dbug/applz
cp applz.lst ../dbug/applz
