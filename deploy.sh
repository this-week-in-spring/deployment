#!/usr/bin/env bash

set -e
set -o pipefail

source $HOME/Desktop/twis-env.sh




function static_ip(){
  NS=$1
  APP=$2
  RESERVED_IP_NAME=${NS}-twi-${APP}-ip
  gcloud compute addresses list --format json | jq '.[].name' -r | grep $RESERVED_IP_NAME || gcloud compute addresses create $RESERVED_IP_NAME --global
}

# twis-twi-api-ip
static_ip $GKE_NS api
static_ip $GKE_NS studio

function deploy_new_gke_cluster() {
  gcloud --quiet beta container --project $GKE_PROJECT_ID clusters create "${GKE_CLUSTER_NAME}" \
    --zone "$GCLOUD_ZONE" --no-enable-basic-auth \
    --metadata disable-legacy-endpoints=true --scopes "compute-rw,gke-default" \
    --machine-type "e2-medium" --image-type "COS" --disk-type "pd-standard" --disk-size "100" \
    --enable-stackdriver-kubernetes --enable-ip-alias \
    --no-enable-master-authorized-networks \
    --addons ConfigConnector,HorizontalPodAutoscaling,HttpLoadBalancing \
    --enable-autoupgrade --enable-autorepair \
    --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
    --workload-pool=${GKE_PROJECT_ID}.svc.id.goog
}

gcloud container clusters list | grep $GKE_CLUSTER_NAME || deploy_new_gke_cluster

echo "Deploying This Week In..."
SECRETS_FN=twi-configmap.env
cat <<EOF >${SECRETS_FN}
VUE_APP_SERVICE_ROOT=https://bookmark-api.twis.online/
SPRING_R2DBC_USERNAME=$DB_USER
SPRING_R2DBC_PASSWORD=$DB_PW
SPRING_R2DBC_URL=r2dbc:postgres://$DB_HOST/$DB_DB
EOF

kubectl get ns/$GKE_NS || kubectl create ns $GKE_NS

KF=kustomization.yaml
cp $KF old.yaml
sed "s|<NS>|${GKE_NS}|" old.yaml >$KF
kubectl apply -k .
mv old.yaml $KF
rm $SECRETS_FN
