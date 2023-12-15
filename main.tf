variable "aiven_api_token" {}
variable "allowed_ips" {}
variable "project_name" {}
variable "kafka_version" {}
variable "service_cloud" {}
variable "service_cloud_alt" {}
variable "service_cloud_flink" {}
variable "service_name_prefix" {}
variable "service_plan_clickhouse" {}
variable "service_plan_flink" {}
variable "service_plan_kafka" {}
variable "service_plan_kafka_connect" {}
variable "service_plan_grafana" {}
variable "service_plan_influxdb" {}
variable "service_plan_opensearch" {}
variable "service_plan_pg" {}

terraform {
  required_providers {
    aiven = {
      source = "aiven/aiven"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_api_token
}

###################################################
# Apache Kafka
###################################################

resource "aiven_kafka" "demo-kafka" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_kafka
  service_name            = "${var.service_name_prefix}-kafka"
  default_acl             = false
  termination_protection  = false
  kafka_user_config {
    schema_registry = true
    kafka_rest = true
    kafka_connect = false
    kafka_version = var.kafka_version
    ip_filter_string = var.allowed_ips
    kafka {
      auto_create_topics_enable = false
    }  
    public_access {
      kafka = false
      kafka_rest = false
      kafka_connect = true
      schema_registry = false
    }
  }
}

resource "aiven_kafka_connect" "demo-kafka-connect" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_kafka_connect
  service_name            = "${var.service_name_prefix}-kafka-connect"
  kafka_connect_user_config {
    ip_filter_string = var.allowed_ips
    public_access {
      kafka_connect = true
      prometheus = true
    }
  }
}

resource "aiven_service_integration" "demo-kafka-connect-source-integration" {
  project                  = var.project_name
  integration_type         = "kafka_connect"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
}

###################################################
# Apache Flink
###################################################

resource "aiven_flink" "demo-flink" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_flink
  service_name            = "${var.service_name_prefix}-flink"
}

resource "aiven_service_integration" "demo-flink-kafka-integration" {
  project                  = var.project_name
  integration_type         = "flink"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_flink.demo-flink.service_name
}

###################################################
# PostgreSQL
###################################################

resource "aiven_pg" "demo-postgres" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_pg
  service_name            = "${var.service_name_prefix}-postgres"
  pg_user_config {
    pg_version            = "14"
  }
}

resource "aiven_service_integration" "demo-flink-postgres-integration" {
  project                  = var.project_name
  integration_type         = "flink"
  source_service_name      = aiven_pg.demo-postgres.service_name
  destination_service_name = aiven_flink.demo-flink.service_name
}

###################################################
# ClickHouse
###################################################

resource "aiven_clickhouse" "demo-clickhouse" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_clickhouse
  service_name            = "${var.service_name_prefix}-clickhouse"
}

resource "aiven_service_integration" "demo-clickhouse-kafka-integration" {
  project                  = var.project_name
  integration_type         = "clickhouse_kafka"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_clickhouse.demo-clickhouse.service_name
  clickhouse_kafka_user_config {
    # note: JSON is experimental data type and not supported yet
    # tables {
    #   name        = "digitransit_hfp_bus_positions_raw"
    #   group_name  = "3e4bf765-3418-42bd-b6f9-0378d677d583"
    #   data_format = "JSONEachRow"
    #   columns {
    #     name = "VP"
    #     type = "JSON"
    #   }
    #   topics {
    #     name = "digitransit-hfp-bus-positions-raw"
    #   }
    # }
    tables {
      name        = "digitransit_hfp_bus_positions_flattened"
      group_name  = "65e9b6ef-978e-4746-8714-dfb2cbef6915"
      data_format = "JSONEachRow"
      columns { 
        name = "desi" 
        type = "String"
      }
      columns {
        name = "dir"
        type = "String"
      }
      columns {
        name = "oper"
        type = "Int32"
      }
      columns {
        name = "oper_name"
        type = "String"
      }
      columns {
        name = "veh"
        type = "Int32"
      }
      columns {
        name = "tst"
        type = "String"
      }
      columns {
        name = "tsi"
        type = "Int32"
      }
      columns {
        name = "spd"
        type = "Float32"
      }
      columns {
        name = "hdg"
        type = "Int32"
      }
      columns {
        name = "lat"
        type = "Float32"
      }
      columns {
        name = "long"
        type = "Float32"
      }
      columns {
        name = "acc"
        type = "Float32"
      }
      columns {
        name = "dl"
        type = "Int32"
      }
      columns {
        name = "drst"
        type = "Int32"
      }
      columns {
        name = "oday"
        type = "String"
      }
      columns {
        name = "start"
        type = "String"
      }
      columns {
        name = "loc"
        type = "String"
      }
      columns {
        name = "stop"
        type = "String"
      }
      columns {
        name = "route"
        type = "String"
      }
      columns {
        name = "occu"
        type = "Int32"
      }
      topics {
        name = "digitransit-hfp-bus-positions-flattened"
      }
    }
  }
}

