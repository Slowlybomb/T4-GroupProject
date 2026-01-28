API_DIR := app/api

.PHONY: help api-run api-test api-tidy api-vet api-build

help:
	@printf "Targets:\n"
	@printf "  api-run   Run the Go API server\n"
	@printf "  api-test  Run Go API tests\n"
	@printf "  api-tidy  Tidy Go API modules\n"
	@printf "  api-vet   Vet Go API code\n"
	@printf "  api-build Build Go API binary\n"

api-run:
	cd $(API_DIR) && go run ./cmd/server

api-test:
	cd $(API_DIR) && go test ./...

api-tidy:
	cd $(API_DIR) && go mod tidy

api-vet:
	cd $(API_DIR) && go vet ./...

api-build:
	cd $(API_DIR) && go build ./cmd/server
