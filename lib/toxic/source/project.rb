require 'xcodeproj'
require 'cli/ui'
require 'date'

module Toxic
  module Project
    class Create

      attr_accessor :name, :template_url, :author, :organization, :repository_address
      attr_accessor :template_name, :template_author, :template_organization

      def initialize(name, template_url)
        @name = name
        @template_url = template_url
      end

      def run
        validate!
        clone_template
        get_template_info
        remove_useless
        ask_info_for_new
        configure_template
        set_bundle_identifiers
        add_git_repository
        pod_install
        add_fastlane
        open_project
      end

      def validate!
        raise "A name for the project is required." unless name
        raise "The project name cannot contain spaces." if name =~ /\s/
        raise "The project name cannot begin with a '.'" if name[0, 1] == '.'
      end

      def clone_template
        if Dir.exist?(Pathname("./#{name}"))
          question = CLI::UI.fmt("{{red: Folder #{name} already exists, do you want to overwrite it? (y/n)}}")
          override = CLI::UI.ask(question, default: 'n')
          if override == 'y'
            puts CLI::UI.fmt("deleting #{name}")
            system "rm -rf ./#{name}"
          else
            exit(0)
          end
        end
        system "git clone #{@template_url} #{name}"
      end

      def get_template_info
        template_path = Dir.glob("./#{name}/**/**/*.xcodeproj").first
        @template_name = File.basename(template_path, '.xcodeproj')
        @template_author, @template_organization = template_author_organization
      end

      def ask_info_for_new
        puts CLI::UI.fmt("{{green: Let's go over some question to create your base project code!}}")

        @author = CLI::UI.ask('author for the project:')
        @organization = CLI::UI.ask('organization for the project:')
      end

      def remove_useless
        system "rm -rf ./#{name}/.git"
        system "rm -rf ./#{name}/**/xcuserdata/"
        system "rm -rf ./#{name}/**/**/xcuserdata/"
        system "rm -rf ./#{name}/**/**/xcshareddata"
      end

      def configure_template
        traverse_dir(Pathname("./#{name}"))
      end

      def set_bundle_identifiers
        puts CLI::UI.fmt("{{cyan: Let's setup your bundle identifiers}}")
        project_path = Dir.glob("./#{name}/**/**/#{name}.xcodeproj").first
        project = Xcodeproj::Project.open(project_path)
        project.targets.each do |target|
          target.build_configurations.each do |config|
            original_bundle_identifier = config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
            question = CLI::UI.fmt("target {{green:#{target}}} under {{green:#{config}}} configuration")
            answer = CLI::UI.ask(question, default: original_bundle_identifier)
            config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = answer
          end
        end
        project.save
      end

      def add_git_repository
        Dir.chdir("#{name}") do |_|
          puts CLI::UI.fmt("{{green: initializing git}}")
          @repository_address = CLI::UI.ask('repository address for the project:')
          system "git init"
          system "git remote add origin #{repository_address}" unless repository_address.empty?
        end
      end

      def pod_install
        Dir.chdir("#{name}") do |_|
          if File.exists?('Podfile')
            decision = CLI::UI.ask("Podfile detected, do you want to exec 'pod install' ?", options: %w(install later))
            case decision
            when 'install'
              system "pod install"
            else break
            end
          end
        end
      end

      def add_fastlane
        decision = CLI::UI.ask("do you want to add fastlane to your project? (y/n)", default: 'y')
        nil unless decision == 'y'
        system "sudo gem install fastlane -NV" unless `which fastlane`
        Dir.chdir("#{name}") do |_|
          system "fastlane init"
        end
      end

      def open_project
        project = Dir.glob("./**/**/#{name}.xcworkspace").first
        project = Dir.glob("./**/**/#{name}.xcodeproj") unless Dir.glob(project).any?
        system "open #{project}"
      end

      def traverse_dir(file_path)
        if File.directory?(file_path)
          file_path = rename(file_path)
          Dir.each_child(file_path) do |file|
            traverse_dir(file_path + file)
          end
        else
          update_content(file_path)
        end
      end

      def template_author_organization
        app_delegate_swift_path = Dir.glob("./#{name}/**/**/*AppDelegate*.swift").last
        raise "Can't find your AppDelegate file" if app_delegate_swift_path.nil?

        author = File.open(app_delegate_swift_path) do |file|
          file.each_line.with_index do |line, _|
            break line if /^\/\/ {2}Created by/ =~ line
          end
        end

        organization = File.open(app_delegate_swift_path) do |file|
          file.each_line do |line|
            break line if /^\/\/ {2}Copyright ©/ =~ line
          end
        end
        index1 = author.index 'by'
        index2 = author.index 'on'
        author = author[index1+3 ... index2]

        index3 = organization.index '©'
        index4 = organization.index '.'
        organization = organization[index3+7 ... index4]

        [author, organization]
      end

      def rename(original_name)
        name_new = original_name.sub(Regexp.new(Regexp.escape(template_name), Regexp::IGNORECASE), name)
        File.rename(original_name, name_new)
        name_new
      end

      def update_content(file_path)
        puts "updating #{file_path}"

        begin

          file = File.new("#{file_path}_new", "w+")
          origin = File.open(file_path, "r:UTF-8" )
          origin.each do |line|
            line = "//  Created by #{author} on #{Date.today}." if /^\/\/ {2}Created by/ =~ line
            line = "//  Copyright © 2018 #{organization}. All rights reserved." if /^\/\/ {2}Copyright ©/ =~ line
            line.gsub!(template_name, name)
            # line.gsub!(Regexp.new(Regexp.escape(template_name), Regexp::IGNORECASE), name)
            # line.gsub!(Regexp.new(Regexp.escape(template_organization), Regexp::IGNORECASE), organization)
            # line.gsub!(Regexp.new(Regexp.escape(template_author), Regexp::IGNORECASE), author)
            file.puts line
          end
          origin.close
          file.close
          File.delete(origin)
          File.rename("#{file_path}_new", file_path)

        rescue Exception
# ignored
        end
        rename(file_path)
      end
    end
  end
end