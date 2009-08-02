$: << File.expand_path(File.dirname(__FILE__))

require 'rdoc_rails/rake'
require 'rdoc_rails/rdoc/context'
require 'rdoc_rails/rdoc/token_stream'
require 'rdoc_rails/rdoc/ar_association'
require 'rdoc_rails/rdoc/parser/rails'
require 'rdoc_rails/rdoc/generator/railsfish'