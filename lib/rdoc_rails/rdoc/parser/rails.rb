require 'rdoc/parser/ruby'
class RDoc::Parser::Rails < RDoc::Parser::Ruby
  include RDoc::RubyToken
  parse_files_matching(/\.rbw?$/)
  
  def parse_rails_meta(container, single, tk, comment)
    return unless container.document_children
    restore_init_token(tk)
    # Start listening to get_tk and saving read tokens into @token_stream, parse
    # symbol args
    add_token_listener self
    args = parse_symbol_arg # This gets any symbol or string args
    opts = (parse_final_hash if token_stream[-1].is_a?(TkCOMMA)) || {}
    remove_token_listener self
    
    send("parse_#{tk.name}", container, single, tk, comment, args, opts)
  end
  
  def parse_rails_debug(container, single, tk, comment, args, opts)
    puts tk.name
    puts args.inspect
    puts opts.inspect if opts
    puts ""
  end
  
  def parse_rails_pending(container, single, tk, comment, args, opts); end
  alias parse_validates_uniqueness_of parse_rails_pending
  
  def parse_ar_association(container, single, tk, comment, args, opts)
    ara =  RDoc::ArAssociation.new(
      :atype   => tk.name,
      :name    => args[0],
      :opts    => opts,
      :comment => comment
    )
    
    ara.start_collecting_tokens
    ara.add_tokens [position_comment(tk), NEWLINE_TOKEN]
    ara.add_tokens token_stream
    
    ara.parent = container
    container.ar_associations << ara
  end
  alias parse_belongs_to                parse_ar_association
  alias parse_has_one                   parse_ar_association
  alias parse_has_many                  parse_ar_association
  alias parse_has_and_belongs_to_many   parse_ar_association
  
  # Take the args, opts, and tokens collected by parse_rails_meta and generate
  # method documentation for delegated methods.
  def parse_delegate(container, single, tk, comment, args, opts)
    add_token_listener self
    skip_to_eol
    remove_token_listener self
    
    args.each do |arg|
      d_meth = RDoc::AnyMethod.new('', arg)
      @stats.add_method    d_meth
      container.add_method d_meth
      
      d_meth.start_collecting_tokens
      d_meth.add_tokens [position_comment(tk), NEWLINE_TOKEN]
      d_meth.add_tokens token_stream
      
      d_meth.params   = "(?) - delegated to #{opts[:to].inspect}" if opts[:to]
      d_meth.params ||= '(?) - delegated method...'
      
      d_meth.comment = comment
    end
  end
  
  def skip_to_eol
    tk = get_tk until tk.is_a?(TkNL)
  end
  
  # Parse tokens assumed to represent a final hash argument, thus will parse
  # either a {} enclosed hash or a naked final hash.
  #
  # The purpose of this is mainly to be able to generate documentation for Rails
  # meta calls, which generally have symbols/strings for keys and values, so
  # that is what I've prioritized being able to parse. Shouldn't be difficult to
  # add parsing of numeric keys/values. Parsing array/hash keys/values would be
  # more difficult and isn't in the scope of what I currently plan to do.  If
  # this hits something it doesn't know how to parse, it rewinds all its tokens
  # and quits.
  #
  # The best way to set up a call to parse_final_hash is as is done in
  # parse_rails_meta, where we first call parse_symbol_arg. This is good setup
  # because parse_symbol_arg will rewind to the comma before the final hash if
  # it detects a hash in parsing other args.
  def parse_final_hash
    buffer = TokenStream.new
    add_token_listener(buffer)
    skip_tkspace(true)
    
    case tk = get_tk
      when TkLBRACE           then bracketed = true
      when TkSYMBOL, TkSTRING then bracketed = false
      else
        unget_tk(tk) until buffer.token_stream.empty?
        remove_token_listener(buffer)
        return
    end
    
    last_tk = tk
    while tk = get_tk do
      case tk
        when TkSEMICOLON then break
        when TkNL
          unget_tk(tk) and break unless last_tk and TkCOMMA === last_tk
        when TkSPACE, TkCOMMENT
        when TkSYMBOL, TkSTRING, TkCOMMA, TkASSIGN, TkGT, TkASSOC then last_tk = tk # Will probably want to expand this to include numerics, possibly others; let's cross that bridge when we come to it.
        else
          break                  if  bracketed and tk.is_a?(TkRBRACE)
          unget_tk(tk) and break if !bracketed and tk.is_a?(TkDO)
          
          unget_tk(tk) until buffer.token_stream.empty?
          remove_token_listener(buffer)
          return
      end
    end
    
    remove_token_listener(buffer)
    read = buffer.token_stream.collect{|tk|tk.text}.join
    read = "{#{read}\n}" if !bracketed # We need the \n in case #{read} ends with a comment
    eval(read) rescue nil
  end
  
  # Largely copied from super, but rewinds if it hits a =>, indicating the last
  # symbol/string read should have been part of the final hash arg.  Rewinds to
  # the comma before the final hash, which provides a good check after we return
  # of whether there are still more arguments to parse.
  def parse_symbol_arg(no=nil)
    buffer = TokenStream.new
    add_token_listener(buffer)
    
    args = []
    skip_tkspace_comment
    case tk = get_tk
    when TkLPAREN
      loop do
        skip_tkspace_comment
        if tk = parse_symbol_in_arg
          args.push tk
          break if no and args.size >= no
        end
        
        skip_tkspace_comment
        case tk2 = get_tk
        when TkRPAREN
          break
        when TkCOMMA
        when TkASSOC, TkASSIGN, TkGT
          # Oops, we started slurping the final Hash!
          # So rewind back past the symbol or string that came before the =>
          unget_tk(buffer.token_stream[-1]) until buffer.token_stream[-1].is_a?(TkCOMMA) or buffer.token_stream.empty?
          args.pop
          break
        when TkLBRACE
          # We hit the beginning of a hash or block, so rewind to the comma
          unget_tk(buffer.token_stream[-1]) until buffer.token_stream[-1].is_a?(TkCOMMA) or buffer.token_stream.empty?
          break
        else
          warn("unexpected token: '#{tk2.inspect}'") if $DEBUG_RDOC
          break
        end
      end
    else
      unget_tk tk
      if tk = parse_symbol_in_arg
        args.push tk
        return args if no and args.size >= no
      end
      
      loop do
        skip_tkspace(false)
        
        tk1 = get_tk
        if TkCOMMA === tk1
        elsif TkASSOC === tk1 or TkASSIGN === tk1 or TkGT === tk1
          # Oops, we started slurping the final Hash!
          # So rewind back past the symbol or string that came before the =>
          unget_tk(buffer.token_stream[-1]) until buffer.token_stream[-1].is_a?(TkCOMMA) or buffer.token_stream.empty?
          args.pop
          break
        elsif TkLBRACE === tk1
          # We hit the beginning of a hash or block, so rewind to the comma
          unget_tk(buffer.token_stream[-1]) until buffer.token_stream[-1].is_a?(TkCOMMA) or buffer.token_stream.empty?
          break
        else
          unget_tk tk1
          break
        end
        
        skip_tkspace_comment
        if tk = parse_symbol_in_arg
          args.push tk
          break if no and args.size >= no
        end
      end
    end
    
    remove_token_listener buffer
    args
  end
  
  # Comment line required to help generator put line numbers on included source code.
  def position_comment(tk)
    TkCOMMENT.new(tk.line_no, 1, "# File #{@top_level.absolute_name}, line #{tk.line_no}")
  end
  
  # Clear @token_stream and then put back the indentation and initial token;
  # basically assumes tk is the first non-whitespace token on the line.
  def restore_init_token(tk)
    start_collecting_tokens
    indent = TkSPACE.new(1, 1)
    indent.set_text(' ' * tk.char_no)
    add_tokens([indent, tk])
  end
  
  # The identifiers that should be processed as rails meta-calls
  RAILS_IDENTIFIERS = [
    'belongs_to',
    'has_one',
    'has_many',
    'has_and_belongs_to_many',
    'delegate',
    'validates_uniqueness_of'
  ]

  # Copied from super, with a minor tweak to the TkIDENTIFIER parsing portion.
  def parse_statements(container, single = NORMAL, current_method = nil, comment = '')
    nest = 1
    save_visibility = container.visibility
    
    non_comment_seen = true
    
    while tk = get_tk do
      keep_comment = false
      
      non_comment_seen = true unless TkCOMMENT === tk
      
      case tk
      when TkNL then
        skip_tkspace true # Skip blanks and newlines
        tk = get_tk
        
        if TkCOMMENT === tk then
          if non_comment_seen then
            # Look for RDoc in a comment about to be thrown away
            parse_comment container, tk, comment unless comment.empty?
            
            comment = ''
            non_comment_seen = false
          end
          
          while TkCOMMENT === tk do
            comment << tk.text << "\n"
            tk = get_tk          # this is the newline
            skip_tkspace(false)  # leading spaces
            tk = get_tk
          end
          
          unless comment.empty? then
            look_for_directives_in container, comment
            
            if container.done_documenting then
              container.ongoing_visibility = save_visibility
            end
          end
          
          keep_comment = true
        else
          non_comment_seen = true
        end
        
        unget_tk tk
        keep_comment = true
        
      when TkCLASS then
        if container.document_children then
          parse_class container, single, tk, comment
        else
          nest += 1
        end
        
      when TkMODULE then
        if container.document_children then
          parse_module container, single, tk, comment
        else
          nest += 1
        end
        
      when TkDEF then
        if container.document_self then
          parse_method container, single, tk, comment
        else
          nest += 1
        end
        
      when TkCONSTANT then
        if container.document_self then
          parse_constant container, single, tk, comment
        end
        
      when TkALIAS then
        if container.document_self then
          parse_alias container, single, tk, comment
        end
        
      when TkYIELD then
        if current_method.nil? then
          warn "Warning: yield outside of method" if container.document_self
        else
          parse_yield container, single, tk, current_method
        end
        
      # Until and While can have a 'do', which shouldn't increase the nesting.
      # We can't solve the general case, but we can handle most occurrences by
      # ignoring a do at the end of a line.
      when  TkUNTIL, TkWHILE then
        nest += 1
        skip_optional_do_after_expression
        
      # 'for' is trickier
      when TkFOR then
        nest += 1
        skip_for_variable
        skip_optional_do_after_expression
        
      when TkCASE, TkDO, TkIF, TkUNLESS, TkBEGIN then
        nest += 1
        
      when TkIDENTIFIER then
        if nest == 1 and current_method.nil? then
          case tk.name
          when 'private', 'protected', 'public', 'private_class_method',
               'public_class_method', 'module_function' then
            parse_visibility container, single, tk
            keep_comment = true
          when 'attr' then
            parse_attr container, single, tk, comment
          when /^attr_(reader|writer|accessor)$/ then
            parse_attr_accessor container, single, tk, comment
          when 'alias_method' then
            if container.document_self then
              parse_alias container, single, tk, comment
            end
          when *RAILS_IDENTIFIERS then parse_rails_meta container, single, tk, comment
          else
            if container.document_self and comment =~ /\A#\#$/ then
              parse_meta_method container, single, tk, comment
            end
          end
        end
        
        case tk.name
        when "require" then
          parse_require container, comment
        when "include" then
          parse_include container, comment
        end
        
      when TkEND then
        nest -= 1
        if nest == 0 then
          read_documentation_modifiers container, RDoc::CLASS_MODIFIERS
          container.ongoing_visibility = save_visibility
          return
        end
        
      end
      
      comment = '' unless keep_comment
      
      begin
        get_tkread
        skip_tkspace(false)
      end while peek_tk == TkNL
    end
  end
  
end
