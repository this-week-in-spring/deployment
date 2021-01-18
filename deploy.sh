#!/usr/bin/env bash

set -e
set -o pipefail


jobs=("feed-ingest-cronjob" "twitter-ingest-cronjob" "bookmark-ingest-cronjob")

##
##
## these values should come from the CI env's secrets!
# source $HOME/Desktop/twis-env.sh
##
##
function static_ip() {
  NS=$1
  APP=$2
  RESERVED_IP_NAME=${NS}-twi-${APP}-ip
  gcloud compute addresses list --format json | jq '.[].name' -r | grep $RESERVED_IP_NAME || gcloud compute addresses create $RESERVED_IP_NAME --global
}

function create_job(){
  CJ=$1
  NCJ=cronjob.batch/$CJ
  kubectl create job --from=$NCJ ${CJ}-job  || echo "Could not create a new cronjob.batch from $NCJ"
}

function clean_job(){
  CJ=$1
  JOB_ID=$2
  kubectl get jobs/${JOB_ID} && kubectl delete jobs/${JOB_ID} || echo "No jobs for cronjob/$CJ to delete.";
}


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


echo "Deploying This Week In..."


static_ip $GKE_NS api
static_ip $GKE_NS studio

gcloud container clusters list | grep $GKE_CLUSTER_NAME || deploy_new_gke_cluster

SECRETS_FN=twi-configmap.env

cat <<EOF >${SECRETS_FN}
VUE_APP_SERVICE_ROOT=https://bookmark-api.twis.online/
PINBOARD_TOKEN=$PINBOARD_TOKEN
SPRING_R2DBC_URL=r2dbc:postgres://$DB_HOST/$DB_DB
SPRING_R2DBC_USERNAME=$DB_USER
SPRING_R2DBC_PASSWORD=$DB_PW
SPRING_DATASOURCE_URL=jdbc:postgresql://$DB_HOST/$DB_DB
SPRING_DATASOURCE_USERNAME=$DB_USER
SPRING_DATASOURCE_PASSWORD=$DB_PW
INGEST_TAGS=$INGEST_TAGS
INGEST_INGESTED_TAG=$INGEST_INGESTED_TAG
SPRING_REDIS_HOST=${REDIS_HOST}
SPRING_REDIS_PASSWORD=${REDIS_PW}
SPRING_REDIS_PORT=${REDIS_PORT}
TWITTER_TWI_CLIENT_KEY_SECRET=${TWITTER_TWI_CLIENT_KEY_SECRET}
TWITTER_TWI_CLIENT_KEY=${TWITTER_TWI_CLIENT_KEY}
EOF


kubectl get ns/$GKE_NS || kubectl create ns $GKE_NS
# kubectl get cronjobs | cut -f1 -d\  | tail -n3  | while read l ; do k delete cronjobs/$l ; done 
# kubectl get jobs | cut -f1 -d\  | tail -n3  | while read l ; do k delete jobs/$l ; done  



KF=kustomization.yaml
cp $KF old.yaml
sed "s|<NS>|${GKE_NS}|" old.yaml >$KF
kubectl apply -k .
mv old.yaml $KF
rm $SECRETS_FN
 
sleep 2   
for job in ${jobs[@]} ;  do 
  create_job $job ${job}_cronjob
done

# run_job feed-ingest-cronjob fic
# run_job twitter-ingest-cronjob tic
# run_job bookmark-ingest-cronjob bic

echo "Deployed This Week In..."