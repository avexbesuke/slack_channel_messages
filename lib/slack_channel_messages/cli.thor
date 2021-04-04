# frozen_string_literal: true

require 'thor'
require 'slack-ruby-client'
require 'tty-spinner'
require 'pry'

# module SlackChannelMessages
  class CLI < Thor
    class Generator
      def initialize(channel_id:)
        @channel_id = channel_id
        @client = Slack::Web::Client.new
      end

      # https://github.com/slack-ruby/slack-ruby-client/blob/ebf98319cf9d89ad4e75dbca0ae8ecf94a855aa3/lib/slack/web/api/endpoints/conversations.rb#L52
      def fetch
        @client.conversations_history(channel: @channel_id)
      end

      def fetch_all
        array = []
        fetch = @client.conversations_history(channel: @channel_id)
        array.push(fetch)

        while fetch.response_metadata != nil do
          fetch = @client.conversations_history(channel: @channel_id, cursor: fetch.response_metadata.next_cursor)
          array.push(fetch)
          p fetch.response_metadata
        end

        return array
      end

      # https://github.com/slack-ruby/slack-ruby-client/blob/ebf98319cf9d89ad4e75dbca0ae8ecf94a855aa3/lib/slack/web/api/endpoints/users.rb#L94
      def users
        @client.users_list().members.map {|member| {id: member.id, profile: member.profile}}
      end

      def conversations_info
        @client.conversations_info(channel: @channel_id)
      end
    end

    desc 'generate [CHANNEL_ID] [FILE_NAME]', 'generate slack channel messages'
    method_option :all, type: :boolean, default: false, aliases: '-a'
    def generate(channel_id)
      Slack.configure do |config|
        config.token = ENV['SLACK_API_TOKEN']
      end

      generator = Generator.new(channel_id: channel_id)
      users = generator.users

      TTY::Spinner.new("[:spinner] Downloading messages...", format: :pulse_2).run do
        if options.all
          messages = generator.fetch_all.flat_map(&:messages)
        else
          messages = generator.fetch.messages
        end

        File.open(file_name(generator) , mode = "w") do |f|
          messages.each do |message| 
            f.write(message(message: message, users: users)) 
          end
        end
      end

    end

    private def find_by_user_id_user_profile(users:, user_id:)
      users.find { |user| user[:id] ==  user_id}&.dig(:profile)
    end

    private def message(message:, users:)
      <<~MESSAGE
        text:\n#{message.text}
        ts: #{Time.at(message.ts.to_i)}
        user:#{find_by_user_id_user_profile(users: users, user_id: message.user)&.real_name}\n
      MESSAGE
    end

    private def file_name(generator) 
      "../../result/#{generator.conversations_info.channel.name}#{options.all ? '_all' : '' }.txt"
    end
  end
# end