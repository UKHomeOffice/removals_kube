#!/bin/sh
set -e

echo "------ ${WHAT} deploy to ${DRONE_DEPLOY_TO} with ${IMAGE_NAME} on ${BRANCH} ------"

BRANCH_SAFE=$(echo ${BRANCH} | sed -e "s/\//_/g")

export KUBE_SERVER=https://kube-dev.dsp.notprod.homeoffice.gov.uk
export KUBE_NAMESPACE=ircbd-${DRONE_DEPLOY_TO}

export INSECURE_SKIP_TLS_VERIFY=true

export KEYCLOAK_DISCOVERY=https://keycloak.digital.homeoffice.gov.uk/auth/realms/ircbd
export KEYCLOAK_CLIENT_ID=ircbd-dev

RANDOM_STRING=$(head /dev/urandom | tr -dc a-z0-9 | head -c 13)


### --- DEFAULT SETTINGS --- ###
export API_URL=api-ircbd-${DRONE_DEPLOY_TO}.notprod.homeoffice.gov.uk
export WALLBOARD_URL=wallboard-ircbd-${DRONE_DEPLOY_TO}.notprod.homeoffice.gov.uk



#export KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET_${DRONE_DEPLOY_TO}}

export DBNAME=removals
export DBUSER=root
export DBPASS=foobar
export DBHOST=mysql
export DBPORT=3306

### --- PRODUCTION SETTINGS --- ###
if [ $DRONE_DEPLOY_TO = "prod" ]; then
  export KUBE_TOKEN=${KUBE_TOKEN_PROD}
  export KUBE_SERVER=https://kube.dsp.digital.homeoffice.gov.uk
  export API_URL=api.ircbd.homeoffice.gov.uk
  export WALLBOARD_URL=wallboard.ircbd.homeoffice.gov.uk
fi


### --- EPHEMERAL SETTINGS --- ###
if [ $DRONE_DEPLOY_TO = "ephemeral" ]; then
  export KUBE_NAMESPACE=ircbd-${RANDOM_STRING}
  export KUBE_SERVER=${KUBE_SERVER_CI}
  export KUBE_TOKEN=${KUBE_TOKEN_CI}

  kubectl create namespace ${KUBE_NAMESPACE} --insecure-skip-tls-verify=true --server=${KUBE_SERVER} --token=${KUBE_TOKEN}

  DEPLOY_API=TRUE
  DEPLOY_WALLBOARD=TRUE
  RUN_TESTS=TRUE

  export API_URL=api-ircbd-${RANDOM_STRING}.notprod.homeoffice.gov.uk
  export WALLBOARD_URL=wallboard-ircbd-${RANDOM_STRING}.notprod.homeoffice.gov.uk

  kd -f kube/e2etest/deployment.yml -f kube/e2etest/service.yml
fi

### we use RDS in UAT/PROD so don't need a mysql server there ###
if [ $DRONE_DEPLOY_TO != "prod" -a $DRONE_DEPLOY_TO != "uat" ]; then
  kd -f kube/mysql/deployment.yml -f kube/mysql/service.yml
fi


if [ $WHAT = api ]; then
  DEPLOY_API=TRUE
  export API_IMAGE=${IMAGE_NAME}
fi

if [ $WHAT = wallboard ]; then
  DEPLOY_WALLBOARD=TRUE
  export WALLBOARD_IMAGE=${IMAGE_NAME}
fi


if [ ${DEPLOY_API} ]; then
  if [ -z ${API_IMAGE} ]; then
    if [ $(wget -sq https://quay.io/c1/squash/ukhomeofficedigital/removals-integration/${BRANCH_SAFE}) ]; then
      export API_IMAGE=quay.io/ukhomeofficedigital/removals-integration:${BRANCH_SAFE}
    else
      export API_IMAGE=quay.io/ukhomeofficedigital/removals-integration:origin_master
    fi
  fi
  echo "Deploying API ${API_IMAGE} to ${API_URL}"
  kd \
    -f kube/redis/deployment.yml \
    -f kube/redis/service.yml \
    -f kube/api/task.yml \
    -f kube/api/deployment.yml \
    -f kube/api/service.yml \
    -f kube/api/ingress.yml
fi

if [ ${DEPLOY_WALLBOARD}  ]; then
  if [ -z ${WALLBOARD_IMAGE} ]; then
    if [ $(wget -sq https://quay.io/c1/squash/ukhomeofficedigital/removals-wallboard/${BRANCH_SAFE}) ]; then
      export WALLBOARD_IMAGE=quay.io/ukhomeofficedigital/removals-wallboard:${BRANCH_SAFE}
    else
      export WALLBOARD_IMAGE=quay.io/ukhomeofficedigital/removals-wallboard:origin_master

    fi
  fi
  echo "Deploying WALLBOARD ${WALLBOARD_IMAGE} to ${WALLBOARD_URL}"
  kd \
  -f kube/wallboard/deployment.yml \
  -f kube/wallboard/service.yml \
  -f kube/wallboard/ingress.yml
fi

if [ $DRONE_DEPLOY_TO = "ephemeral" ]; then
  kubectl delete namespace ${KUBE_NAMESPACE} --insecure-skip-tls-verify=true --server=${KUBE_SERVER} --token=${KUBE_TOKEN}
fi


if [ ${RUN_TESTS} ]; then
  kd \
  -f kube/e2etest/task.yml
# @TODO check the test results
fi
