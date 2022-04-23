module Agents
  class GithubReceivedEventsAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Github notification agent fetches notifications and creates an event by notification.

      `username` for the wanted username.

      `token` If you are authenticated as the given user, you will see private events.

      `debug` is used for verbose mode.

      The `changes only` option causes the Agent to report an event only when the status changes. If set to false, an event will be created for every check.  If set to true, an event will only be created when the status changes (like if your site goes from 200 to 500).

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "id": "XXXXXXXXXXX",
            "type": "WatchEvent",
            "actor": {
              "id": XXXXXX,
              "login": "XXXXXX",
              "display_login": "XXXXXX",
              "gravatar_id": "",
              "url": "https://api.github.com/users/XXXXXX",
              "avatar_url": "https://avatars.githubusercontent.com/u/XXXXXX?"
            },
            "repo": {
              "id": 76460706,
              "name": "hihouhou/docker-sslscan",
              "url": "https://api.github.com/repos/hihouhou/docker-sslscan"
            },
            "payload": {
              "action": "started"
            },
            "public": true,
            "created_at": "2020-10-06T08:55:11Z"
          }
    MD

    def default_options
      {
        'username' => '',
        'debug' => 'false',
        'changes_only' => 'true',
        'expected_receive_period_in_days' => '2',
        'token' => ''
      }
    end

    form_configurable :username, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    form_configurable :token, type: :string
    form_configurable :expected_receive_period_in_days, type: :string

    def validate_options
      unless options['username'].present?
        errors.add(:base, "username is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("https://api.github.com/users/hihouhou/received_events")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "#{interpolated['token']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    
      log "fetch event request status : #{response.code}"
    
      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end

      if interpolated['changes_only'] == 'true' && !payload.empty?
        if payload.to_s != memory['last_status']
          if payload
            if "#{memory['last_status']}" == ''
              payload.each do |event|
                if interpolated['debug'] == 'true'
                  log event
                end
                create_event payload: event
              end
            else
              last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,").gsub(": nil}", ": null}")
              last_status = JSON.parse(last_status)
              payload.each do |event|
                found = false
                if interpolated['debug'] == 'true'
                  log "found is #{found}!"
                  log event
                end
                last_status.each do |eventbis|
                  if event == eventbis
                    found = true
                  end
                  if interpolated['debug'] == 'true'
                    log "found is #{found}!"
                  end
                end
                if found == false
                  if interpolated['debug'] == 'true'
                    log "found is #{found}! so event created"
                    log event
                  end
                  create_event payload: event
                end
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        if !payload.empty?
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
      end
    end    
  end
end
