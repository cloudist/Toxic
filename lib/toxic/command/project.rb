require 'toxic/source/project'

desc 'Project'
command :project, :p do |c|
  c.desc 'template url'
  c.arg_name 'template-url'
  c.default_value 'https://github.com/srv7/ios-template-project.git'
  c.flag :'template-url'

  c.desc 'create xcode project'
  c.command :create, :c do |com|
    com.action do |_global_options, options, args|
      Toxic::Project::Create.new(args[0], options[:"template-url"]).run
    end
  end
end
