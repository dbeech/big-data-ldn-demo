terraform {
  required_providers {
    aiven = {
      source = "aiven/aiven"
      version = "3.6.0"
    }
  }
}

resource "aiven_kafka_topic" "digitransit-hfp-kafka-topic" {
  project                  = var.aiven_project_name
  service_name             = var.kafka_service_name
  topic_name               = var.kafka_topic_name
  partitions               = 3
  replication              = 3
  config {
    retention_ms = 1209600000
  }
}

resource "aiven_kafka_connector" "digitransit-hfp-kafka-connector" {
  project         = var.aiven_project_name
  service_name    = var.kafka_connect_service_name
  connector_name  = var.kafka_topic_name
  config = {
    "connector.class" = "com.datamountaineer.streamreactor.connect.mqtt.source.MqttSourceConnector",
    "connect.mqtt.client.id" = var.kafka_topic_name
    "connect.mqtt.error.policy" = "NOOP",
    "connect.mqtt.hosts" = "tcp://mqtt.hsl.fi:1883",
    "connect.mqtt.kcql" = "INSERT INTO ${var.kafka_topic_name} SELECT * FROM ${var.mqtt_topic_name} WITHCONVERTER=`com.datamountaineer.streamreactor.connect.converters.source.JsonSimpleConverter`",
    "connect.mqtt.log.message" = "true",
    "connect.mqtt.service.quality" = "0",
    "connect.progress.enabled" = "true",
    "errors.tolerance" = "all",
    "name" = var.kafka_topic_name
    "errors.log.enable" = "true",
    "errors.log.include.messages" = "true" 
  }
  depends_on = [var.connect_integration]
}
