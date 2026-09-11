#!/usr/bin/env bash

ROOT="$(git rev-parse --show-toplevel)"

cd "$ROOT/backend/poc-springboot"

./mvnw spring-boot:run
