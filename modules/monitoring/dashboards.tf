# GCP Cloud Monitoring Dashboards for EV Cost Tracker
# These dashboards provide visibility into service health, performance, and business metrics

# =============================================================================
# Dashboard 1: Service Health Overview
# =============================================================================
resource "google_monitoring_dashboard" "service_health" {
  count   = var.enable_dashboards ? 1 : 0
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "EV Cost Tracker - Service Health"
    labels = {
      environment = terraform.workspace
    }
    mosaicLayout = {
      columns = 12
      tiles = [
        # Row 1: Golden Signals Overview
        # NOTE: Prometheus metrics from PodMonitoring use resource.type="prometheus_target"
        # with resource.labels.namespace (not namespace_name)
        {
          width  = 3
          height = 4
          widget = {
            title = "Request Rate"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # Use histogram metric - ALIGN_COUNT counts observations per interval
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "resource.labels.namespace=\"api\"",
                    "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_COUNT"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 3
          height = 4
          xPos   = 3
          widget = {
            title = "Error Rate %"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # Filter for 5xx status codes using histogram
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "resource.labels.namespace=\"api\"",
                    "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\"",
                    "metric.labels.status=monitoring.regex.full_match(\"5.*\")"
                  ])
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_COUNT"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              thresholds = [
                { value = 1, color = "YELLOW", direction = "ABOVE" },
                { value = 5, color = "RED", direction = "ABOVE" }
              ]
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 3
          height = 4
          xPos   = 6
          widget = {
            title = "P95 Latency (ms)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # Use histogram without le filter - aggregation calculates P95
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "resource.labels.namespace=\"api\"",
                    "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_95"
                  }
                }
              }
              thresholds = [
                { value = 0.5, color = "YELLOW", direction = "ABOVE" },
                { value = 1.0, color = "RED", direction = "ABOVE" }
              ]
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 3
          height = 4
          xPos   = 9
          widget = {
            title = "Pod Count"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = join(" AND ", [
                    "resource.type=\"k8s_container\"",
                    "resource.labels.namespace_name=\"api\"",
                    "metric.type=\"kubernetes.io/container/uptime\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_COUNT"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.labels.container_name"]
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_BAR"
              }
            }
          }
        },

        # Row 2: Request Rate Over Time
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Request Rate by Service"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "resource.labels.namespace=\"api\"",
                      "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_COUNT"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.service"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Requests/min"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Response Time Distribution"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "resource.labels.namespace=\"api\"",
                      "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["metric.labels.service"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Seconds"
                scale = "LINEAR"
              }
              thresholds = [
                { value = 0.5 },
                { value = 1.0 }
              ]
            }
          }
        },

        # Row 3: Error Rate and Circuit Breaker
        {
          width  = 6
          height = 4
          yPos   = 8
          widget = {
            title = "Error Rate by Status Code"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "resource.labels.namespace=\"api\"",
                      "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\"",
                      "metric.labels.status=monitoring.regex.full_match(\"[45].*\")"
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_COUNT"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.status"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 8
          widget = {
            title = "Circuit Breaker State"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.labels.service=\"gateway\"",
                      "metric.type=\"prometheus.googleapis.com/resilience4j_circuitbreaker_state/gauge\""
                    ])
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MAX"
                      groupByFields    = ["metric.labels.state", "metric.labels.name"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },

        # Row 4: Resource Usage
        {
          width  = 4
          height = 4
          yPos   = 12
          widget = {
            title = "CPU Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"k8s_container\"",
                      "resource.labels.namespace_name=\"api\"",
                      "metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.container_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "CPU cores"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 4
          height = 4
          xPos   = 4
          yPos   = 12
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"k8s_container\"",
                      "resource.labels.namespace_name=\"api\"",
                      "metric.type=\"kubernetes.io/container/memory/used_bytes\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.container_name"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
              yAxis = {
                label = "Bytes"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 4
          height = 4
          xPos   = 8
          yPos   = 12
          widget = {
            title = "DB Connection Pool"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = join(" AND ", [
                        "resource.type=\"prometheus_target\"",
                        "metric.labels.service=\"session-service\"",
                        "metric.type=\"prometheus.googleapis.com/hikaricp_connections_active/gauge\""
                      ])
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Active"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = join(" AND ", [
                        "resource.type=\"prometheus_target\"",
                        "metric.labels.service=\"session-service\"",
                        "metric.type=\"prometheus.googleapis.com/hikaricp_connections_idle/gauge\""
                      ])
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Idle"
                }
              ]
              yAxis = {
                label = "Connections"
                scale = "LINEAR"
              }
              thresholds = [
                { value = 4 },
                { value = 5 }
              ]
            }
          }
        }
      ]
    }
  })
}

