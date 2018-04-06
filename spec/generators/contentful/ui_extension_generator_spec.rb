# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators'
require 'generators/contentful/ui_extension_generator'

require 'generator_spec'
require 'timecop'

RSpec.describe Contentful::UiExtensionGenerator, type: :generator do
  destination Rails.root.join('tmp/generators')

  arguments [
    'slug-generator',
    'description:This is a test',
    'url:https://watermarkresources.org/',
    'Symbol',
    'Text'
  ]

  before(:all) do
    Timecop.freeze(Time.parse('2018-01-02T12:03:04'))
    prepare_destination
    run_generator
  end

  after(:all) do
    Timecop.return
  end

  let(:extension_dir) { File.join(destination_root, 'contentful/extensions/slug-generator') }

  it 'should ensure node dependencies are installed' do
    expect(destination_root).to have_structure {
      directory 'contentful' do
        directory 'extensions' do
          directory 'slug-generator' do
            file 'package.json' do
              contains '"webpack": "^4.5"'
            end
          end
        end
      end
    }
  end

  it 'should create npm scripts' do
    expect(extension_dir).to have_structure {
      file 'package.json' do
        contains '"build": "webpack --config webpack.production.js'
        contains '"serve": "webpack-dev-server -d --config ./webpack.config.js --https"'
      end
    }
  end

  it 'should copy template files' do
    expect(extension_dir).to have_structure {
      file '.gitignore'
      file 'index.template.html'
      file 'tsconfig.json'
      file 'webpack.config.js'
      file 'webpack.production.js'
      directory 'images' do
        file 'logo-blue.svg'
      end
      directory 'types' do
        directory 'contentful-ui-extensions-sdk' do
          file 'index.d.ts'
        end
      end
      directory 'src' do
        file 'index.tsx'
        file 'index.scss'
      end
    }
  end

  it 'should generate extension.json' do
    expect(extension_dir).to have_structure {
      file 'extension.json' do
        contains '"id": "slug-generator"'
        contains '"name": "This is a test"'
        contains '"src": "https://watermarkresources.org/contentful/extensions/slug-generator"'
        contains '"fieldTypes": ["Symbol", "Text"]'
      end
    }
  end
end
