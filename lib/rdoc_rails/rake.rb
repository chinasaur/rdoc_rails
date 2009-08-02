module Rake
  def self.remove_task(task_name)
    Rake.application.instance_variable_get(:@tasks).delete(task_name.to_s) || raise('No such task!')
  end
  
  class RDocTask
    def self.remove_task(task='rdoc', opts={})
      Rake.remove_task(Rake::Task[task].prerequisites[0])
      Rake.remove_task(task)
      
      task = task.to_s.split(':')
      name = task[-1]
      path = task[0..-2] * ':'
      rerdoc  = opts[:rerdoc]       || "re#{name}"
      clobber = opts[:clobber_rdoc] || "clobber_#{name}"
      
      Rake.remove_task("#{path}:#{rerdoc}")
      Rake.remove_task("#{path}:#{clobber}")
    end
  end
end
