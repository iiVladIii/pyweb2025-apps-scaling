.PHONY: build swarm-deploy swarm-down k8s-deploy k8s-down k8s-status k8s-logs load-test-single load-test-swarm load-test-k8s compare clean

build:
	docker build -t counter-app:latest .

# ==== SWARM ====
swarm-deploy: build
	docker swarm init 2>/dev/null || true
	docker stack deploy -c swarm/docker-compose.swarm.yml counter

swarm-down:
	docker stack rm counter

swarm-status:
	docker stack ps counter

# ==== KUBERNETES ====
k8s-deploy: build
	kubectl apply -f k8s/deployment.yaml
	@echo "Waiting for pods..."
	@sleep 10
	kubectl wait --for=condition=available --timeout=120s deployment/counter-app -n counter-app || true
	@echo ""
	kubectl get all -n counter-app
	@echo ""
	@echo "Access: http://localhost/api/counter"

k8s-down:
	kubectl delete namespace counter-app

k8s-status:
	kubectl get all -n counter-app

k8s-logs:
	kubectl logs -n counter-app deployment/counter-app --tail=50

# ==== LOAD TESTS ====
load-test-single:
	@echo "=== Single instance test ==="
	docker-compose down -v 2>/dev/null || true
	docker-compose up -d
	@sleep 10
	python3 tests/load-test.py | tee tests/results-single.txt
	docker-compose down

load-test-swarm: swarm-deploy
	@echo "=== Swarm cluster test ==="
	@sleep 15
	python3 tests/load-test.py | tee tests/results-swarm.txt

load-test-k8s: k8s-deploy
	@echo "=== Kubernetes cluster test ==="
	@sleep 20
	python3 tests/load-test.py | tee tests/results-k8s.txt

# ==== COMPARE ALL ====
compare:
	pip3 install -q requests
	$(MAKE) load-test-single
	$(MAKE) load-test-swarm
	$(MAKE) load-test-k8s
	@echo ""
	@echo "======================================"
	@echo "=== COMPARISON ==="
	@echo "======================================"
	@echo ""
	@echo "Single instance:"
	@grep "Requests per second" tests/results-single.txt
	@grep "Average:" tests/results-single.txt
	@echo ""
	@echo "Swarm (4 replicas):"
	@grep "Requests per second" tests/results-swarm.txt
	@grep "Average:" tests/results-swarm.txt
	@echo ""
	@echo "Kubernetes (4 replicas):"
	@grep "Requests per second" tests/results-k8s.txt
	@grep "Average:" tests/results-k8s.txt

clean:
	docker stack rm counter 2>/dev/null || true
	docker-compose down -v 2>/dev/null || true
	kubectl delete namespace counter-app 2>/dev/null || true
	rm -f tests/results-*.txt
