
# frozen_string_literal: true

module Contentful
  class UiExtensionGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    argument :attributes, type: :array

    def validate_and_prompt_for_args
      unless name
        given_name = ask('What do you want to name this UI extension?: ')
        until given_name && /[\w\-]+/.match(given_name)
          say('The name should contain only letters, numbers, and hyphens.')
          given_name = ask('What do you want to name this UI extension?: ')
        end
        args['name'] = given_name
      end

      unless description
        args['description'] = ask('Give the UI extension a description (leave blank to skip): ')
      end

      unless url
        given_url = ask('What is the base URL of this app?: ')
        until given_url && /^http(s)?\:\/\/.+/i.match(given_url)
          say('The base URL should begin with http(s)')
          given_url = ask('What is the base URL of this app?: ')
        end
        args['url'] = given_url
      end

      return if types&.any?
      given_types = ask('What field type(s) should this extension apply to? (comma-separated list): ')
      until (parsed_types = given_types&.split(/\,\s*/)) && parsed_types.any?
        say('Please specify at least one type, like "Symbol, Text"')
        given_types = ask('What field type(s) should this extension apply to? '\
        '(comma-separated list): ')
      end
      args['types'] = parsed_types
    end

    def install_npm_dependencies
      inside("contentful/extensions/#{name}") do
        run 'npm init -y' unless File.exist?('package.json')
        package = JSON.parse(File.read('package.json'))
        deps = package['dependencies'] || {}

        # {
        #   "contentful-ui-extensions-sdk": "^3.3",
        #   "html-webpack-inline-source-plugin": "0.0.10",
        #   "html-webpack-inline-svg-plugin": "^1.2",
        #   "html-webpack-plugin": "^3.2",
        #   "preact": "^8.2",
        #   "typescript": "^2.8",
        #   "webpack": "^4.5"
        #   "css-loader": "^0.28",
        #   "localtunnel": "^1.9",
        #   "mini-css-extract-plugin": "^0.4",
        #   "node-sass": "^4.8",
        #   "sass-loader": "^6.0",
        #   "style-loader": "^0.20",
        #   "ts-loader": "^4.1",
        #   "webpack-cli": "^2.0",
        #   "webpack-dev-server": "^3.1",
        #   "webpack-merge": "^4.1"
        # }

        deps['contentful-ui-extensions-sdk'] ||= '^3.3'
        deps['html-webpack-inline-source-plugin'] ||= '0.0.10'
        deps['html-webpack-inline-svg-plugin'] ||= '^1.2'
        deps['html-webpack-plugin'] ||= '^3.2'
        deps['preact'] ||= '^8.2'
        deps['typescript'] ||= '^2.8'
        deps['webpack'] ||= '^4.5'
        deps['css-loader'] ||= '^0.28'
        deps['localtunnel'] ||= '^1.9'
        deps['mini-css-extract-plugin'] ||= '^0.4'
        deps['node-sass'] ||= '^4.8'
        deps['sass-loader'] ||= '^6.0'
        deps['style-loader'] ||= '^0.20'
        deps['ts-loader'] ||= '^4.1'
        deps['webpack-cli'] ||= '^2.0'
        deps['webpack-dev-server'] ||= '^3.1'
        deps['webpack-merge'] ||= '^4.1'

        package['dependencies'] = deps

        scripts = package['scripts']
        scripts['build'] ||= 'webpack --config webpack.production.js && '\
          'if [[ $(du -k index.html | cut -f1) -gt 199 ]]; then '\
            'echo "\\033[0;31mindex.html is too big to be uploaded directly to contentful!"; '\
          'fi'
        scripts['serve'] ||= 'webpack-dev-server -d --config ./webpack.config.js --https'
        scripts['enable-dev'] ||= 'contentful extension create --space-id $CONTENTFUL_SPACE_ID '\
          '--src https://localhost:8080 --id ${npm_package_name}-dev'
        scripts['disable-dev'] ||= 'contentful extension delete --space-id $CONTENTFUL_SPACE_ID '\
          '--id ${npm_package_name}-dev --force'
        scripts['publish'] ||= 'contentful extension create --space-id $CONTENTFUL_SPACE_ID'

        File.write('package.json', JSON.pretty_generate(package))
      end
    end

    def add_support_files
      dir = "contentful/extensions/#{name}"

      [
        '.gitignore',
        'index.template.html',
        'tsconfig.json',
        'webpack.config.js',
        'webpack.production.js',
        'images/logo-blue.svg',
        'types/contentful-ui-extensions-sdk/index.d.ts',
        'src/index.tsx',
        'src/index.scss'
      ].each do |f|
        copy_file f, File.join(dir, f)
      end
    end

    def generate_extension_json
      parsed_url = url && URI.join(URI(url), '/contentful/extensions/', name)
      url_prop = url && "\"src\": \"#{parsed_url}\","

      create_file "contentful/extensions/#{name}/extension.json", <<~FILE
        {
          "id": "#{name}",
          "name": "#{description || name}",
          #{url_prop}
          "fieldTypes": [#{types.map { |t| "\"#{t}\"" }.join(', ')}]
        }
    FILE
    end

    private

    def name
      args['name']
    end

    def description
      args['description']
    end

    def types
      args['types']
    end

    def url
      args['url']
    end

    def args
      return @ret if @ret

      @ret = {}
      remaining = []
      attributes.each do |att|
        if m = /^([^\:]+)\:(.+)$/.match(att)
          @ret[m[1]] = m[2]
        else
          remaining.push(att)
        end
      end

      @ret['name'] ||= remaining.shift
      @ret['types'] = remaining
      @ret
    end
  end
end
