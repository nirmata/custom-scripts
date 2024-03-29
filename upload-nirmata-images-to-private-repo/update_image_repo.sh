#!/usr/bin/bash
echo
read -p 'Enter private repository name: ' PRIVATE_REPO_NAME
read -p 'Enter private repository username: ' PRIVATE_REPO_USERNAME
read -sp 'Enter private repository Password: ' PRIVATE_REPO_PASSWORD
read -sp 'Enter Nirmata repository Password: ' NIRMATA_REPO_PASSWORD

echo
NIRMATA_REPO_NAME=ghcr.io
NIRMATA_REPO_USERNAME=deployment
#NIRMATA_REPO_PASSWORD=
NIRMATA_TAG=4.8.1
echo "login to Nirmata image repository $NIRMATA_REPO_NAME ..."
docker login ${NIRMATA_REPO_NAME} -u ${NIRMATA_REPO_USERNAME} -p ${NIRMATA_REPO_PASSWORD}
echo
echo "login to private image repository $PRIVATE_REPO_NAME ..."
docker login ${PRIVATE_REPO_NAME} -u ${PRIVATE_REPO_USERNAME} -p ${PRIVATE_REPO_PASSWORD}
echo
NIRMATA_SERVICES="activity catalog client-gateway cluster config environments haproxy host-gateway orchestrator policies security nirmata-static-files users webclient nirmata-tunnel-server"
for nirmata_service in ${NIRMATA_SERVICES}
do
   echo "Pulling image ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} from Nirmata repository ..."
   docker pull ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}
   echo "Tagging downloaded image ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} to ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}"
   docker tag ${NIRMATA_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}
   echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG} to private repository ..."
   docker push ${PRIVATE_REPO_NAME}/nirmata/${nirmata_service}:${NIRMATA_TAG}
   echo
done

echo "Pulling image ghcr.io/nirmata/kafka:3.3.2 from Nirmata repository ..."
docker pull ghcr.io/nirmata/kafka:3.3.2
echo "Tagging downloaded image ghcr.io/nirmata/kafka:3.3.2 to ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2"
docker tag ghcr.io/nirmata/kafka:3.3.2  ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/kafka:3.3.2

echo
echo "Pulling image ghcr.io/nirmata/mongodb:5.0.15 from Nirmata repository ..."
docker pull ghcr.io/nirmata/mongodb:5.0.15
echo "Tagging downloaded image ghcr.io/nirmata/mongodb:5.0.15 to ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15"
docker tag  ghcr.io/nirmata/mongodb:5.0.15 ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/mongodb:5.0.15

echo
echo "Pulling image ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15 from Nirmata repository ..."
docker pull ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15
echo "Tagging downloaded image ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15 to ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15"
docker tag  ghcr.io/nirmata/mongo-k8s-sidecar:5.0.15 ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/mongo-k8s-sidecar:5.0.15

echo
echo "Pulling image ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3 from Nirmata repository ..."
docker pull ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3
echo "Tagging downloaded image ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3 to ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3"
docker tag ghcr.io/nirmata/kubernetes-zookeeper:v3-zk3.6.3 ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/kubernetes-zookeeper:v3-zk3.6.3
echo

echo
echo "Pulling image ghcr.io/nirmata/enterprise-kyverno-operator:v0.1.7 from Nirmata repository ..."
docker pull ghcr.io/nirmata/enterprise-kyverno-operator:v0.1.7
echo "Tagging downloaded image ghcr.io/nirmata/enterprise-kyverno-operator:v0.1.7 to ${PRIVATE_REPO_NAME}/nirmata/enterprise-kyverno-operator:v0.1.7"
docker tag ghcr.io/nirmata/enterprise-kyverno-operator:v0.1.7 ${PRIVATE_REPO_NAME}/nirmata/enterprise-kyverno-operator:v0.1.7
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/enterprise-kyverno-operator:v0.1.7 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/enterprise-kyverno-operator:v0.1.7
echo

echo
echo "Pulling image ghcr.io/nirmata/kyverno-license-manager:v0.0.2 from Nirmata repository ..."
docker pull ghcr.io/nirmata/kyverno-license-manager:v0.0.2
echo "Tagging downloaded image ghcr.io/nirmata/kyverno-license-manager:v0.0.2 to ${PRIVATE_REPO_NAME}/nirmata/kyverno-license-manager:v0.0.2"
docker tag ghcr.io/nirmata/kyverno-license-manager:v0.0.2 ${PRIVATE_REPO_NAME}/nirmata/kyverno-license-manager:v0.0.2
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/kyverno-license-manager:v0.0.2 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/kyverno-license-manager:v0.0.2
echo

echo
echo "Pulling image ghcr.io/nirmata/kyverno:v1.9.2-n4k.nirmata.1 from Nirmata repository ..."
docker pull ghcr.io/nirmata/kyverno:v1.9.2-n4k.nirmata.1
echo "Tagging downloaded image ghcr.io/nirmata/kyverno:v1.9.2-n4k.nirmata.1 to ${PRIVATE_REPO_NAME}/nirmata/kyverno:v1.9.2-n4k.nirmata.1"
docker tag ghcr.io/nirmata/kyverno:v1.9.2-n4k.nirmata.1 ${PRIVATE_REPO_NAME}/nirmata/kyverno:v1.9.2-n4k.nirmata.1
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/kyverno:v1.9.2-n4k.nirmata.1 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/kyverno:v1.9.2-n4k.nirmata.1
echo

echo
echo "Pulling image ghcr.io/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1 from Nirmata repository ..."
docker pull ghcr.io/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1
echo "Tagging downloaded image ghcr.io/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1 to ${PRIVATE_REPO_NAME}/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1"
docker tag ghcr.io/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1 ${PRIVATE_REPO_NAME}/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/kyvernopre:v1.9.2-n4k.nirmata.1
echo

echo
echo "Pulling image ghcr.io/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1 from Nirmata repository ..."
docker pull ghcr.io/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1
echo "Tagging downloaded image ghcr.io/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1 to ${PRIVATE_REPO_NAME}/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1"
docker tag ghcr.io/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1 ${PRIVATE_REPO_NAME}/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/cleanup-controller:v1.9.2-n4k.nirmata.1
echo

echo
echo "Pulling image ghcr.io/nirmata/metrics-agent:0.38.2 from Nirmata repository ..."
docker pull ghcr.io/nirmata/metrics-agent:0.38.2
echo "Tagging downloaded image ghcr.io/nirmata/metrics-agent:0.38.2 to ${PRIVATE_REPO_NAME}/nirmata/metrics-agent:0.38.2"
docker tag ghcr.io/nirmata/metrics-agent:0.38.2 ${PRIVATE_REPO_NAME}/nirmata/metrics-agent:0.38.2
echo "Uploading image ${PRIVATE_REPO_NAME}/nirmata/metrics-agent:0.38.2 to private repository ..."
docker push ${PRIVATE_REPO_NAME}/nirmata/metrics-agent:0.38.2
echo
