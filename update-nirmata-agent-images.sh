#!/bin/bash -x 

prefix="foo:4403"
containers="nirmata/nirmata-host-agent nirmata/nirmata-host-agent:running"


for container in $containers; do
 docker pull $container
 new_container=$(echo $container |sed s/index.docker.io/$prefix/)
 docker tag $container $new_container
 docker push $new_container
done
