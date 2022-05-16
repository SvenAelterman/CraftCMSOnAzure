#!/bin/bash
sudo /usr/sbin/sshd &
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisor.conf