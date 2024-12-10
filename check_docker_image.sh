#!/bin/bash

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

# Function to fetch Docker Hub tag info
get_docker_hub_tag() {
  local image=$1
  local tag=$2
  local repo=${image%/*}
  local name=${image##*/}
  # Handle library images (e.g., "nginx" -> "library/nginx")
  [[ "$repo" == "$name" ]] && repo="library"
  curl -s "https://hub.docker.com/v2/repositories/${repo}/${name}/tags/${tag}" | jq -r '.last_updated'
}

# Get all running Docker containers' images
RUNNING_IMAGES=$(docker ps --format '{{.Image}}' | sort | uniq)

# Check if no containers are running
if [ -z "$RUNNING_IMAGES" ]; then
  echo "OK: No running containers found."
  exit $NAGIOS_OK
fi

# Initialize status
STATUS="$NAGIOS_OK"
OUTPUT=""

# Compare each running image with Docker Hub
for IMAGE in $RUNNING_IMAGES; do
  IMAGE_NAME=${IMAGE%:*}
  IMAGE_TAG=${IMAGE#*:}
  [[ "$IMAGE_NAME" == "$IMAGE_TAG" ]] && IMAGE_TAG="latest"

  # Get last updated timestamp from Docker Hub
  HUB_VERSION=$(get_docker_hub_tag "$IMAGE_NAME" "$IMAGE_TAG")

  # Check if we could fetch the Hub version
  if [ -z "$HUB_VERSION" ]; then
    OUTPUT+="CRITICAL: Unable to fetch info for $IMAGE from Docker Hub.\n"
    STATUS="$NAGIOS_CRITICAL"
    continue
  fi

  # Compare versions (use timestamps or other logic if preferred)
  OUTPUT+="OK: Running $IMAGE matches Docker Hub.\n"
done

# Print the output
echo -e "$OUTPUT"
exit $STATUS
