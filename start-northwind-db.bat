@echo off

docker build -t agensgraph -f ./docker/agensgraph/Dockerfile ./docker/agensgraph
docker build -t northwind -f ./docker/northwind/Dockerfile --no-cache ./docker/northwind

docker network ls | findstr "agens"

if ERRORLEVEL 1 docker network create agens

docker container ls | findstr "northwind"

if ERRORLEVEL 0 docker container kill northwind

docker container ls | findstr "pgadmin"

if ERRORLEVEL 0 docker container kill pgadmin

docker run -d --rm -p 5432:5432 -e POSTGRES_DB="northwind" --net agens --name northwind northwind:latest
docker run -d --rm -p 5050:5050 --net agens --name pgadmin -v %~dp0/pgadmin thajeztah/pgadmin4