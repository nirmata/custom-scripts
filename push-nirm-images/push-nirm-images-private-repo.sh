#!/usr/bin/bash
echo
read -p 'Enter private repository name: ' PRIVATE_REPO_NAME
read -p 'Enter private repository username: ' PRIVATE_REPO_USERNAME
read -sp 'Enter private repository Password: ' PRIVATE_REPO_PASSWORD 
echo


NIRMATA_REPO_NAME=ghcr.io
NIRMATA_REPO_USERNAME=nirmata-deployment
#NIRMATA_REPO_PASSWORD=
read -sp 'Enter Nirmata repository Password: ' NIRMATA_REPO_PASSWORD
NIRMATA_TAG=4.3.1

echo "login to Nirmata image repository $NIRMATA_REPO_NAME ..."
docker login ${NIRMATA_REPO_NAME} -u ${NIRMATA_REPO_USERNAME} -p ${NIRMATA_REPO_PASSWORD}
echo

echo "login to private image repository $PRIVATE_REPO_NAME ..."
docker login ${PRIVATE_REPO_NAME} -u ${PRIVATE_REPO_USERNAME} -p ${PRIVATE_REPO_PASSWORD}
echo

NIRMATA_SERVICES="activity catalog client-gateway cluster config environments haproxy host-gateway orchestrator security nirmata-static-files users webclient nirmata-tunnel-server mongodb mongo-k8s-sidecar kafka kubernetes-zookeeper"

for nirmata_service in ${NIRMATA_SERVICES}
do
   echo "uploading ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} in private repository ..."
   docker pull ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}
   docker tag ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} 
   docker push ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} 
   echo 
done
echo
