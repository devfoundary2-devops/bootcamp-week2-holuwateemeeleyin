.PHONY: help setup start-cluster build-images deploy verify test clean easter-eggs bonus redo-port-forward

# Default target
help:
	@echo "Kubernetes Bootcamp Lab - Available Commands:"
	@echo ""
	@echo "Setup & Prerequisites:"
	@echo "  make setup          - Install required tools (macOS)"
	@echo "  make verify-tools   - Verify tool installations"
	@echo ""
	@echo "Cluster Management:"
	@echo "  make start-cluster  - Start Minikube cluster"
	@echo "  make cluster-info   - Show cluster information"
	@echo "  make stop-cluster   - Stop Minikube cluster"
	@echo ""
	@echo "Application Deployment:"
	@echo "  make build-images   - Build Docker images"
	@echo "  make deploy         - Deploy all components"
	@echo "  make deploy-infra   - Deploy infrastructure only"
	@echo "  make deploy-apps    - Deploy applications only"
	@echo ""
	@echo "Testing & Verification:"
	@echo "  make verify         - Verify deployment"
	@echo "  make test           - Run assessment tests"
	@echo "  make port-forward   - Setup port forwarding"
	@echo "  make redo-port-forward - Restart port forwarding"
	@echo ""
	@echo "Easter Eggs & Bonus:"
	@echo "  make easter-eggs    - Find all easter eggs"
	@echo "  make bonus          - Deploy bonus challenges"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Clean up resources"
	@echo "  make destroy        - Destroy all local infrastructure"
	@echo "  make reset          - Reset everything"

# Setup and Prerequisites
setup:
	@echo "Installing required tools..."
	choco install minikube kubernetes-cli docker-desktop kubernetes-helm -y

verify-tools:
	@echo "Verifying tool installations..."
	minikube version
	kubectl version --client
	docker --version
	helm version

# Cluster Management
start-cluster:
	@echo "Starting Minikube cluster..."
	minikube start --cpus=2 --memory=3072 --kubernetes-version=v1.28.0 --driver=docker
	minikube addons enable ingress
	minikube addons enable metrics-server

cluster-info:
	@echo "Cluster Information:"
	kubectl cluster-info
	kubectl get nodes

stop-cluster:
	@echo "Stopping Minikube cluster..."
	minikube stop

# Build Images
build-images:
	@echo "Building Docker images..."
	docker build -t shopmicro-backend:latest ./backend
	docker build -t shopmicro-frontend:latest ./frontend
	docker build -t shopmicro-ml-service:latest ./ml-service
	@echo "Loading images into Minikube..."
	minikube image load shopmicro-backend:latest
	minikube image load shopmicro-frontend:latest
	minikube image load shopmicro-ml-service:latest

# Deployment
deploy: deploy-infra deploy-apps

deploy-infra:
	@echo "Deploying infrastructure..."
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmaps/
	kubectl apply -f k8s/deployments/

deploy-apps:
	@echo "Deploying applications..."
	kubectl apply -f k8s/services/
	@echo "Waiting for deployments..."
	kubectl wait --for=condition=available --timeout=300s deployment --all -n shopmicro

# Verification
verify:
	@echo "Verifying deployment..."
	kubectl get pods -n shopmicro
	kubectl get svc -n shopmicro

port-forward:
	@echo "Setting up port forwarding..."
	cmd /c start powershell -NoExit -Command "kubectl port-forward -n shopmicro svc/grafana 3000:3000"
	cmd /c start powershell -NoExit -Command "kubectl port-forward -n shopmicro svc/frontend 8080:80"
	cmd /c start powershell -NoExit -Command "kubectl port-forward -n shopmicro svc/backend 3001:3001"
	@echo "Services available at:"
	@echo "  Grafana: http://localhost:3000 (admin/admin)"
	@echo "  Frontend: http://localhost:8080"
	@echo "  Backend: http://localhost:3001"

redo-port-forward:
	@echo "Killing existing port forwards..."
	taskkill /F /IM "kubectl.exe" || exit 0
	@echo "Setting up new port forwarding..."
	kubectl port-forward -n shopmicro svc/grafana 3000:3000 &
	kubectl port-forward -n shopmicro svc/frontend 8080:80 &
	kubectl port-forward -n shopmicro svc/backend 3001:3001 &
	@echo "Services available at:"
	@echo "  Grafana: http://localhost:3000 (admin/admin)"
	@echo "  Frontend: http://localhost:8080"
	@echo "  Backend: http://localhost:3001"


test:
	@echo "Running assessment tests..."
	@echo "Test 1: Cluster Health"
	kubectl get pods -n shopmicro
	@echo ""
	@echo "Test 2: Service Connectivity"
	-curl -f http://localhost:3001/health || echo "Backend not accessible - run 'make port-forward' first"
	-curl -f http://localhost:8080 || echo "Frontend not accessible - run 'make port-forward' first"
	@echo ""
	@echo "Test 3: Metrics Collection"
	-curl -s http://localhost:3001/metrics | grep shopmicro_backend || echo "Metrics not available"