###################################################
# DigiTransit HFP feeds
###################################################

module "digitransit-hfp-bus-positions" {
  source = "./digitransit-hfp"
  connect_integration = aiven_service_integration.demo-kafka-connect-source-integration
  aiven_project_name = var.project_name
  kafka_connect_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  kafka_service_name = aiven_kafka.demo-kafka.service_name
  kafka_topic_name = "digitransit-hfp-bus-positions-raw"
  mqtt_topic_name = "/hfp/v2/journey/ongoing/vp/bus/+/+/+/+/+/+/+/+/+/+/+/+"
}

module "digitransit-hfp-train-positions" {
  source = "./digitransit-hfp"
  connect_integration = aiven_service_integration.demo-kafka-connect-source-integration
  aiven_project_name = var.project_name
  kafka_connect_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  kafka_service_name = aiven_kafka.demo-kafka.service_name
  kafka_topic_name = "digitransit-hfp-train-positions-raw"
  mqtt_topic_name = "/hfp/v2/journey/ongoing/vp/train/+/+/+/+/+/+/+/+/+/+/+/+"
}

resource "aiven_kafka_topic" "demo-kafka-topic-digitransit-hfp-bus-positions-flattened" {
  project                  = var.project_name
  service_name             = aiven_kafka.demo-kafka.service_name
  topic_name               = "digitransit-hfp-bus-positions-flattened"
  partitions               = 3
  replication              = 3
  config {
    retention_ms = 1209600000
  }
}

resource "aiven_flink_application" "demo-flink-application-digitransit-hfp-bus-position-flattening" {
  project                 = var.project_name
  service_name            = aiven_flink.demo-flink.service_name
  name                    = "digitransit_hfp_bus_positions_flatten"
}

