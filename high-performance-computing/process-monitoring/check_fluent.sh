#!/bin/bash

LOG=/home/ansysuser/fluent_realtime_2_core.log

echo "=== START LOGGING at $(date) ===" >> $LOG

while true
do
    echo "" >> $LOG
    echo "---- $(date) ----" >> $LOG

    ps -eo pid,user,%cpu,command | grep -E "fluent|cortex" | grep -v grep >> $LOG

    sleep 1
done
