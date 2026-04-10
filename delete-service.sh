#!/bin/bash

set -e

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "❌ Usage: ./delete-service.sh <service-name>"
  exit 1
fi

echo "🧹 Deleting service: $SERVICE_NAME"

BASE_DIR=$(cd .. && pwd)
ENV_REPO_DIR="$BASE_DIR/primetime-env-repo"
SERVICE_DIR="$BASE_DIR/$SERVICE_NAME"

GITHUB_ORG="sgodha111"

APP_FILE="$ENV_REPO_DIR/apps/$SERVICE_NAME.yaml"

# --- 1. Remove from ENV repo (GitOps source of truth) ---
if [ -f "$APP_FILE" ]; then
  echo "🗑 Removing from env-repo..."
  rm -f "$APP_FILE"
  # Ensure apps folder is not empty
  if [ -z "$(ls -A "$ENV_REPO_DIR/apps")" ]; then
    echo "📁 apps folder empty, adding .gitkeep"
    touch "$ENV_REPO_DIR/apps/.gitkeep"
  fi
  touch "$ENV_REPO_DIR/apps/.gitkeep"
  cd "$ENV_REPO_DIR"
  git add .
  git commit -m "Remove $SERVICE_NAME"
  git push

  echo "✅ Removed from env-repo (ArgoCD will delete resources)"
else
  echo "⚠️ App file not found in env-repo"
fi

# --- 2. Wait for ArgoCD cleanup (optional) ---
echo "⏳ Waiting for ArgoCD to clean resources..."
sleep 5

# --- 3. Delete GitHub repo ---
echo "🗑 Deleting GitHub repo..."

if gh repo view "$GITHUB_ORG/$SERVICE_NAME" &>/dev/null; then
  gh repo delete "$GITHUB_ORG/$SERVICE_NAME" --yes
  echo "✅ GitHub repo deleted"
else
  echo "⚠️ GitHub repo not found"
fi

# --- 4. Delete local service folder ---
if [ -d "$SERVICE_DIR" ]; then
  rm -rf "$SERVICE_DIR"
  echo "✅ Local folder deleted"
else
  echo "⚠️ Local folder not found"
fi

echo "🎉 Service '$SERVICE_NAME' fully deleted!"

# --- 5. Delete Docker Hub image ---
echo "🗑 Deleting Docker Hub image..."

DOCKER_REPO="$DOCKER_USERNAME/$SERVICE_NAME"

# Get JWT token
TOKEN=$(curl -s -H "Content-Type: application/json" \
  -X POST \
  -d "{\"username\": \"$DOCKER_USERNAME\", \"password\": \"$DOCKER_PASSWORD\"}" \
  https://hub.docker.com/v2/users/login/ | jq -r .token)

# Delete 'latest' tag
curl -s -X DELETE \
  -H "Authorization: JWT $TOKEN" \
  "https://hub.docker.com/v2/repositories/$DOCKER_USERNAME/$SERVICE_NAME/tags/latest/" \
  && echo "✅ Docker image deleted" \
  || echo "⚠️ Failed to delete Docker image"

# --- Delete ArgoCD app explicitly ---
echo "🗑 Deleting ArgoCD application..."

argocd app delete $SERVICE_NAME --yes || echo "⚠️ App not found"