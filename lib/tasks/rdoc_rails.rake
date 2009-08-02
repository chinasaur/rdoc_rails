require File.expand_path(File.dirname(__FILE__) + '/../rdoc_rails')

Rake::RDocTask.remove_task('doc:app')

namespace :doc do
  desc "Generate documentation for the application. Set custom template with TEMPLATE=/path/to/rdoc/template.rb Set custom format with FORMAT=format_name"
  Rake::RDocTask.new('app') { |rdoc|
    ENV['format'] ||= 'railsfish'
    rdoc.rdoc_dir = 'doc/app'
    rdoc.template = ENV['template'] if ENV['template']
    rdoc.title    = "Rails Application Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.options << '--charset' << 'utf-8'
    rdoc.options << '--format'  << ENV['format']
    rdoc.rdoc_files.include('doc/README_FOR_APP')
    rdoc.rdoc_files.include('app/**/*.rb')
    rdoc.rdoc_files.include('lib/**/*.rb')
  }
end
