#!/bin/bash
clickhouse_service=$(avn service list -t clickhouse --format '{service_name}')
avn service user-list --format 'CH_USER={username}' $clickhouse_service > .env
avn service user-list --format 'CH_PASSWORD={password}' $clickhouse_service >> .env
SERVICE_URI=$(avn service get --format '{service_uri}' $clickhouse_service)
echo "CH_SERVICE_URI=${SERVICE_URI}" >> .env
