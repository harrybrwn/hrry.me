locals {
  discord_role_id  = "989730245168988170"
  discord_template = "discord.message"
}

resource "grafana_message_template" "discord_template" {
  name = "Discord Message Template"
  # See https://github.com/grafana/alerting/blob/main/templates/default_template.go
  template = templatefile("templates/discord_message.tpl", {
    discord_role_id  = local.discord_role_id,
    discord_template = local.discord_template,
  })
}

resource "grafana_contact_point" "discord_alerts" {
  name = "Discord Alerts"
  discord {
    url                     = var.discord_webhook_url
    message                 = "{{ template \"${local.discord_template}\" . }}"
    use_discord_username    = true
    disable_resolve_message = false
  }
}

resource "grafana_notification_policy" "root" {
  # Policy for testing out one off notifications
  policy {
    matcher {
      label = "test"
      match = "="
      value = "true"
    }
    contact_point   = grafana_contact_point.discord_alerts.name
    group_by        = ["alertname"]
    group_wait      = "1s"
    group_interval  = "10s"
    repeat_interval = "10s"
  }
  # Default policy
  group_by        = ["alertname"]
  contact_point   = grafana_contact_point.discord_alerts.name
  group_interval  = "5m"  # time between notifications in a group
  repeat_interval = "25m" # time between resending a notification
  group_wait      = "30s" # time spent buffering fired alerts
}

resource "grafana_folder" "alerting_rule_folder" {
  title = "Homelab Alerts"
}

module "homelab_alerts" {
  source           = "../../modules/grafana/alert"
  name             = "Homelab Alerts"
  folder_uid       = grafana_folder.alerting_rule_folder.uid
  datasource_uid   = grafana_data_source.prometheus.uid
  interval_seconds = 120
  rules = [
    {
      name               = "NGINX Up"
      description        = "Triggers when nginx stops reporting the \"up\" metric."
      dashboard_panel_id = 15
      dashboard          = { uid = "MsjffzSZz", panel_id = 15 }
      duration           = "2m"
      query              = "nginx_up{}"
      condition = {
        op   = "lt"
        args = [1]
      }
    },
  ]
}

module "node_alerts" {
  source = "../../modules/grafana/alert"

  name             = "Node Alerts"
  folder_uid       = grafana_folder.node_alerts_folder.uid
  interval_seconds = floor(60 * 2.5)
  datasource_uid   = grafana_data_source.prometheus.uid

  rules = concat(
    [
      for node in local.nodes :
      {
        name        = "Node Memory: \"${node.name}\""
        summary     = "Memory for node \"${node.name}\""
        description = "Triggered when the Memory for node \"${node.name}\" does above 40%"
        dashboard   = { uid = grafana_dashboard.node_resources.uid, panel_id = 1 }
        duration    = "5m"
        query       = <<EOT
            (
              node_memory_MemTotal_bytes{nodename="${node.name}"} -
              node_memory_MemAvailable_bytes{nodename="${node.name}"}
            ) / node_memory_MemTotal_bytes
        EOT
        condition = {
          op      = "gt"
          args    = [10.0]
          reducer = "last"
        }
      }
    ],
    [
      for node in local.nodes :
      {
        name        = "Node CPU: \"${node.name}\""
        summary     = "CPU for node \"${node.name}\""
        description = "Triggered when the CPU for node \"${node.name}\" does above the threshold"
        dashboard   = { uid = grafana_dashboard.node_resources.uid, panel_id = 0 }
        duration    = "5m"
        query       = <<EOT
            avg without (cpu) (
              rate(node_cpu_seconds_total{mode="user", nodename="${node.name}"}[1m]) * 100
            )
        EOT
        condition = {
          op      = "gt"
          args    = [6.0]
          reducer = "last"
        }
      }
    ],
  )
}

module "node_disk_usage" {
  source = "../../modules/grafana/alert"

  name             = "Disk Usage Alerts"
  folder_uid       = grafana_folder.node_alerts_folder.uid
  interval_seconds = 60 * 10
  datasource_uid   = grafana_data_source.prometheus.uid

  rules = [
    for node in local.nodes :
    {
      name     = "Disk Usage: ${node.name}"
      summary  = "Disk usage > 90%"
      query    = <<EOT
        100 - (
          (node_filesystem_avail_bytes{mountpoint="/", nodename="${node.name}"} * 100)
          / node_filesystem_size_bytes{mountpoint="/", nodename="${node.name}"}
        )
      EOT
      duration = "0s"
      condition = {
        op   = "gt"
        args = [90.0]
      }
    }
  ]
}

#sum by (mode) (rate(pg_locks_count{}[1m]))
#avg by (usename, state) (rate(pg_stat_activity_count{}[1m]))
