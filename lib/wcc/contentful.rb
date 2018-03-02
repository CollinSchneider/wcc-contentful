# frozen_string_literal: true

require 'wcc/contentful/version'
require 'contentful_model'

module WCC
  module Contentful
    class << self
      attr_accessor :configuration
      attr_reader :client
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
      config = Configuration.configure_contentful_model
      @client = ContentfulModel::Base.client
      config
    end

    class Configuration
      attr_accessor :access_token, :space, :default_locale

      def initialize
        @access_token = ''
        @space = ''
        @default_locale = ''
      end

      def self.configure_contentful_model
        ContentfulModel.configure do |config|
          config.access_token = WCC::Contentful.configuration.access_token
          config.space = WCC::Contentful.configuration.space
          config.default_locale = WCC::Contentful.configuration.default_locale
        end
      end
    end

    def self.init!
      raise ArgumentError, 'Please first call WCC:Contentful.Configure!' if configuration.nil?
    end
  end
end

require 'wcc/contentful/redirect'

require 'wcc/contentful/helpers'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model'
require 'wcc/contentful/model_builder'
require 'wcc/contentful/graphql'
