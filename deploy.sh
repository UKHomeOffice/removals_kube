#!/bin/sh
set -e
cd "`dirname $0`"

export KUBE_SERVER=https://kube-dev.dsp.notprod.homeoffice.gov.uk
export ENVIRON=dev
export KUBE_NAMESPACE=ircbd-${ENVIRON}
export INSECURE_SKIP_TLS_VERIFY=true

export KEYCLOAK_DISCOVERY=https://keycloak.digital.homeoffice.gov.uk/auth/realms/ircbd
export KEYCLOAK_CLIENT_ID=ircbd-dev

export API_URL=api-ircbd.notprod.homeoffice.gov.uk
export WALLBOARD_URL=wallboard-ircbd.notprod.homeoffice.gov.uk

NEED_MYSQL="eph dev int"

NEED_REDIS="eph dev int uat prod"

if [ ${DEPlOY_MYSQL} ]; then
  kd -f kube/mysql/deployment.yml -f kube/mysql/service.yml
fi

if [ ${DEPLOY_REDIS} ]; then
  kd -f kube/redis/deployment.yml -f kube/redis/service.yml
fi

if [ ${DEPLOY_SELENIUM} ]; then
  kd -f kube/e2etest/deployment.yml -f kube/e2etest/service.yml
fi


if [ ${DEPLOY_API} ]; then
  kd \
    -f kube/api/task.yml \
    -f kube/api/deployment.yml \
    -f kube/api/service.yml \
    -f kube/api/ingress.yml
fi

if ${DEPLOY_WALLBOARD}; then
  kd \
  -f kube/wallboard/deployment.yml \
  -f kube/wallboard/service.yml \
  -f kube/wallboard/ingress.yml
fi


if ${RUN_TESTS}; then
  kd \
  -f kube/e2etest/task.yml
# @TODO check the test results
fi
