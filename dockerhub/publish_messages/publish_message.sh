#!/usr/bin/env sh

endpoint_url="http://localstack:443"

if jq --version > /dev/null 2>&1 ; then
  echo "jq exists and version is  $(jq --version)"
else
  echo "installing jq"
  apk update && apk add --no-cache jq
fi

sns_arn=$(aws --endpoint-url="${endpoint_url}" sns list-topics |  jq '.Topics[].TopicArn' --raw-output)
echo "local-stack sqs arn is ${sns_arn}"

# subscribing to FHS messages
publish_to_sns(){
  endpoint_url=$1
  sns_arn="$2"
  sample_trigger_json_message_1="$3"
  response=$(aws --endpoint-url="${endpoint_url}" sns publish \
            --topic-arn "${sns_arn}" --message "${sample_trigger_json_message_1}" 2>/dev/null)
  if [ $? -eq 0 ];
  then
    msg_id=$(echo "${response}" | jq '.MessageId' --raw-output)
    echo "Sample message published with message id ${msg_id}"
  else
    echo "Check your input message"
    exit 1
  fi
}

# shellcheck disable=SC2012
nr_files=$(ls -1 /mockup_messages/*.json 2>&1 | wc -l)
echo "Number of files ${nr_files}"
if [ "${nr_files}" != 0 ];
then
  for f in /mockup_messages/*.json;
  do
    echo "Publishing sample trigger message found in file ${f}"
    type=$(cat ${f} | jq type)
    echo "JSON Message structure is an: ${type}"
    jq -cn --stream 'fromstream(1|truncate_stream(inputs))' --raw-output < "${f}" |
    while IFS= read -r line;
    do
      # echo -n "$line"
      message=$(jq -n "${line}")
      publish_to_sns "${endpoint_url}" "${sns_arn}" "${message}"
    done
  done
else
  echo -n "No Mockup JSON Messages in Mockup folder."
fi

#sns_arn=$(aws --endpoint-url="${endpoint_url}" sns list-topics |  jq '.Topics[].TopicArn' --raw-output)
#echo "local-stack sqs arn is ${sns_arn}"
## sample trigger message to be published to SNS
#sample_trigger_message_1='{"header__timestamp":"Thu Jun 10 18:40:13 GMT 2021","header__change_seq":"MANUAL__00000000_10961004trigger_aesso","header__operation":"INSERT","Trigger_NewConsumer":"{\"uid\":\"0052cf44bafd43009ff85bc83b861ff6\",\"relation-numbers\":[{\"type\":\"AKOS\",\"value\":\"10961004\"},{\"type\":\"AEGAR\",\"value\":\"2143850\"}],\"contract-sources\":[\"FHS\"]}"}'
## convert the sample trigger message to JSON
#sample_trigger_json_message_1=$(jq -n "${sample_trigger_message_1}")
#echo "Publishing sample trigger message ${sns_arn}"
#publish_to_sns "${endpoint_url}" "${sns_arn}" "${sample_trigger_json_message_1}"
## sample full-load message to be published to SNS
#sample_fl_message_1='{"header__timestamp":1623359011,"header__change_seq":"00000000000000000000000000000000","trigger_dossiernr":2929249,"header__operation":"FULL LOAD","trigger_objectkey":78932.78,"trigger_oid":78932.78}'
## convert the sample fl message into json
#sample_fl_json_message_1=$(jq -n "${sample_fl_message_1}")
#echo "Publishing sample fl message ${sns_arn}"
#publish_to_sns "${endpoint_url}" "${sns_arn}" "${sample_fl_json_message_1}"
