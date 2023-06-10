#!/usr/bin/env bash 
set -e
set -o pipefail

NS=$TWI_NS
CHART_NAME=twi 

function create_ip(){
    IPN=$1
    gcloud compute addresses list --format json | jq '.[].name' -r | grep $IPN || gcloud compute addresses create $IPN --global
}

function init(){
    create_ip ${NS}-twi-studio-client-ip 
    create_ip ${NS}-twi-studio-gateway-ip 
    create_ip ${NS}-twi-bookmark-api-ip 
    kubectl get ns/$NS || kubectl create namespace ${NS} 
}

function reset(){ 
    for d in ${NS}-twi-bookmark-api ${NS}-twi-studio-client ${NS}-twi-studio-gateway    
    do 
            for dn in "deployments/$d" # "managedcertificates/${d}-certificate" "ingress/${d}-ingress" "service/${d}-service"
            do
                echo "running: kubectl delete $dn "
                kubectl delete $dn || echo "could not delete $dn "
            done
    done
}

init 



HELM_COMMAND="install"
helm list -n $NS | grep $CHART_NAME  && HELM_COMMAND="upgrade" 

# todo remove this 
helm list -n $NS | grep $CHART_NAME && reset

echo "Performing a helm ${HELM_COMMAND}..."
git clone https://github.com/this-week-in/helm-charts.git my-chart 
cd my-chart
helm $HELM_COMMAND $CHART_NAME ./twi  \
 --namespace=$NS \
 --set twi.prefix=$NS \
 --set twi.domain=$TWI_DOMAIN  \
 --set twi.postgres.username=$DB_USER  \
 --set twi.postgres.password=$DB_PW  \
 --set twi.postgres.host=$DB_HOST  \
 --set twi.postgres.schema=$DB_DB  \
 --set twi.redis.host=$REDIS_HOST \
 --set twi.redis.password=$REDIS_PW \
 --set twi.redis.port=$REDIS_PORT \
 --set twi.ingest.tags.ingest=$INGEST_TAG \
 --set twi.ingest.tags.ingested=$INGESTED_TAG \
 --set twi.pinboard.token=$PINBOARD_TOKEN \
 --set twi.twitter.client_key=${TWITTER_CLIENT_KEY} \
 --set twi.twitter.client_key_secret=${TWITTER_CLIENT_KEY_SECRET} \
 --set twi.ingest.feed.mappings=$INGEST_FEED_ENCODED_MAPPINGS \
 --set twi.ingest.twitter.mappings=$INGEST_TWITTER_ENCODED_MAPPINGS \
 --set twi.oauth.client_key=$TWI_OAUTH_CLIENT_KEY \
 --set twi.oauth.client_key_secret=$TWI_OAUTH_CLIENT_KEY_SECRET \
 --set twi.oauth.issuer_uri=$TWI_OAUTH_ISSUER_URI 



# sleep 30
# kubectl create job --from=cronjob/${NS}-twi-twitter-ingest-cronjob ${NS}-twi-twitter-ingest-cronjob-${RANDOM} -n $NS 
# kubectl create job --from=cronjob/${NS}-twi-bookmark-ingest-cronjob ${NS}-twi-bookmark-ingest-cronjob-${RANDOM} -n $NS 
# kubectl create job --from=cronjob/${NS}-twi-feed-ingest-cronjob ${NS}-twi-feed-ingest-cronjob-${RANDOM} -n $NS
 
 
 
 
 
 
 
 
 
 
