# frozen_string_literal: true

require 'wcc/contentful/version'

require 'active_support'
require 'active_support/core_ext/object'

require 'wcc/contentful/configuration'
require 'wcc/contentful/exceptions'
require 'wcc/contentful/helpers'
require 'wcc/contentful/services'
require 'wcc/contentful/simple_client'
require 'wcc/contentful/store'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model_validators'
require 'wcc/contentful/model'
require 'wcc/contentful/model_methods'
require 'wcc/contentful/model_singleton_methods'
require 'wcc/contentful/model_builder'

##
# The root namespace of the wcc-contentful gem
#
# Initialize the gem with the `configure` and `init` methods inside your
# initializer.
module WCC::Contentful
  class << self
    ##
    # Gets the current configuration, after calling WCC::Contentful.configure
    attr_reader :configuration

    ##
    # Gets the sync token that was returned by the Contentful CDN after the most
    # recent invocation of WCC::Contentful.sync!
    attr_reader :next_sync_token
  end

  ##
  # Configures the WCC::Contentful gem to talk to a Contentful space.
  # This must be called first in your initializer, before #init! or accessing the
  # client.
  def self.configure
    @configuration ||= Configuration.new
    @next_sync_token = nil
    yield(configuration)

    configuration.validate!

    configuration
  end

  ##
  # Initializes the WCC::Contentful model-space and backing store.
  # This populates the WCC::Contentful::Model namespace with Ruby classes
  # that represent content types in the configured Contentful space.
  #
  # These content types can be queried directly:
  #   WCC::Contentful::Model::Page.find('1xab...')
  # Or you can inherit from them in your own app:
  #   class Page < WCC::Contentful::Model.page; end
  #   Page.find_by(slug: 'about-us')
  def self.init!
    raise ArgumentError, 'Please first call WCC:Contentful.configure' if configuration.nil?
    @mutex ||= Mutex.new

    # we want as much as possible the raw JSON from the API so use the management
    # client if possible
    client = Services.instance.management_client ||
      Services.instance.client

    @content_types = client.content_types(limit: 1000).items

    indexer =
      ContentTypeIndexer.new.tap do |ixr|
        @content_types.each { |type| ixr.index(type) }
      end
    @types = indexer.types

    store = Services.instance.store
    if store.respond_to?(:index)
      @next_sync_token = store.find("sync:#{configuration.space}:token")
      sync!
    end

    WCC::Contentful::ModelBuilder.new(@types).build_models

    # Extend all model types w/ validation & extra fields
    @types.each_value do |t|
      file = File.dirname(__FILE__) + "/contentful/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end

    require_relative 'client_ext' if defined?(::Contentful)
  end

  ##
  # Runs validations over the content types returned from the Contentful API.
  # Validations are configured on predefined model classes using the
  # `validate_field` directive.  Example:
  #    validate_field :top_button, :Link, :optional, link_to: 'menuButton'
  # This results in a WCC::Contentful::ValidationError
  # if the 'topButton' field in the 'menu' content type is not a link.
  def self.validate_models!
    # Ensure application models are loaded before we validate
    Dir[Rails.root.join('app/models/**/*.rb')].each { |file| require file } if defined?(Rails)

    content_types = WCC::Contentful::ModelValidators.transform_content_types_for_validation(
      @content_types
    )
    errors = WCC::Contentful::Model.schema.call(content_types)
    raise WCC::Contentful::ValidationError, errors.errors unless errors.success?
  end

  ##
  # Calls the Contentful Sync API and updates the configured store with the returned
  # data.
  #
  # up_to_id: An ID that we know has changed and should come back from the sync.
  #           If we don't find this ID in the sync data, then drop a job to try
  #           the sync again after a few minutes.
  #
  def self.sync!(up_to_id: nil)
    store = Services.instance.store
    client = Services.instance.client
    return unless store.respond_to?(:index)

    @mutex.synchronize do
      sync_resp = client.sync(sync_token: next_sync_token)

      id_found = up_to_id.nil?

      sync_resp.items.each do |item|
        id = item.dig('sys', 'id')
        id_found ||= id == up_to_id
        store.index(item)
      end
      store.set("sync:#{configuration.space}:token", sync_resp.next_sync_token)
      @next_sync_token = sync_resp.next_sync_token

      unless id_found
        raise SyncError, "ID '#{up_to_id}' did not come back via sync." unless defined?(Rails)
        sync_later!(up_to_id: up_to_id)
      end
      next_sync_token
    end
  end

  ##
  # Drops an ActiveJob job to invoke WCC::Contentful.sync! after a given amount
  # of time.
  def self.sync_later!(up_to_id: nil, wait: 10.minutes)
    raise NotImplementedError, 'Cannot sync_later! outside of a Rails app' unless defined?(Rails)

    WCC::Contentful::DelayedSyncJob.set(wait: wait).perform_later(up_to_id)
  end

  # TODO: https://zube.io/watermarkchurch/development/c/2234 init graphql
  # def self.init_graphql!
  #   require 'wcc/contentful/graphql'
  #   etc...
  # end
end
