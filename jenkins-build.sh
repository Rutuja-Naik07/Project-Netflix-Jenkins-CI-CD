#!/bin/bash
set -eu

echo "===================================="
echo "STEP 1: Verify source code"
echo "===================================="

test -s index.html
test -s Dockerfile

echo "Website source files found."

echo "===================================="
echo "STEP 2: Build Docker image"
echo "===================================="

IMAGE="$DOCKERHUB_USER/cloud-messenger-netflix:latest"

docker build --pull -t "$IMAGE" .

echo "Docker image built successfully."

echo "===================================="
echo "STEP 3: Test the Docker image"
echo "===================================="

docker run -d --rm \
    --name cloudflix-test \
    -p 127.0.0.1:18081:80 \
    "$IMAGE"

trap 'docker stop cloudflix-test >/dev/null 2>&1 || true' EXIT

sleep 3

curl -fsS http://127.0.0.1:18081/ -o /tmp/cloudflix-test.html

if grep -qi "<html" /tmp/cloudflix-test.html; then
    echo "Website test passed."
else
    echo "ERROR: The website did not return valid HTML."
    cat /tmp/cloudflix-test.html
    exit 1
fi

docker stop cloudflix-test >/dev/null 2>&1 || true
trap - EXIT

echo "Test container cleaned up successfully."

echo "===================================="
echo "STEP 4: Login to Docker Hub"
echo "===================================="

printf '%s' "$DOCKERHUB_TOKEN" | \
    docker login \
        --username "$DOCKERHUB_USER" \
        --password-stdin

echo "Docker Hub login successful."

echo "===================================="
echo "STEP 5: Push image to Docker Hub"
echo "===================================="

docker push "$IMAGE"

docker logout

echo "Image pushed successfully."

echo "===================================="
echo "STEP 6: Deploy container"
echo "===================================="

docker rm -f cloudflix || true

docker run -d \
    --name cloudflix \
    --restart unless-stopped \
    -p 8081:80 \
    "$IMAGE"

echo "===================================="
echo "CI/CD PIPELINE COMPLETED"
echo "===================================="

docker ps --filter "name=cloudflix" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
