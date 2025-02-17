#!/bin/bash

if [ -f /home/customuser/moodle/config.php ]; then
  PID=`pgrep -f /home/customuser/moodle/admin/cli/cron.php`
  if [ -z $PID ] ; then
    php /home/customuser/moodle/admin/cli/cron.php
  fi
fi