#!/bin/bash

# Script to create Kubernetes Secret from .env file
ENV_FILE="05-config-templates/kubernetes/kanban-api.env"
SECRET_FILE="05-config-templates/kubernetes/kanban-api-secret.yaml"

echo "Creating Kubernetes Secret from .env file..."

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Create temporary secret file
cat > temp-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: kanban-api-secret
  namespace: default
type: Opaque
data:
EOF

# Read .env file and encode each variable
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    if [[ -n "$key" && ! "$key" =~ ^# ]]; then
        # Remove any trailing comments
        value=$(echo "$value" | sed 's/#.*$//')
        # Trim whitespace
        value=$(echo "$value" | xargs)
        
        if [[ -n "$value" ]]; then
            # Encode the value
            encoded_value=$(echo -n "$value" | base64)
            echo "  $key: $encoded_value" >> temp-secret.yaml
        fi
    fi
done < "$ENV_FILE"

# Replace the original secret file
mv temp-secret.yaml "$SECRET_FILE"

echo "Secret file created at $SECRET_FILE"
echo "You can now apply it with: kubectl apply -f $SECRET_FILE"