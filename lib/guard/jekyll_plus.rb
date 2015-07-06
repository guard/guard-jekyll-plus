# encoding: UTF-8

require 'pathname'

require 'jekyll'

require 'guard/compat/plugin'

module Guard
  class JekyllPlus < Plugin
    def initialize(options = {})
      super

      @config = Config.new(options)
      @server = Server.new(@config)
      @builder = Builder.new(@config)
    end

    def start
      @builder.build
      @server.start if @config.serve?
      @config.info 'watching'
    end

    def reload
      stop
      @config.info 'Reloading Jekyll configuration!'
      @config.reload
      @builder.reload
      start
    end

    def stop
      @server.stop
    end

    def run_on_modifications(paths)
      reload if paths.any? { |f| @config.config_file?(f) }
      @builder.modified(paths)
    end

    def run_on_additions(paths)
      @builder.added(paths)
    end

    def run_on_removals(paths)
      @builder.removed(paths)
    end

    def self.template(plugin_location)
      path = 'lib/guard/jekyll_plus/templates/Guardfile'
      (Pathname(plugin_location) + path).read
    end
  end
end

# At the end, or we'll get a circular dependency with this file
require 'guard/jekyll_plus/config'

# At the end, since these require this file
require 'guard/jekyll_plus/server'
require 'guard/jekyll_plus/builder'
require 'guard/jekyll_plus/builder/action'
require 'guard/jekyll_plus/builder/modifier'
require 'guard/jekyll_plus/builder/adder'
require 'guard/jekyll_plus/builder/remover'
require 'guard/jekyll_plus/builder/rebuilder'
