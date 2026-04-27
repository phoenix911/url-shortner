.PHONY: setup commit deploy dev create create-interactive test

# Interactive setup wizard — resumes from where you left off
setup:
	@bash scripts/setup.sh

# Local dev server (hot reload)
dev:
	cd code && npx wrangler dev

# Commit and push (default). Use NP=1 to skip push. Use MSG="..." or get prompted.
# Appends branch name to commit message, same as _gcp.
commit:
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	echo "You are currently on branch: $$BRANCH"; \
	read -p "Proceed with commit? (y/n): " proceed </dev/tty; \
	if [ "$$proceed" != "y" ]; then echo "Commit aborted."; exit 1; fi; \
	if [ -n "$(MSG)" ]; then msg="$(MSG)"; else read -p "Enter commit message: " msg </dev/tty; fi; \
	git add -A; \
	git commit -m "$$msg || $$BRANCH"; \
	if [ -z "$(NP)" ]; then git push origin $$BRANCH; else echo "Committed but not pushed (NP=1)."; fi

# Deploy to Cloudflare Workers
deploy:
	cd code && npx wrangler deploy

# Load .env if present (exports ADMIN_PASSWORD for create targets)
ifneq (,$(wildcard .env))
  include .env
  export
endif

# Create a short link. Usage:
#   make create URL=https://example.com
#   make create URL=https://example.com CODE=myslug
#   make create URL=https://example.com CODE=myslug TTL=30
create:
	@bash curl/create.sh "$(URL)" "$(CODE)" "$(TTL)"

# Run the end-to-end test suite against the deployed worker
test:
	@bash scripts/test.sh

# Interactive create — prompts for URL, code, TTL
create-interactive:
	@read -p "Long URL (required): " url </dev/tty; \
	read -p "Short code (leave blank for auto): " code </dev/tty; \
	read -p "Expires in days (leave blank for 365, 0 = never): " ttl </dev/tty; \
	bash curl/create.sh "$$url" "$$code" "$${ttl:-365}"
