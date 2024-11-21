#!/usr/bin/env bash

## Script to clear a ECR registry of repositories that contain multiple images
#  It works by listing all existing repositories in the registry and then clearing each repository of images in batches, the largest batch supported by AWS is 100. Then proceeds to delete the repository.
#  Example call: ./clear-ecr.sh us-east-1 my-aws-cli-profile 100

REGION=$1
PROFILE=$2
BATCH_SIZE=$3

REPOSITORIES=$(aws ecr describe-repositories --region "$REGION" --profile "$PROFILE" | jq -r '.repositories[].repositoryName');

for REPOSITORY in $REPOSITORIES;
do
    echo "Clearing repository $REPOSITORY images"
    IMAGES=$(aws ecr list-images --region "$REGION" --repository-name "$REPOSITORY" --max-items "$BATCH_SIZE" --profile "$PROFILE");

    while
        IMAGE_BATCH=$(echo "$IMAGES" | jq -r '[.imageIds[] | "imageTag=\(.imageTag)"] | join(" ")');
        [[ "$(aws ecr batch-delete-image --region "$REGION" --repository-name "$REPOSITORY" --image-ids $IMAGE_BATCH --profile "$PROFILE" | jq '.failures | length')" -gt 0 ]] && echo "Some images couldn't be deleted";

        NEXT_TOKEN=$(echo "$IMAGES" | jq -r '.NextToken')
        [[ "$NEXT_TOKEN" != "null" ]]
    do
        IMAGES=$(aws ecr list-images --region "$REGION" --repository-name "$REPOSITORY" --max-items "$BATCH_SIZE" --starting-token "$NEXT_TOKEN" --profile "$PROFILE");
    done;

    echo "Deleting repository $REPOSITORY"
    aws ecr delete-repository --region "$REGION" --repository-name "$REPOSITORY" --profile "$PROFILE";
done;
