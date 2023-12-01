@echo off

runas /user:%* && exit
pause
exit 1
