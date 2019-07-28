#!/bin/sh

# How to test:
#  NAMESPACE=default POD_NAME=kubesh-3976960141-b9b9t ./this_script

# Set VERBOSE=1 to get more output
POD_NAME=${POD_NAME:-""}
VERBOSE=${VERBOSE:-0}
verbose () {
  [ "${VERBOSE}" -eq 1 ] && return 0 || return 1
}

echo 'This script polls the "EC2 Spot Instance Termination Notices" endpoint to gracefully stop and then reschedule all the pods running on this Kubernetes node, up to 2 minutes before the EC2 Spot Instance backing this node is terminated.'
echo 'See https://aws.amazon.com/blogs/aws/new-ec2-spot-instance-termination-notices/ for more information.'

if [ "${NAMESPACE}" = "" ]; then
  echo '[ERROR] Environment variable `NAMESPACE` has no value set. You must set it via PodSpec like described in http://stackoverflow.com/a/34418819' 1>&2
  exit 1
fi

if [ "${POD_NAME}" = "" ]; then
  echo '[ERROR] Environment variable `POD_NAME` has no value set. You must set it via PodSpec like described in http://stackoverflow.com/a/34418819' 1>&2
  exit 1
fi

NODE_NAME=$(kubectl --namespace "${NAMESPACE}" get pod "${POD_NAME}" --output jsonpath="{.spec.nodeName}")

if [ "${NODE_NAME}" = "" ]; then
  echo "[ERROR] Unable to fetch the name of the node running the pod \"${POD_NAME}\" in the namespace \"${NAMESPACE}\". Maybe a bug?: " 1>&2
  exit 1
fi

# Do we detach the instance from the AutoScaling Group? Defaults to not do so.
DETACH_ASG=${DETACH_ASG:-false}

