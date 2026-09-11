#!/usr/bin/env bash

ROOT="$(git rev-parse --show-toplevel)"

cd "$ROOT/backend/poc-jakarta-glassfish"

mvn package

java \
-jar "$ROOT/tools/glassfish/glassfish-embedded-all-8.0.4.jar" \
--httpPort=8082 \
target/poc-jakarta.war