# =============================================================================
# Dashboard 2: Business Metrics
# =============================================================================
resource "google_monitoring_dashboard" "business_metrics" {
  count   = var.enable_dashboards ? 1 : 0
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "EV Cost Tracker - Business Metrics"
    labels = {
      environment = terraform.workspace
    }
    mosaicLayout = {
      columns = 12
      tiles = [
        # Row 1: Session Metrics
        # NOTE: Business metrics from PodMonitoring use resource.type="prometheus_target"
        {
          width  = 4
          height = 4
          widget = {
            title = "Sessions Created (24h)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # ev_cost_sessions_total is the actual metric name
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "metric.type=\"prometheus.googleapis.com/ev_cost_sessions_total/counter\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "86400s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 4
          height = 4
          xPos   = 4
          widget = {
            title = "Cost Calculations (24h)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # Use histogram ALIGN_COUNT to count cost calculation operations
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "metric.type=\"prometheus.googleapis.com/ev_cost_cost_calculation_duration_seconds/histogram\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "86400s"
                    perSeriesAligner   = "ALIGN_COUNT"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 4
          height = 4
          xPos   = 8
          widget = {
            title = "Invoices Parsed (24h)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  # ev_cost_invoices_parsed_total is the actual metric name
                  filter = join(" AND ", [
                    "resource.type=\"prometheus_target\"",
                    "metric.type=\"prometheus.googleapis.com/ev_cost_invoices_parsed_total/counter\""
                  ])
                  aggregation = {
                    alignmentPeriod    = "86400s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_BAR"
              }
            }
          }
        },

        # Row 2: Sessions and Calculations over time
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Sessions Created Over Time"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.type=\"prometheus.googleapis.com/ev_cost_sessions_total/counter\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "3600s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Sessions"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Session Creation Duration (P95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.type=\"prometheus.googleapis.com/ev_cost_sessions_create_duration_seconds/histogram\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Seconds"
                scale = "LINEAR"
              }
              thresholds = [
                { value = 0.5 },
                { value = 1.0 }
              ]
            }
          }
        },

        # Row 3: Auth & Users
        {
          width  = 6
          height = 4
          yPos   = 8
          widget = {
            title = "User Logins by Provider"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.type=\"prometheus.googleapis.com/ev_cost_auth_login_total/counter\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "3600s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.provider", "metric.labels.success"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 8
          widget = {
            title = "Cost Calculation Duration (P95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    # Use cost calculation histogram to show performance
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.type=\"prometheus.googleapis.com/ev_cost_cost_calculation_duration_seconds/histogram\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Seconds"
                scale = "LINEAR"
              }
            }
          }
        },

        # Row 4: API & Stripe
        {
          width  = 6
          height = 4
          yPos   = 12
          widget = {
            title = "Public API Usage (v1)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "resource.type=\"prometheus_target\"",
                      "metric.type=\"prometheus.googleapis.com/ev_cost_api_key_usage_total/counter\""
                    ])
                    aggregation = {
                      alignmentPeriod    = "3600s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.endpoint"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 12
          widget = {
            title = "Database Connection Pool"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = join(" AND ", [
                        "resource.type=\"prometheus_target\"",
                        "metric.type=\"prometheus.googleapis.com/hikaricp_connections_active/gauge\""
                      ])
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Active"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = join(" AND ", [
                        "resource.type=\"prometheus_target\"",
                        "metric.type=\"prometheus.googleapis.com/hikaricp_connections_idle/gauge\""
                      ])
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Idle"
                }
              ]
              yAxis = {
                label = "Connections"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}
