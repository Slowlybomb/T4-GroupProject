APP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
API_DIR := $(APP_DIR)api
MIGRATIONS_DIR := $(API_DIR)/migrations
ENV_FILE ?= $(API_DIR)/.env.dev

ifneq ($(wildcard $(ENV_FILE)),)
include $(ENV_FILE)
endif

DB_URL ?= $(DATABASE_URL)
# Export runtime env so `make api-run` passes .env.dev values to `go run`.
export DATABASE_URL DB_URL SUPABASE_URL SUPABASE_JWKS_URL JWT_AUDIENCE JWT_ISSUER SUPABASE_SERVICE_ROLE_KEY SUPABASE_ANON_KEY
MIGRATE_DB_URL = $(if $(filter postgresql://%,$(DB_URL)),$(patsubst postgresql://%,postgres://%,$(DB_URL)),$(DB_URL))
MIGRATE_CMD := go run -tags postgres github.com/golang-migrate/migrate/v4/cmd/migrate@v4.18.3

.PHONY: help api-run api-start api-test api-tidy api-vet api-build migrate-up migrate-down migrate-version

help:
	@printf "Targets:\n"
	@printf "  api-run   Run the Go API server\n"
	@printf "  api-start Run built Go API binary\n"
	@printf "  api-test  Run Go API tests\n"
	@printf "  api-tidy  Tidy Go API modules\n"
	@printf "  api-vet   Vet Go API code\n"
	@printf "  api-build Build Go API binary\n"
	@printf "  migrate-up      Apply all DB migrations\n"
	@printf "  migrate-down    Roll back one DB migration\n"
	@printf "  migrate-version Show current DB migration version\n"

api-run:
	cd $(API_DIR) && go run ./cmd/server

api-start:
	cd $(API_DIR) && ./bin/server

api-test:
	cd $(API_DIR) && go test ./...

api-tidy:
	cd $(API_DIR) && go mod tidy

api-vet:
	cd $(API_DIR) && go vet ./...

api-build:
	cd $(API_DIR) && mkdir -p bin && go build -o ./bin/server ./cmd/server

migrate-up:
	@if [ -z "$(DB_URL)" ]; then echo "Set DATABASE_URL or DB_URL before running migrations."; exit 1; fi
	$(MIGRATE_CMD) -path $(MIGRATIONS_DIR) -database "$(MIGRATE_DB_URL)" up

migrate-down:
	@if [ -z "$(DB_URL)" ]; then echo "Set DATABASE_URL or DB_URL before running migrations."; exit 1; fi
	$(MIGRATE_CMD) -path $(MIGRATIONS_DIR) -database "$(MIGRATE_DB_URL)" down 1

migrate-version:
	@if [ -z "$(DB_URL)" ]; then echo "Set DATABASE_URL or DB_URL before running migrations."; exit 1; fi
	$(MIGRATE_CMD) -path $(MIGRATIONS_DIR) -database "$(MIGRATE_DB_URL)" version
