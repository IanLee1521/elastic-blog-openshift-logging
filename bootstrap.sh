#!/bin/bash

if [ -z "${ES_URL}" ]; then
    echo "ES_URL is not defined"
    exit 1
fi

if [ -z "${ES_USERNAME}" ]; then
    echo "ES_USERNAME is not defined"
    exit 1
fi

if [ -z "${ES_PASSWORD}" ]; then
    echo "ES_PASSWORD is not defined"
    exit 1
fi

for filepath in pipelines/*.yml; 
do 
    filename=$(basename "${filepath}"); 
    pipeline_name="${filename%.*}"
    body=$(yq -c < "${filepath}"); 
    echo "${filename}";
    curl -XPUT "${ES_URL}/_ingest/pipeline/${pipeline_name}" -H "Content-Type: application/json" -d "$body" -u "${ES_USERNAME}":"${ES_PASSWORD}" || \
        printf "Could not upload ingest pipeline"
    echo ""
done

for filepath in indices/*.yml; 
do 
    filename=$(basename "${filepath}"); 
    index_name="${filename%.*}"
    body=$(yq -c < "${filepath}"); 
    echo "${filename}";
    # Create the index only if it does not exist
    curl -I "${ES_URL}/${index_name}" -u "${ES_USERNAME}":"${ES_PASSWORD}" -fSs 1>/dev/null 2> /dev/null || \
        curl -XPUT "${ES_URL}/${index_name}" -H "Content-Type: application/json" -d "$body" -u "${ES_USERNAME}":"${ES_PASSWORD}" || \
        printf "Could not create index"
done