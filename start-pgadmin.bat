@echo off

docker network ls | findstr "agens"

if ERRORLEVEL 1 docker network create agens

docker container ls | findstr "pgadmin"

if ERRORLEVEL 0 docker container kill pgadmin

docker run -d --rm -p 5050:5050 --net agens --name pgadmin -v %~dp0/pgadmin thajeztah/pgadmin4