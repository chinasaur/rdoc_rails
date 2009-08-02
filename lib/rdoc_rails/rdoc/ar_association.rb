require 'active_support/inflector'
class RDoc::ArAssociation < RDoc::Context
  include RDoc::TokenStream
  attr_accessor :atype
  attr_accessor :name
  attr_writer   :opts
  
  def initialize(init={})
    super()
    init.each{ |k,v| send("#{k}=", v) }
  end
  
  def opts
    @opts || {}
  end
  
  def class_name
    class_name   = opts[:class_name]
    class_name ||= Inflector.classify(name) if ['has_many', 'has_and_belongs_to_many'].include?(atype.to_s)
    class_name ||= name.camelize
    class_name
  end
  
  def path
    parent.path
  end
  
  # Pulled from RDoc::Generator::Markup
  # Would be nice if this were moved into a module so it could be includable
  # without copy/paste.
  def add_line_numbers(src)
    if src =~ /\A.*, line (\d+)/ then
      first = $1.to_i - 1
      last  = first + src.count("\n")
      size = last.to_s.length
      
      line = first
      src.gsub!(/^/) do
        res = if line == first
                " " * (size + 2)
              else
                "%#{size}d: " % line
              end
        
        line += 1
        res
      end
    end
  end

  # Pulled from RDoc::Generator::Markup
  # Would be nice if this were moved into a module so it could be includable
  # without copy/paste.
  def markup_code
    return '' unless @token_stream
    
    src = ""
    
    @token_stream.each do |t|
      next unless t
      #        style = STYLE_MAP[t.class]
      style = case t
                when RDoc::RubyToken::TkCONSTANT then "ruby-constant"
                when RDoc::RubyToken::TkKW       then "ruby-keyword kw"
                when RDoc::RubyToken::TkIVAR     then "ruby-ivar"
                when RDoc::RubyToken::TkOp       then "ruby-operator"
                when RDoc::RubyToken::TkId       then "ruby-identifier"
                when RDoc::RubyToken::TkNode     then "ruby-node"
                when RDoc::RubyToken::TkCOMMENT  then "ruby-comment cmt"
                when RDoc::RubyToken::TkREGEXP   then "ruby-regexp re"
                when RDoc::RubyToken::TkSTRING   then "ruby-value str"
                when RDoc::RubyToken::TkVal      then "ruby-value"
                else nil
              end
      
      text = CGI.escapeHTML(t.text)
      
      if style
        src << "<span class=\"#{style}\">#{text}</span>"
      else
        src << text
      end
    end
    
    add_line_numbers src if RDoc::RDoc.current.options.include_line_numbers
    
    src
  end
end
