.PHONY: help dev-build dev-apply dev-secrets eso-logs

help:
	@echo "Targets:"
	@echo "  dev-build SERVICE=apps/<svc> IMAGE=quicklookup/<name>:dev-latest   - Build local dev image with nerdctl"
	@echo "  dev-apply SERVICE=apps/<svc>                                     - Apply dev overlay via kustomize"
	@echo "  dev-secrets NAMESPACE=<ns> FILE=.env.local NAME=<secret>         - Create dev Secret from .env file"
	@echo "  eso-logs                                                        - Tail ESO controller logs"

# Build local image (Rancher Desktop / containerd)
# Usage: make dev-build SERVICE=apps/inbox IMAGE=quicklookup/inbox:dev-latest
dev-build:
	@test -n "$(IMAGE)" || (echo "IMAGE is required" && exit 1)
	@nerdctl build -t $(IMAGE) .

# Apply dev overlay
# Usage: make dev-apply SERVICE=apps/inbox
dev-apply:
	@test -n "$(SERVICE)" || (echo "SERVICE is required (e.g., apps/inbox)" && exit 1)
	@kustomize build $(SERVICE)/overlays/dev | kubectl apply -f -

# Create a dev Secret from a .env file (local only)
# Usage: make dev-secrets NAMESPACE=inbox NAME=inbox-secrets FILE=.env.local
dev-secrets:
	@test -n "$(NAMESPACE)" || (echo "NAMESPACE is required" && exit 1)
	@test -n "$(NAME)" || (echo "NAME is required" && exit 1)
	@test -n "$(FILE)" || (echo "FILE is required" && exit 1)
	@kubectl -n $(NAMESPACE) create secret generic $(NAME) --from-env-file=$(FILE) --dry-run=client -o yaml | kubectl apply -f -

# Tail External Secrets Operator logs
eso-logs:
	@kubectl -n external-secrets logs -l app.kubernetes.io/name=external-secrets -f --since=1h

