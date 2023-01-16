#!/bin/bash

set -e

echo Creating image...
image="$(docker build -q .)"
echo Image created: "$image"
container=$(docker run -d -p 8080:8080 --rm "$image")
echo Container started: "$container"
read -p "Press any key to continue (kill the container)... " -n1 -s
echo Container killed "$(docker kill "$container")"
echo Image deleted "$(docker rmi "$image")"
exit ${EXIT_CODE}