require 'rdoc/generator/darkfish'
class RDoc::Generator::Railsfish < RDoc::Generator::Darkfish
  RDoc::RDoc.add_generator(self)
  VERSION = '0.1.0'
  
  # Override template path to use standard darkfish template for most pages
  def initialize(opts)
    opts.instance_variable_set(:@template, 'darkfish') if opts.template == 'railsfish'
    super
  end
  
  # Overriding to allow setting templatefile to my Rails customized version.
  def generate_class_files
    debug_msg "Generating class documentation in #@outputdir"
    templatefile = Pathname.new(File.dirname(__FILE__) + '/template/railsfish/classpage.rhtml')
    
    @classes.each do |klass|
      debug_msg "  working on %s (%s)" % [ klass.full_name, klass.path ]
      outfile    = @outputdir + klass.path
      rel_prefix = @outputdir.relative_path_from( outfile.dirname )
      svninfo    = self.get_svninfo( klass )
      
      debug_msg "  rendering #{outfile}"
      self.render_template( templatefile, binding(), outfile )
    end
  end
end
