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
variable "service_plan_m3db" {}
variable "service_plan_opensearch" {}

terraform {
  required_providers {
    aiven = {
      source = "aiven/aiven"
      version = "3.3.1"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_api_token
}

###################################################
# Apache Kafka + MirrorMaker2
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
    kafka_version = "3.1"
    ip_filter = var.allowed_ips
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
    ip_filter = var.allowed_ips
    public_access {
      kafka_connect = true
      prometheus = true
    }
  }
}

resource "aiven_kafka_connector" "demo-kafka-connect-mqtt-digitransit-hfp-vp" {
  project         = var.project_name
  service_name    = "${var.service_name_prefix}-kafka-connect"
  connector_name  = aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp-bus.topic_name
  config = {
    "connector.class" = "com.datamountaineer.streamreactor.connect.mqtt.source.MqttSourceConnector",
    "connect.mqtt.client.id" = aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp-bus.topic_name,
    "connect.mqtt.error.policy" = "NOOP",
    "connect.mqtt.hosts" = "tcp://mqtt.hsl.fi:1883",
    "connect.mqtt.kcql" = "INSERT INTO ${aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp-bus.topic_name} SELECT * FROM /hfp/v2/journey/ongoing/vp/bus/+/+/+/+/+/+/+/+/+/+/+/+ WITHCONVERTER=`com.datamountaineer.streamreactor.connect.converters.source.JsonSimpleConverter`",
    "connect.mqtt.log.message" = "true",
    "connect.mqtt.service.quality" = "0",
    "connect.progress.enabled" = "true",
    "errors.tolerance" = "all",
    "name" = aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp-bus.topic_name
    "errors.log.enable" = "true",
    "errors.log.include.messages" = "true" 
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
  termination_protection  = false
}

resource "aiven_service_integration" "demo-flink-kafka-integration" {
  project                  = var.project_name
  integration_type         = "flink"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_flink.demo-flink.service_name
}

###################################################
# Kafka topics and Flink tables
###################################################

resource "aiven_kafka_topic" "demo-kafka-topic-digitransit-hfp-raw-vp-bus" {
  project                  = var.project_name
  service_name             = aiven_kafka.demo-kafka.service_name
  topic_name               = "digitransit-hfp-raw-vp-bus"
  partitions               = 3
  replication              = 3
  config {
    retention_ms = 604800000
  }
}

resource "aiven_kafka_topic" "demo-kafka-topic-digitransit-hfp-intermediate" {
  project                  = var.project_name
  service_name             = aiven_kafka.demo-kafka.service_name
  topic_name               = "digitransit-hfp-intermediate"
  partitions               = 3
  replication              = 3
  config {
    retention_ms = 604800000
  }
}

# resource "aiven_flink_table" "demo-flink-table-digitransit-hfp-raw-vp" {
#   project = var.project_name
#   service_name = aiven_flink.demo-flink.service_name
#   table_name = aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp.topic_name
#   integration_id = aiven_service_integration.demo-flink-kafka-integration.integration_id
#   kafka_connector_type = "kafka"
#   kafka_topic = aiven_kafka_topic.demo-kafka-topic-digitransit-hfp-raw-vp.topic_name
#   kafka_value_format = "json"
#   kafka_startup_mode = "latest-offset"
#   schema_sql = <<EOF
      # `VP` ROW (
      #   `desi` STRING,
      #   `dir` STRING,
      #   `oper` INT,
      #   `veh` INT,
      #   `tst` INT,
      #   `tsi` INT,
      #   `spd` FLOAT,
      #   `hdg` INT,
      #   `lat` FLOAT,
      #   `long` FLOAT,
      #   `acc` FLOAT,
      #   `dl` INT,
      #   `odo` INT,
      #   `drst` INT,
      #   `oday` STRING,
      #   `jrn` INT,
      #   `line` INT,
      #   `start` STRING,
      #   `loc` STRING,
      #   `stop` STRING,
      #   `route` STRING,
      #   `occu` INT
      # )
#   EOF
# }

# resource "aiven_flink_job" "demo-flink-customer-redaction-job" {
#   project = var.project_name
#   service_name = aiven_flink.demo-flink.service_name
#   job_name = "customer_data_redaction"
#   table_ids = [
#     aiven_flink_table.demo-flink-table-customers.table_id,
#     aiven_flink_table.demo-flink-table-customers-redacted.table_id,
#   ]                                                           
#   statement = <<EOF
#     INSERT INTO ${aiven_flink_table.demo-flink-table-customers-redacted.table_name}
#     SELECT
#       first_name,
#       CONCAT(LEFT(last_name,1),'.'),
#       CONCAT('XXX',SUBSTR(email, LOCATE('@',email))),
#       'XXX',
#       CONCAT('XXXXXXXXXXXX',RIGHT(credit_card_number,4))
#     FROM ${aiven_flink_table.demo-flink-table-customers.table_name}
#   EOF                                                                                             
# }

# *********************************
# Monitoring services
# *********************************

resource "aiven_m3db" "demo-metrics" {
  project                 = var.project_name 
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_m3db
  service_name            = "${var.service_name_prefix}-metrics"
  m3db_user_config {
    m3db_version          = "1.5"
    ip_filter             = var.allowed_ips
    namespaces {
      name = "default"
      type = "unaggregated"
      options {
        retention_options {
          blocksize_duration        = "2h"
          retention_period_duration = "8d"
        }
      }
    }
  }
}

resource "aiven_grafana" "demo-metrics-dashboard" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_grafana
  service_name            = "${var.service_name_prefix}-metrics-dashboard"
  grafana_user_config {
    ip_filter = var.allowed_ips
    public_access {
      grafana = true
    }
  }
}

# Dashboard integration = M3 -> Grafana
resource "aiven_service_integration" "demo-integration-dashboard" {
  project                  = var.project_name
  integration_type         = "dashboard"
  source_service_name      = aiven_grafana.demo-metrics-dashboard.service_name
  destination_service_name = aiven_m3db.demo-metrics.service_name
}

