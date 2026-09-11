#!/usr/bin/env bash

ROOT="$(git rev-parse --show-toplevel)"

cd "$ROOT/backend/poc-quarkus"

./mvnw quarkus:dev
