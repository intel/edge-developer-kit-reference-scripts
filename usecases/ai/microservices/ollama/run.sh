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

echo "Starting Ollama..."
./ollama serve &

# Give Ollama a moment to start up
sleep 5

echo "Checking if Ollama is up..."
PORT=$(echo "$OLLAMA_HOST" | cut -d':' -f2)

echo "Downloading Model: $LLM_MODEL"
curl -# "http://localhost:$PORT/api/pull" -d "{\"name\": \"$LLM_MODEL\"}"

# Warm Up Model
curl -# http://localhost:"$PORT"/api/generate -d "{\"model\": \"$LLM_MODEL\", \"prompt\": \"Why is the sky blue?\"}"

# To keep the container running, use an indefinite wait
echo "Ollama is running. Keeping container alive..."
tail -f /dev/null