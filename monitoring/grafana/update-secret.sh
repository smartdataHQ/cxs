#!/usr/bin/env bash

set -euo pipefail

DB_URL=$(kubectl get secret cxs-pg-pguser-grafana-db --namespace data -o jsonpath='{.data.pgbouncer-uri}' | base64 --decode)
awk -v db_url="$DB_URL" '{gsub(/__DB_URL__/, db_url); print}' secret.yaml.tmpl | kubectl -n grafana apply -f -
