#!/bin/bash

COUNT=${1-1}

docker build -t jmeter-base jmeter-base
docker-compose build && docker-compose up -d && docker-compose scale master=1 slave=$COUNT

SLAVE_IP=$(docker inspect -f '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq) | grep slave | awk -F' ' '{print $2}' | tr '\n' ',' | sed 's/.$//')
WDIR=`docker exec -t master /bin/pwd | tr -d '\r'`
mkdir -p results
for filename in scripts/*.jmx; do
    NAME=$(basename $filename)
    NAME="${NAME%.*}"
    eval "docker cp $filename master:$WDIR/scripts/"
    eval "docker exec -t master /bin/bash -c 'mkdir $NAME && cd $NAME && ../bin/jmeter -Jjmeter.save.saveservice.output_format=xml -Jjmeter.save.saveservice.response_data=true -Jjmeter.save.saveservice.samplerData=true -Jjmeter.save.saveservice.requestHeaders=true -Jjmeter.save.saveservice.url=true -Jjmeter.save.saveservice.responseHeaders=true -n -t ../$filename -R$SLAVE_IP'"
    eval "docker cp master:$WDIR/$NAME results/"
done

docker-compose stop && docker-compose rm -f