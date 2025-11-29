# Remove old incorrect module cache
rm -rf go.sum
go clean -modcache

# Re-initialize with correct imports
go mod tidy

# Verify it works
go run ./cmd/ingester