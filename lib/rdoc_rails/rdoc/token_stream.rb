require 'rdoc/tokenstream'
module RDoc::TokenStream
  class TokenStream
    include RDoc::TokenStream
    def initialize
      start_collecting_tokens
    end
  end
end
