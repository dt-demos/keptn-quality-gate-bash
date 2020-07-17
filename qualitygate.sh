#!/usr/bin/env bash

DEBUG=${DEBUG:="false"}
PROCESS_TYPE=${PROCESS_TYPE:="ignore"}

# Required parameters
KEPTN_URL=${KEPTN_URL:?'KEPTN_URL ENV variable missing.'}
KEPTN_TOKEN=${KEPTN_TOKEN:?'KEPTN_TOKEN ENV variable missing.'}
START=${START:?'START ENV variable missing.'}
END=${END:?'END ENV variable missing.'}
PROJECT=${PROJECT:?'PROJECT ENV variable missing.'}
SERVICE=${SERVICE:?'SERVICE ENV variable missing.'}
STAGE=${STAGE:?'STAGE ENV variable missing.'}
SOURCE=${SOURCE:?'SOURCE ENV variable is missing'}

echo "================================================================="
echo "Keptn Quality Gate:"
echo ""
echo "KEPTN_URL      = $KEPTN_URL"
echo "START          = $START"
echo "END            = $END"
echo "PROJECT        = $PROJECT"
echo "SERVICE        = $SERVICE"
echo "STAGE          = $STAGE"
echo "LABELS         = $LABELS"
echo "SOURCE         = $SOURCE"
echo "PROCESS_TYPE   = $PROCESS_TYPE"
echo "================================================================="

# build up POST_BODY variable
POST_BODY="{\"data\":{"
POST_BODY="${POST_BODY}\"start\":\"${START}\","
POST_BODY="${POST_BODY}\"end\":\"${END}\","
POST_BODY="${POST_BODY}\"project\":\"${PROJECT}\","
POST_BODY="${POST_BODY}\"service\":\"${SERVICE}\","
POST_BODY="${POST_BODY}\"stage\":\"${STAGE}\","
POST_BODY="${POST_BODY}\"teststrategy\":\"manual\""
[ ! -z "$LABELS" ] && POST_BODY="${POST_BODY},\"labels\":${LABELS}"
# add the closing bracket
POST_BODY="${POST_BODY}},"
POST_BODY="${POST_BODY}\"type\":\"sh.keptn.event.start-evaluation\","
POST_BODY="${POST_BODY}\"source\":\"${SOURCE}\"}"

if [[ "${DEBUG}" == "true" ]]; then
  echo "KEPTN_URL = $KEPTN_URL"
  echo "---"
  echo "POST_BODY = $POST_BODY"
  echo "---"
  ARGS+=( --verbose )
fi

echo "Sending start Keptn Evaluation"
ctxid=$(curl -s -k -X POST --url "${KEPTN_URL}/v1/event" -H "Content-type: application/json" -H "x-token: ${KEPTN_TOKEN}" -d "$POST_BODY"|jq -r ".keptnContext")

if [ -z "${ctxid}" ]; then
  echo "Aborting: keptnContext ID not returned"
  exit 1
else
  echo "keptnContext ID = $ctxid"
fi

loops=20
i=0
while [ $i -lt $loops ]
do
    i=`expr $i + 1`
    result=$(curl -s -k -X GET "${KEPTN_URL}/v1/event?keptnContext=${ctxid}&type=sh.keptn.events.evaluation-done" -H "accept: application/json" -H "x-token: ${KEPTN_TOKEN}")
    status=$(echo $result|jq -r ".data.evaluationdetails.result")
    if [ "$status" = "null" ]; then
      echo "Waiting for results (attempt $i of 20)..."
      sleep 10
    else
      break
    fi
done

filename=quality-gate-result.json
echo "Writing results to file $filename."
echo $result|jq > $filename
cat $filename

echo "================================================================="
echo "eval status = ${status}"
echo "eval result = $(echo $result|jq)"
echo "================================================================="

# determine if process the result
if [ "${PROCESS_TYPE}" != "pass_on_warning" ] && [ "${PROCESS_TYPE}" != "fail_on_warning" ]; then
  exit
fi

if [ "$status" = "pass" ]; then
  success "Keptn Quality Gate - Evaluation Succeeded"
elif [ "$status" = "warning" ]; then
  if [ "${PROCESS_TYPE}" == "fail_on_warning" ]; then
    echo "Keptn Quality Gate - Got Warning status. Evaluation failed!"
    echo "For details visit the Keptn Bridge!"
    exit 1
  else
    echo "Keptn Quality Gate - Evaluation Succeeded with Warning"
  fi
else
  echo "Keptn Quality Gate - Got Fail status. Evaluation failed!"
  echo "For details visit the Keptn Bridge!"
  exit 1
fi