# Gather some information
AZ_URL=${AZ_URL:-http://169.254.169.254/latest/meta-data/placement/availability-zone}
AZ=$(curl -s "${AZ_URL}")
REGION=$(echo "${AZ}" | sed 's/[a-z]$//')
INSTANCE_ID_URL=${INSTANCE_ID_URL:-http://169.254.169.254/latest/meta-data/instance-id}
INSTANCE_ID=$(curl -s "${INSTANCE_ID_URL}")
INSTANCE_TYPE_URL=${INSTANCE_TYPE_URL:-http://169.254.169.254/latest/meta-data/instance-type}
INSTANCE_TYPE=$(curl -s "${INSTANCE_TYPE_URL}")

if [ "${DETACH_ASG}" != "false" ]; then
  ASG_NAME=$(aws --output text --query 'AutoScalingInstances[0].AutoScalingGroupName' --region "${REGION}" autoscaling describe-auto-scaling-instances --instance-ids "${INSTANCE_ID}")
fi

if [ -z "$CLUSTER" ]; then
  echo "[WARNING] Environment variable CLUSTER has no name set. You can set this to get it reported in the Slack message." 1>&2
else
  CLUSTER_INFO=" (${CLUSTER})"
fi

echo "\`kubectl drain ${NODE_NAME}\` will be executed once a termination notice is made."

POLL_INTERVAL=${POLL_INTERVAL:-5}

NOTICE_URL=${NOTICE_URL:-http://169.254.169.254/latest/meta-data/spot/termination-time}

echo "Polling ${NOTICE_URL} every ${POLL_INTERVAL} second(s)"

# To whom it may concern: http://superuser.com/questions/590099/can-i-make-curl-fail-with-an-exitcode-different-than-0-if-the-http-status-code-i
while http_status=$(curl -o /dev/null -w '%{http_code}' -sL "${NOTICE_URL}"); [ "${http_status}" -ne 200 ]; do
  verbose && echo "$(date): ${http_status}"
  sleep "${POLL_INTERVAL}"
done

# Similar Worker Count
# For added confidence that terminated worker nodes are being replaced, we can add a count of similarly-tagged EC2 instances to our message
# Enable and filter the query by setting SWC_TAG_NAME, e.g. "Name", and SWC_TAG_VALUES, e.g. "eks-worker-spot,eks-worker-ondemand"
# Note: a spot instance remains in "running" state throughout the termination notice period, after which the shutdown signal is sent
SWC_TAG_NAME=${SWC_TAG_NAME:-""}
SWC_TAG_VALUES=${SWC_TAG_VALUES:-""}
SWC_TIMEOUT=${SWC_TIMEOUT:-5}
SWC_MESSAGE="Disabled"
if [ "${SWC_TAG_NAME}" != "" ] && [ "${SWC_TAG_VALUES}" != "" ]; then
  SWC_COUNT=$(aws ec2 --cli-read-timeout $SWC_TIMEOUT --output text --query "Reservations[*].Instances[*] | length(@)" --region $REGION describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:$SWC_TAG_NAME,Values=$SWC_TAG_VALUES" 2>/dev/null)
  case $SWC_COUNT in
    ''|*[!0-9]*) SWC_MESSAGE="Failed" ;;
    *) SWC_MESSAGE="$((SWC_COUNT-1))" ;;
  esac
fi

echo "$(date): ${http_status}"
MESSAGE="Spot Termination${CLUSTER_INFO}: ${NODE_NAME}, Instance: ${INSTANCE_ID}, Instance Type: ${INSTANCE_TYPE}, AZ: ${AZ}, Surviving Worker Count: ${SWC_MESSAGE}"

# Notify Hipchat
# Set the HIPCHAT_ROOM_ID & HIPCHAT_AUTH_TOKEN variables below.
# Further instructions at https://www.hipchat.com/docs/apiv2/auth
if [ "${HIPCHAT_AUTH_TOKEN}" != "" ]; then
  curl -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HIPCHAT_AUTH_TOKEN" \
     -X POST \
     -d "{\"color\": \"purple\", \"message_format\": \"text\", \"message\": \"${MESSAGE}\" }" \
     "https://api.hipchat.com/v2/room/${HIPCHAT_ROOM_ID}/notification"
fi

# Notify Slack incoming-webhook
# Docs: https://api.slack.com/incoming-webhooks
# Setup: https://slack.com/apps/A0F7XDUAZ-incoming-webhooks
#
# You will have to set SLACK_URL as an environment variable via PodSpec.
# The URL should look something like: https://hooks.slack.com/services/T67UBFNHQ/B4Q7WQM52/1ctEoFjkjdjwsa22934
#
if [ "${SLACK_URL}" != "" ]; then
  color="danger"
  curl -X POST --data "payload={\"attachments\":[{\"fallback\":\"${MESSAGE}\",\"title\":\":warning: Spot Termination${CLUSTER_INFO}\",\"color\":\"${color}\",\"fields\":[{\"title\":\"Node\",\"value\":\"${NODE_NAME}\",\"short\":false},{\"title\":\"Instance\",\"value\":\"${INSTANCE_ID}\",\"short\":true},{\"title\":\"Instance Type\",\"value\":\"${INSTANCE_TYPE}\",\"short\":true},{\"title\":\"Availability Zone\",\"value\":\"${AZ}\",\"short\":true},{\"title\":\"Surviving Worker Count\",\"value\":\"${SWC_MESSAGE}\",\"short\":true}]}]}" "${SLACK_URL}"
fi

# Notify Email address with a Google account
# Provide: Gsuite email account and Password
#
if [ "${GMAIL_USER}" != "" ]; then
  python gmail.py --gmail-user "${GMAIL_USER}" \
                  --gmail-pass "${GMAIL_PASS}" \
                  --to-address "${GMAIL_EMAILTO}" \
                  --cluster-name "${CLUSTER_INFO}"
fi

# Notify Sematext Cloud incoming-webhook
# Docs: https://sematext.com/docs/events/#adding-events
# Setup: app
#
# You will have to set SEMATEXT_URL as an environment variable via PodSpec.
# The URL should look something like:
# - USA: https://event-receiver.sematext.com/APPLICATION_TOKEN/event
# - EUROPE: https://event-receiver.sematext.com/APPLICATION_TOKEN/event
if [ "${SEMATEXT_URL}" != "" ]; then
  curl -X POST --data "{\"message\":\"${MESSAGE}\",\"title\":\"Spot Termination ${CLUSTER_INFO}\",\"host\":\"${NODE_NAME}\",\"Instance\":\"${INSTANCE_ID}\",\"Instance Type\":\"${INSTANCE_TYPE}\", \"Availability Zone\":\"${AZ}\", \"Surviving Instance Count\":\"${SWC_MESSAGE}\", \"type\":\"aws_spot_instance_terminated\"}" "${SEMATEXT_URL}"
fi

# Detach from autoscaling group, which will cause faster replacement
# We do this in parallel with the drain (see the & at the end of the command).
if [ "${DETACH_ASG}" != "false" ] && [ "${ASG_NAME}" != "" ]; then
  verbose && echo "$(date): detaching instance from AutoScaling Group ${ASG_NAME}"
  aws --region "${REGION}" autoscaling detach-instances --instance-ids "${INSTANCE_ID}" --auto-scaling-group-name "${ASG_NAME}" --no-should-decrement-desired-capacity &
fi


# Drain the node.
# https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/#use-kubectl-drain-to-remove-a-node-from-service
GRACE_PERIOD=${GRACE_PERIOD:-120}
kubectl drain "${NODE_NAME}" --force --ignore-daemonsets --delete-local-data --grace-period="${GRACE_PERIOD}"

# Sleep for 200 seconds to prevent this script from looping.
# The instance should be terminated by the end of the sleep.
sleep 200
