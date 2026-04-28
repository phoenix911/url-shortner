.PHONY: setup commit deploy dev create create-interactive test help
.DEFAULT_GOAL := help

BOLD  := \033[1m
RESET := \033[0m
CYAN  := \033[36m
GREEN := \033[32m
DIM   := \033[2m

# Load .env if present (exports ADMIN_PASSWORD, SITE_DOMAIN for targets that need them)
ifneq (,$(wildcard .env))
  include .env
  export
endif

##@ Setup & deploy
setup: ## Interactive wizard — Cloudflare auth, KV, domain, password, deploy
	@bash scripts/setup.sh

deploy: ## Deploy to Cloudflare Workers
	cd code && npx wrangler deploy

dev: ## Local dev server at localhost:8787 (hot reload)
	cd code && npx wrangler dev

##@ Links
create: ## Create a short link  (URL=https://...  CODE=slug  TTL=days)
	@bash scripts/create.sh "$(URL)" "$(CODE)" "$(TTL)"

create-interactive: ## Prompt for URL / code / TTL interactively
	@read -p "Long URL (required): " url </dev/tty; \
	read -p "Short code (leave blank for auto): " code </dev/tty; \
	read -p "Expires in days (leave blank for 365, 0 = never): " ttl </dev/tty; \
	bash scripts/create.sh "$$url" "$$code" "$${ttl:-365}"

##@ Dev
test: ## Run 32 end-to-end tests against the live worker
	@bash scripts/test.sh

commit: ## Stage all, commit, push  (MSG="..."  NP=1 to skip push)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	echo "You are currently on branch: $$BRANCH"; \
	read -p "Proceed with commit? (y/n): " proceed </dev/tty; \
	if [ "$$proceed" != "y" ]; then echo "Commit aborted."; exit 1; fi; \
	if [ -n "$(MSG)" ]; then msg="$(MSG)"; else read -p "Enter commit message: " msg </dev/tty; fi; \
	git add -A; \
	git commit -m "$$msg || $$BRANCH"; \
	if [ -z "$(NP)" ]; then git push origin $$BRANCH; else echo "Committed but not pushed (NP=1)."; fi

##@
help: ## Show this help
	@awk ' \
	  /^##@ / { \
	    group = substr($$0, 5); \
	    printf "\n$(BOLD)$(CYAN)%s$(RESET)\n", group; \
	    next \
	  } \
	  /^[a-zA-Z_-]+:.*## / { \
	    split($$0, a, ":.*## "); \
	    printf "  $(GREEN)make %-22s$(RESET) $(DIM)%s$(RESET)\n", a[1], a[2] \
	  } \
	' $(MAKEFILE_LIST)
	@printf "\n$(DIM)Reads ADMIN_PASSWORD and SITE_DOMAIN from .env$(RESET)\n"
