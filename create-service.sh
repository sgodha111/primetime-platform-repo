#!/bin/bash

set -e

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "❌ Usage: ./create-service.sh <service-name>"
  exit 1
fi

echo "🚀 Creating service: $SERVICE_NAME"

BASE_DIR=$(cd .. && pwd)
TEMPLATE_DIR="$BASE_DIR/primetime-service-template"
ENV_REPO_DIR="$BASE_DIR/primetime-env-repo"

SERVICE_DIR="$BASE_DIR/$SERVICE_NAME"

GITHUB_ORG="sgodha111"   # ✅ your username

# --- SAFETY CHECK ---
if [ -d "$SERVICE_DIR" ]; then
  echo "❌ Service already exists: $SERVICE_NAME"
  exit 1
fi

# --- 1. Copy template WITHOUT .git ---
echo "📂 Copying template..."
rsync -av --exclude='.git' "$TEMPLATE_DIR/" "$SERVICE_DIR/"

# --- 2. Replace values ---

sed -i '' "s/my-service/$SERVICE_NAME/g" "$SERVICE_DIR/values.yaml"
sed -i '' "s/serviceName:.*/serviceName: $SERVICE_NAME/" "$SERVICE_DIR/values.yaml"
sed -i '' "s|repository:.*|repository: $DOCKER_USERNAME/$SERVICE_NAME|" "$SERVICE_DIR/values.yaml"
TAG="latest"   # later can be commit SHA
sed -i '' "s/tag:.*/tag: $TAG/" "$SERVICE_DIR/values.yaml"

# --- 3. Initialize NEW git repo ---
cd "$SERVICE_DIR"
rm -rf .git   # extra safety
git init
git checkout -b main
git add .
git commit -m "Initial commit for $SERVICE_NAME"

# --- 4. Ensure gh is logged in ---
if ! gh auth status &>/dev/null; then
  echo "🔐 Logging into GitHub..."
  gh auth login
fi

# --- 5. Create GitHub repo ---
echo "📦 Creating GitHub repo..."

gh repo create "$GITHUB_ORG/$SERVICE_NAME" --public --source=. --remote=origin

echo "⏳ Waiting for GitHub repo to be ready..."
sleep 5

# Retry push
echo "🚀 Pushing code..."
git push -u origin main || {
  echo "⚠️ First push failed, retrying..."
  sleep 5
  git push -u origin main
}

echo "✅ Repo created: https://github.com/$GITHUB_ORG/$SERVICE_NAME"

# --- 6. Set GitHub secrets ---
echo "🔐 Adding Docker secrets..."

gh secret set DOCKER_USERNAME -b "$DOCKER_USERNAME" -R "$GITHUB_ORG/$SERVICE_NAME"
gh secret set DOCKER_PASSWORD -b "$DOCKER_PASSWORD" -R "$GITHUB_ORG/$SERVICE_NAME"

# --- 6. Update ENV repo ---
APP_FILE="$ENV_REPO_DIR/apps/$SERVICE_NAME.yaml"

cat <<EOF > "$APP_FILE"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $SERVICE_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/$GITHUB_ORG/$SERVICE_NAME
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cd "$ENV_REPO_DIR"
touch .gitkeep
git add .
git commit -m "Add $SERVICE_NAME"
git push

echo "🎉 Service $SERVICE_NAME fully created and deployed!"