# #!/bin/bash

# SERVICE_NAME=$1

# echo "Creating service: $SERVICE_NAME"

# # 1. Create repo from template (simulate)
# cp -r service-template $SERVICE_NAME

# # 2. Replace placeholders
# sed -i '' "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" $SERVICE_NAME/k8s/deployment.yaml
# sed -i '' "s|{{IMAGE}}|myrepo/$SERVICE_NAME:latest|g" $SERVICE_NAME/k8s/deployment.yaml

# # 3. Commit to GitHub (pseudo)
# echo "Push $SERVICE_NAME repo to GitHub"

# # 4. Add to env-repo
# cat <<EOF >> ../primetime-env-repo/apps/$SERVICE_NAME.yaml
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: $SERVICE_NAME
#   namespace: argocd
# spec:
#   project: default
#   source:
#     repoURL: https://github.com/YOUR_ORG/$SERVICE_NAME
#     targetRevision: main
#     path: k8s
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: default
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
# EOF

# # 5. Commit env repo
# cd ../primetime-env-repo
# git add .
# git commit -m "Add $SERVICE_NAME"
# git push

# echo "🚀 Service $SERVICE_NAME deployed via ArgoCD"


set -e

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "❌ Usage: ./create-service.sh <service-name>"
  exit 1
fi

echo "🚀 Creating service: $SERVICE_NAME"

BASE_DIR=$(pwd)/..
TEMPLATE_DIR="$BASE_DIR/primetime-service-template"
ENV_REPO_DIR="$BASE_DIR/primetime-env-repo"

# --- 1. Create service folder ---
cp -r $TEMPLATE_DIR $BASE_DIR/$SERVICE_NAME

# --- 2. Replace placeholders ---
sed -i '' "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" $BASE_DIR/$SERVICE_NAME/k8s/deployment.yaml

# --- 3. Create ArgoCD Application ---
cat <<EOF > $ENV_REPO_DIR/apps/$SERVICE_NAME.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $SERVICE_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: file://$BASE_DIR/$SERVICE_NAME
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 4. Apply to cluster ---
kubectl apply -f $ENV_REPO_DIR/apps/$SERVICE_NAME.yaml

echo "✅ Service $SERVICE_NAME deployed via ArgoCD"