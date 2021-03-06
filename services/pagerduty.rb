# encoding: utf-8

# Initial implementation by Mike Heffner:
#  https://github.com/librato/papertrail_pagerduty_webhook
class Service::Pagerduty < Service
  def receive_validate(errors)
    success = true
    [:service_key, :event_type, :description].each do |k|
      if settings[k].to_s.empty?
        errors[k] = "Is required"
        success = false
      end
    end
    success
  end

  def receive_alert_clear
    receive_alert
  end

  def receive_alert
    raise_config_error unless receive_validate({})

    pd_payload = {}
    ['user_id', 'alert', 'trigger_time', 'conditions', 'violations'].each do |whitelisted|
      pd_payload[whitelisted] = payload[whitelisted]
    end
    alert_name = payload['alert']['name']
    description = alert_name.blank? ? settings[:description] : alert_name
    body = {
      :service_key => settings[:service_key],
      :event_type => settings[:event_type],
      :description => description,
      :details => pd_payload
    }

    body[:event_type] = payload[:clear] ? "resolve" : "trigger"
    if payload[:alert][:version] == 1
      body[:details][:metric_link] = payload_link(payload)
    end
    body[:details][:alert_link] = alert_link(payload['alert']['id'])
    keys = [settings[:incident_key], payload[:incident_key]].compact
    if keys.size > 0
      body[:incident_key] = keys.join("-")
    end

    url = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

    http_post url, body, 'Content-Type' => 'application/json'
  end
end
