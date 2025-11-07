/**
* Copyright 2024 Google LLC
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

# Email notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email - siva@progrowth.services"
  type         = "email"
  labels = {
    email_address = "siva@progrowth.services"
  }
  enabled = true

  depends_on = [google_project_service.monitoring]
}

# Phase 6.1: Cloud Run Error Rate Alert
# Alert when error rate exceeds 5%
resource "google_monitoring_alert_policy" "cloud_run_error_rate" {
  display_name = "Cloud Run - Error Rate > 5%"
  combiner     = "OR"

  conditions {
    display_name = "Error rate > 5%"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metadata.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Error rate for Cloud Run service has exceeded 5%. This typically indicates application errors (5xx responses). Check Cloud Logging for error details."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.2: Cloud Run Latency Alert
# Alert when 95th percentile latency exceeds 30 seconds
resource "google_monitoring_alert_policy" "cloud_run_latency" {
  display_name = "Cloud Run - Latency P95 > 30s"
  combiner     = "OR"

  conditions {
    display_name = "P95 latency > 30s"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 30000 # 30 seconds in milliseconds

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "95th percentile latency for Cloud Run requests has exceeded 30 seconds. This indicates performance degradation. Check request logs and resource utilization."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.3: Storage Quota Alert
# Alert when Cloud Storage bucket exceeds 50GB
resource "google_monitoring_alert_policy" "storage_quota" {
  display_name = "Cloud Storage - Bucket Size > 50GB"
  combiner     = "OR"

  conditions {
    display_name = "Bucket size > 50GB"

    condition_threshold {
      filter          = "resource.type=\"gcs_bucket\" AND metric.type=\"storage.googleapis.com/storage/total_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 53687091200 # 50GB in bytes

      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Cloud Storage bucket has exceeded 50GB. This helps prevent runaway storage costs from generated assets. Consider archiving or deleting old files."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.4: Vertex AI API Error Alert
# Alert on Vertex AI API errors
resource "google_monitoring_alert_policy" "vertex_ai_errors" {
  display_name = "Vertex AI - API Errors"
  combiner     = "OR"

  conditions {
    display_name = "> 10 errors in 5 minutes"

    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"servicecontrol.googleapis.com/check_error_count\" AND resource.labels.service=\"aiplatform.googleapis.com\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Vertex AI API errors detected. This may indicate quota exhaustion, permission issues, or service degradation. Check Cloud Logging and API quotas."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.5: Certificate Expiry Alert
# Alert when certificate is within 30 days of expiry
resource "google_monitoring_alert_policy" "certificate_expiry" {
  display_name = "Certificate Manager - Expiry < 30 Days"
  combiner     = "OR"

  conditions {
    display_name = "Certificate expires < 30 days"

    condition_threshold {
      filter          = "resource.type=\"certificate\" AND metric.type=\"certificatemanager.googleapis.com/certificate_days_until_expiry\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 30

      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_MIN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "SSL/TLS certificate is expiring within 30 days. Google auto-renews certificates, but this alert monitors the renewal status. Take action if needed."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.6: Uptime Check
# Monitor service availability via HTTPS endpoint
resource "google_monitoring_uptime_check_config" "service_uptime" {
  display_name = "GenAI Creative Studio Uptime Check"
  timeout      = "10s"
  period       = "300s" # Check every 5 minutes

  https_check {
    path = "/"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host = "genaicreativestudio.progrowth.services"
    }
  }

  selected_regions = ["USA", "EUROPE", "ASIA_PACIFIC"]

  depends_on = [google_project_service.monitoring]
}

# Alert policy for uptime check failures
resource "google_monitoring_alert_policy" "uptime_check_failure" {
  display_name = "Uptime Check - Service Down"
  combiner     = "OR"

  conditions {
    display_name = "Service unavailable"

    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND resource.labels.host=\"genaicreativestudio.progrowth.services\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 0.5 # Less than 50% success rate

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_MIN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Uptime check indicates the service is down or returning errors. Check Cloud Run service status and logs immediately."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.7: Cloud Run Instance Count Alert
# Alert when approaching instance limit (warning at 4 out of 5)
resource "google_monitoring_alert_policy" "instance_count" {
  display_name = "Cloud Run - Instance Count > 4"
  combiner     = "OR"

  conditions {
    display_name = "Instance count near limit"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container_instance_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 4

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Cloud Run instance count is approaching the limit (currently at 4/5 max instances). You may need to increase max_instances configuration or investigate traffic spike."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.8: CPU Utilization Alert
# Alert when CPU exceeds 80% for 5 minutes
resource "google_monitoring_alert_policy" "cpu_utilization" {
  display_name = "Cloud Run - CPU Utilization > 80%"
  combiner     = "OR"

  conditions {
    display_name = "High CPU utilization"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container_cpu_allocations\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "CPU utilization on Cloud Run has exceeded 80% for 5+ minutes. Consider increasing CPU allocation (Phase 2.8) or optimizing application code."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}

# Phase 6.9: Memory Utilization Alert
# Alert when memory exceeds 85% for 5 minutes
resource "google_monitoring_alert_policy" "memory_utilization" {
  display_name = "Cloud Run - Memory Utilization > 85%"
  combiner     = "OR"

  conditions {
    display_name = "High memory utilization"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container_memory_allocations\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Memory utilization on Cloud Run has exceeded 85% for 5+ minutes. Consider increasing memory allocation or investigating memory leaks in the application."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.monitoring]
}
