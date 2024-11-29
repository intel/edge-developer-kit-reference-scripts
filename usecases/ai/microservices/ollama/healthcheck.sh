#!/bin/bash

# Ensure OLLAMA_HOST is set
if [ -z "$OLLAMA_HOST" ]; then
  echo "Error: OLLAMA_HOST environment variable is not set."
  exit 1
fi

# Ensure LLM_MODEL is set
if [ -z "$LLM_MODEL" ]; then
  echo "Error: LLM_MODEL environment variable is not set."
  exit 1
fi

PORT=$(echo "$OLLAMA_HOST" | cut -d':' -f2)

# Capture the HTTP response code and response body separately
http_code=$(curl -s -o response.txt -w "%{http_code}" -X POST "http://localhost:$PORT/api/show" -d "{\"model\": \"$LLM_MODEL\"}")
response=$(cat response.txt)

echo "HTTP Response Code: $http_code"

if [ "$http_code" -ne 200 ]; then
  echo "Error: HTTP request failed with status code $http_code"
  rm response.txt
  exit 1
fi

if echo "$response" | grep -q "\"error\""; then
  echo "Error in response: $(echo "$response" | sed -n 's/.*\"error\":\"\([^\"]*\)\".*/\1/p')"
  rm response.txt
  exit 1
else
  echo "Ollama is up and running."
  rm response.txt
  exit 0
fi