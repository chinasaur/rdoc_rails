require 'rdoc/context'
class RDoc::Context
  attr_accessor :ar_associations
  
  # Overriding to initialize ar_associations
  def initialize_methods_etc
    @method_list = []
    @attributes  = []
    @aliases     = []
    @requires    = []
    @includes    = []
    @constants   = []
    @ar_associations = []
    
    # This Hash maps a method name to a list of unmatched aliases (aliases of
    # a method not yet encountered).
    @unmatched_alias_lists = {}
  end
end
