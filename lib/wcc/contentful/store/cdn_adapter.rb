# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
    attr_reader :client

    # Intentionally not implementing write methods

    def initialize(client)
      super()
      @client = client
    end

    def find(key)
      entry =
        begin
          client.entry(key, locale: '*')
        rescue WCC::Contentful::SimpleClient::NotFoundError
          client.asset(key, locale: '*')
        end
      entry&.raw
    rescue WCC::Contentful::SimpleClient::NotFoundError
      nil
    end

    def find_by(content_type:, filter: nil)
      # default implementation - can be overridden
      q = find_all(content_type: content_type)
      q = q.apply(filter) if filter
      q.first
    end

    def find_all(content_type:)
      Query.new(@client, content_type: content_type)
    end

    class Query < Base::Query
      delegate :count, to: :resolve

      def result
        resolve.items
      end

      def initialize(client, relation)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?
        @client = client
        @relation = relation
      end

      def apply_operator(operator, field, expected, context = nil)
        op = operator == :eq ? nil : operator
        param = parameter(field, operator: op, context: context)

        Query.new(@client, @relation.merge(param => expected))
      end

      def nested_conditions(field, conditions, context)
        base_param = parameter(field, locale: false)

        conditions.reduce(self) do |query, (ref, value)|
          nested = parameter(ref, locale: false)

          query.apply({ "#{base_param}.#{nested}" => value }, context)
        end
      end

      private

      def parameter(field, operator: nil, context: nil, locale: true)
        if sys?(field)
          "#{sys_reference(field)}#{op_param(operator)}"
        else
          "#{field_reference(field)}#{locale(context) if locale}#{op_param(operator)}"
        end
      end

      def locale(context)
        ".#{(context || {}).fetch(:locale, 'en-US')}"
      end

      def op_param(operator)
        operator ? "[#{operator}]" : ''
      end

      SYS_FIELDS = %w[
        id
        type
        createdAt
        updatedAt
        revision
        locale

        contentType
        space
        environment
      ].freeze

      def sys?(field)
        SYS_FIELDS.any? { |f| field.to_s =~ /#{f}$/ }
      end

      def sys_reference(field)
        return field if nested?(field)

        if %i[contentType space environment].include?(field.to_sym)
          "sys.#{field}.sys.id"
        else
          "sys.#{field}"
        end
      end

      def field_reference(field)
        return field if nested?(field)

        "fields.#{field}"
      end

      def nested?(field)
        field.to_s.include?('.')
      end

      def resolve
        return @resolve if @resolve
        @resolve ||=
          if @relation[:content_type] == 'Asset'
            @client.assets(
              { locale: '*' }.merge!(@relation.reject { |k| k == :content_type })
            )
          else
            @client.entries({ locale: '*' }.merge!(@relation))
          end
      end
    end
  end
end
