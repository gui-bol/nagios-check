#!/bin/bash

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

# Function to fetch the latest tag from Docker Hub
get_latest_tag() {
  local image=$1
  local repo=${image%/*}
  local name=${image##*/}
  # Handle library images (e.g., "nginx" -> "library/nginx")
  [[ "$repo" == "$name" ]] && repo="library"

  # Fetch the latest tag
  curl -s "https://hub.docker.com/v2/repositories/${repo}/${name}/tags?page_size=1&ordering=last_updated" | jq -r '.results[0].name'
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

# Compare each running image with the latest tag on Docker Hub
for IMAGE in $RUNNING_IMAGES; do
  IMAGE_NAME=${IMAGE%:*}
  IMAGE_TAG=${IMAGE#*:}
  [[ "$IMAGE_NAME" == "$IMAGE_TAG" ]] && IMAGE_TAG="latest"

  # Get the latest tag from Docker Hub
  LATEST_TAG=$(get_latest_tag "$IMAGE_NAME")

  # Check if we could fetch the latest tag
  if [ -z "$LATEST_TAG" ]; then
    OUTPUT+="CRITICAL: Unable to fetch the latest tag for $IMAGE from Docker Hub.\n"
    STATUS="$NAGIOS_CRITICAL"
    continue
  fi

  # Compare the running tag with the latest tag
  if [[ "$IMAGE_TAG" != "$LATEST_TAG" ]]; then
    OUTPUT+="WARNING: Running image $IMAGE is outdated (latest: $IMAGE_NAME:$LATEST_TAG).\n"
    STATUS="$NAGIOS_WARNING"
  else
    OUTPUT+="OK: Running image $IMAGE is up-to-date.\n"
  fi
done

# Print the output
echo -e "$OUTPUT"
exit $STATUS