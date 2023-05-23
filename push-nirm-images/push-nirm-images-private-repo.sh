#!/usr/bin/bash
echo
read -p 'Enter private repository name: ' PRIVATE_REPO_NAME
read -p 'Enter private repository username: ' PRIVATE_REPO_USERNAME
read -sp 'Enter private repository Password: ' PRIVATE_REPO_PASSWORD 
echo
​
​
NIRMATA_REPO_NAME=ghcr.io
NIRMATA_REPO_USERNAME=nirmata-deployment
NIRMATA_REPO_PASSWORD=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
NIRMATA_TAG=4.8.1
​
echo "login to Nirmata image repository $NIRMATA_REPO_NAME ..."
docker login ${NIRMATA_REPO_NAME} -u ${NIRMATA_REPO_USERNAME} -p ${NIRMATA_REPO_PASSWORD}
echo
​
echo "login to private image repository $PRIVATE_REPO_NAME ..."
docker login ${PRIVATE_REPO_NAME} -u ${PRIVATE_REPO_USERNAME} -p ${PRIVATE_REPO_PASSWORD}
echo
​
NIRMATA_SERVICES="activity catalog client-gateway cluster config environments haproxy host-gateway orchestrator policies security nirmata-static-files users webclient nirmata-tunnel-server"
​
for nirmata_service in ${NIRMATA_SERVICES}
do
   echo "uploading ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} in private repository ..."
   docker pull ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}
   docker tag ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} 
   docker push ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} 
   echo 
done
​
echo "uploading ghcr.io/nirmata/kafka:3.3.2 in private repository ..."
docker pull ghcr.io/nirmata/kafka:3.3.2 
docker tag ghcr.io/nirmata/kafka:3.3.2  ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2
docker push ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2
echo
​
echo "uploading ghcr.io/nirmata/mongodb:5.0.15 in private repository ..."
docker pull ghcr.io/nirmata/mongodb:5.0.15
docker tag  ghcr.io/nirmata/mongodb:5.0.15 ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15
docker push ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15
echo
​
echo "uploading ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15 in private repository ..."
docker pull ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15
docker tag  ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15 ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15
docker push ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15
echo
​
echo "uploading ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3 in private repository ..."
docker pull ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3
docker tag ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3 ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3 
docker push ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3 
echo