# Easter Eggs
easter-eggs:
	@echo "Hunting for Easter Eggs..."
	@echo "Easter Egg #1: Secret Bootcamp Endpoint"
	-curl -s http://localhost:3001/api/bootcamp/secret || echo "Backend not accessible - run 'make port-forward' first"
	@echo ""
	@echo "Easter Egg #2: Konami Code - Open frontend and press: ↑↑↓↓←→←→BA"
	@echo ""
	@echo "Easter Egg #3: Coffee Metrics"
	-curl -s http://localhost:3002/metrics | grep coffee || echo "Check ML service metrics"
	@echo ""
	@echo "Easter Egg #4: Pod Whisperer Detection"
	-curl -s http://localhost:3001/api/pod-identity || echo "Backend not accessible - run 'make port-forward' first"
	@echo ""
	@echo "Easter Egg #5: Time Traveler"
	kubectl annotate namespace shopmicro retro.mode="1985"

# Bonus Challenges
bonus:
	@echo "Deploying bonus challenges..."
	@echo "1. Horizontal Pod Autoscaling"
	kubectl apply -f - <<EOF
	apiVersion: autoscaling/v2
	kind: HorizontalPodAutoscaler
	metadata:
	  name: backend-hpa
	  namespace: shopmicro
	spec:
	  scaleTargetRef:
	    apiVersion: apps/v1
	    kind: Deployment
	    name: backend
	  minReplicas: 2
	  maxReplicas: 10
	  metrics:
	  - type: Resource
	    resource:
	      name: cpu
	      target:
	        type: Utilization
	        averageUtilization: 70
	EOF
	@echo "2. Persistent Storage"
	kubectl apply -f - <<EOF
	apiVersion: v1
	kind: PersistentVolume
	metadata:
	  name: postgres-pv
	spec:
	  capacity:
	    storage: 5Gi
	  accessModes:
	    - ReadWriteOnce
	  hostPath:
	    path: /data/postgres
	---
	apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  name: postgres-pvc
	  namespace: shopmicro
	spec:
	  accessModes:
	    - ReadWriteOnce
	  resources:
	    requests:
	      storage: 5Gi
	EOF

# Debugging
logs:
	@echo "Showing logs for all services..."
	kubectl logs -l app=backend -n shopmicro --tail=50
	kubectl logs -l app=frontend -n shopmicro --tail=50

debug:
	@echo "Debug information..."
	kubectl describe pods -n shopmicro
	kubectl get events -n shopmicro --sort-by='.lastTimestamp'

top:
	@echo "Resource usage..."
	kubectl top pods -n shopmicro
	kubectl top nodes

# Cleanup
clean:
	@echo "Cleaning up resources..."
	kubectl delete namespace shopmicro --ignore-not-found=true
	taskkill /F /IM "kubectl.exe" || exit 0

destroy:
	@echo "Destroying all local infrastructure..."
	@echo "Stopping port forwards..."
	taskkill /F /IM "kubectl.exe" || exit 0
	@echo "Deleting Kubernetes resources..."
	kubectl delete namespace shopmicro --ignore-not-found=true
	@echo "Stopping Minikube cluster..."
	minikube stop || true
	@echo "Deleting Minikube cluster..."
	minikube delete || true
	@echo "Cleaning up Docker images..."
	docker rmi shopmicro-backend:latest shopmicro-frontend:latest shopmicro-ml-service:latest || true
	@echo "Pruning Docker system..."
	docker system prune -f
	@echo "All local infrastructure destroyed!"

reset: clean
	@echo "Resetting everything..."
	minikube delete
	docker system prune -f

# Quick commands
status:
	@echo "Current Status:"
	kubectl get all -n shopmicro

restart:
	@echo "Restarting all deployments..."
	kubectl rollout restart deployment -n shopmicro

scale-up:
	@echo "Scaling up services..."
	kubectl scale deployment backend --replicas=3 -n shopmicro
	kubectl scale deployment frontend --replicas=2 -n shopmicro

scale-down:
	@echo "Scaling down services..."
	kubectl scale deployment backend --replicas=1 -n shopmicro
	kubectl scale deployment frontend --replicas=1 -n shopmicro

# Achievement verification
achievements:
	@echo "Checking achievements..."
	@echo "Deployment Master:"
	kubectl get pods -n shopmicro | grep Running | wc -l
	@echo "Troubleshoot Hero:"
	kubectl get events -n shopmicro | grep -c Warning || echo "0 warnings found"
	@echo "Metrics Guru:"
	-curl -s http://localhost:3000/api/health || echo "Grafana not accessible"
	@echo "Easter Egg Hunter:"
	kubectl get namespace shopmicro -o jsonpath='{.metadata.annotations.retro\.mode}' || echo "Time traveler not activated"