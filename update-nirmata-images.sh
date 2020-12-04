#!/bin/bash -x 

version="pe-2.11.8"
prefix="foo:4403"

containers="index.docker.io/nirmata/haproxy index.docker.io/nirmata/activity index.docker.io/nirmata/catalog index.docker.io/nirmata/client-gateway index.docker.io/nirmata/cluster index.docker.io/nirmata/config index.docker.io/nirmata/environments index.docker.io/nirmata/host-gateway index.docker.io/nirmata/orchestrator index.docker.io/nirmata/security index.docker.io/nirmata/nirmata-static-files index.docker.io/nirmata/nirmata-tunnel-server index.docker.io/nirmata/users index.docker.io/nirmata/webclient index.docker.io/nirmata/kafka index.docker.io/nirmata/mongodb index.docker.io/nirmata/mongo-k8s-sidecar index.docker.io/nirmata/zookeeper"


for container in $containers; do
 container="$container:$version"
 docker pull $container
 new_container=$(echo $container |sed s/index.docker.io/$prefix/)
 docker tag $container $new_container
 docker push $new_container
done