resource "aiven_flink_application_version" "demo-flink-application-version-digitransit-hfp-bus-position-flattening" {
  project                 = var.project_name
  service_name            = aiven_flink.demo-flink.service_name
  application_id          = aiven_flink_application.demo-flink-application-digitransit-hfp-bus-position-flattening.application_id
  statement = <<EOF
    INSERT INTO digitransit_hfp_bus_positions_flattened
    SELECT
      VP.`desi`,
      VP.`dir`,
      VP.`oper`,
      operators.`name`,
      VP.`veh`,
      VP.`tst`,
      VP.`tsi`,
      VP.`spd`,
      VP.`hdg`,
      VP.`lat`,
      VP.`long`,
      VP.`acc`,
      VP.`dl`,
      VP.`drst`,
      VP.`oday`,
      VP.`start`,
      VP.`loc`,
      VP.`stop`,
      VP.`route`,
      VP.`occu`
    FROM digitransit_hfp_bus_positions_raw positions
    INNER JOIN digitransit_operators operators
    ON positions.VP.`oper` = operators.`id`
  EOF   
  sink {
    create_table   = <<EOT
    CREATE TABLE digitransit_hfp_bus_positions_flattened (
      `desi` STRING,
      `dir` STRING,
      `oper` INT,
      `oper_name` STRING,
      `veh` INT,
      `tst` STRING,
      `tsi` INT,
      `spd` FLOAT,
      `hdg` INT,
      `lat` FLOAT,
      `long` FLOAT,
      `acc` FLOAT,
      `dl` INT,
      `drst` INT,
      `oday` STRING,
      `start` STRING,
      `loc` STRING,
      `stop` STRING,
      `route` STRING,
      `occu` INT
    ) WITH (
      'connector' = 'kafka',
      'properties.bootstrap.servers' = '',
      'scan.startup.mode' = 'latest-offset',
      'topic' = 'digitransit-hfp-bus-positions-flattened',
      'value.format' = 'json'
    )
  EOT
    integration_id = aiven_service_integration.demo-flink-kafka-integration.integration_id
  }
  source {
    create_table   = <<EOT
    CREATE TABLE digitransit_hfp_bus_positions_raw (
      `VP` ROW<`desi` STRING,`dir` STRING,`oper` INT,`veh` INT,`tst` STRING,`tsi` INT,`spd` FLOAT,`hdg` INT,`lat` FLOAT,`long` FLOAT,`acc` FLOAT,`dl` INT,`drst` INT,`oday` STRING,`start` STRING,`loc` STRING,`stop` STRING,`route` STRING,`occu` INT>
    ) WITH (
      'connector' = 'kafka',
      'properties.bootstrap.servers' = '',
      'scan.startup.mode' = 'earliest-offset',
      'topic' = 'digitransit-hfp-bus-positions-raw',
      'value.format' = 'json'
    )
    EOT
    integration_id = aiven_service_integration.demo-flink-kafka-integration.integration_id
  }
  source {
    create_table   = <<EOT
    CREATE TABLE digitransit_operators (
      `id` INT PRIMARY KEY,
      `name` STRING NOT NULL
    ) WITH (
      'connector' = 'jdbc',
      'url' = 'jdbc:postgresql://',
      'table-name' = 'public.digitransit_operators'
    )
    EOT
    integration_id = aiven_service_integration.demo-flink-postgres-integration.integration_id
  }
}

resource "aiven_flink_application_deployment" "demo-flink-application-deployment-digitransit-hfp-bus-position-flattening" {
  project                 = var.project_name
  service_name            = aiven_flink.demo-flink.service_name
  application_id          = aiven_flink_application.demo-flink-application-digitransit-hfp-bus-position-flattening.application_id
  version_id              = aiven_flink_application_version.demo-flink-application-version-digitransit-hfp-bus-position-flattening.application_version_id 
}

# *********************************
# Monitoring services
# *********************************

resource "aiven_influxdb" "demo-metrics" {
  project                 = var.project_name 
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_influxdb
  service_name            = "${var.service_name_prefix}-metrics"
  influxdb_user_config {
    ip_filter_string      = var.allowed_ips
  }
}

resource "aiven_grafana" "demo-metrics-dashboard" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_grafana
  service_name            = "${var.service_name_prefix}-metrics-dashboard"
  grafana_user_config {
    ip_filter_string = var.allowed_ips
    public_access {
      grafana = true
    }
  }
}

# Metrics integration: Kafka -> InfluxDB
resource "aiven_service_integration" "demo-metrics-integration-kafka" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_influxdb.demo-metrics.service_name
}

# Metrics integration: Flink -> InfluxDB
resource "aiven_service_integration" "demo-metrics-integration-flink" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_flink.demo-flink.service_name
  destination_service_name = aiven_influxdb.demo-metrics.service_name
}

# Dashboard integration = InfluxDB -> Grafana
resource "aiven_service_integration" "demo-dashboard-integration" {
  project                  = var.project_name
  integration_type         = "dashboard"
  source_service_name      = aiven_grafana.demo-metrics-dashboard.service_name
  destination_service_name = aiven_influxdb.demo-metrics.service_name
}

