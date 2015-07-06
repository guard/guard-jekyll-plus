require 'jekyll'

# Workaround for issue:
# 1. Bundler's require mechanism is not used in Guard (should be)
# 2. This file is alone included from the Guardfile
# 3. The Guard::JekyllPlus::Config class is defined ...
# 4. ... but this means Guard::JekyllPlus is also defined
# 5. Guard detects that Guard::JekyllPlus is defined
# 6. Guard considers Guard::JekyllPlus loaded, so ...
# 7. Guard::JekyllPlus has no methods (run_on_modifications, etc.)
# 8. Since Guard::JekyllPlus has no methods, nothing happens when files change
#
# So, detect if this file was loaded from the Guardfile and load the real, full
# Guard::JekyllPlus class if it hasn't been loaded already
require 'guard/jekyll_plus' unless defined?(Guard::JekyllPlus)

module Guard
  class JekyllPlus < Plugin
    class Config
      EXTS = %w(md mkd mkdn markdown textile html haml slim xml yml sass scss)

      class TerribleConfiguration < RuntimeError
      end

      def initialize(options)
        @options = {
          extensions: [],
          config: ['_config.yml'],
          serve: false,
          rack_config: nil,
          drafts: false,
          future: false,
          config_hash: nil,
          silent: false,
          msg_prefix: 'Jekyll '
        }.merge(options)

        @jekyll_config = load_config(@options)

        @source = local_path(@jekyll_config['source'])
        @destination = local_path(@jekyll_config['destination'])
        @msg_prefix = @options[:msg_prefix]

        # Convert array of extensions into a regex for matching file extensions
        # eg, /\.md$|\.markdown$|\.html$/i
        #
        extensions  = @options[:extensions].concat(EXTS).flatten.uniq
        extensions.map! { |e| Regexp.quote(e.sub(/^\./, '')) }
        @extensions = /\.(?:#{extensions.join('|')})$/i
      end

      attr_reader :extensions
      attr_reader :destination
      attr_reader :jekyll_config

      def server_options
        jekyll_config
      end

      def config_file?(file)
        config_files.include?(file)
      end

      def reload
        @jekyll_config = load_config(@options)
      end

      def info(msg)
        Compat::UI.info(@msg_prefix + msg) unless silent?
      end

      def error(msg)
        Compat::UI.error(@msg_prefix + msg)
      end

      def source
        @jekyll_config['source']
      end

      def serve?
        @options[:serve]
      end

      def host
        @jekyll_config['host']
      end

      def baseurl
        @jekyll_config['baseurl']
      end

      def port
        @jekyll_config['port']
      end

      def rack_config
        @options[:rack_config]
      end

      def rack_environment
        silent? ? nil : 'development'
      end

      alias_method :server_root, :destination
      alias_method :jekyll_serve_options, :jekyll_config

      def excluded?(path)
        @jekyll_config['exclude'].any? { |glob| File.fnmatch?(glob, path) }
      end

      def watch_regexp
        if destination_includes_source?
          fail(
            TerribleConfiguration,
            'Fatal: source directory is inside destination directory!')
        end

        add_configs_to_regexp(source_and_dest_pattern)
      end

      private

      def source_and_dest_pattern
        q_src = source == '.' ? '' : Regexp.quote("#{source}/")

        return "#{q_src}.*" unless source_includes_destination?

        q_rel_dst = Regexp.quote("#{relative_destination}/")
        "#{q_src}(?!#{q_rel_dst}).*"
      end

      def add_configs_to_regexp(pattern)
        quoted_configs = config_files.map { |file| Regexp.quote(file) }
        parts = [pattern] + quoted_configs
        /^#{parts.join('$|')}$/
      end

      def relative_destination
        p_dst = Pathname(File.realpath(destination))
        p_src = Pathname(File.realpath(source))
        p_dst.relative_path_from(p_src).to_s
      end

      def silent?
        @options[:silent] || @options['silent']
      end

      def load_config(options)
        config = ::Jekyll.configuration(jekyllize_options(options))

        # Override configuration with guard option values
        config['show_drafts'] = options[:drafts]
        config['future']      = options[:future]
        config
      end

      def config_files
        @options[:config]
      end

      def jekyllize_options(options)
        opts = options.dup
        return opts[:config_hash] if opts[:config_hash]
        return opts unless opts[:config]
        opts[:config] = [opts[:config]] unless opts[:config].is_a? Array
        opts
      end

      def local_path(path)
        # TODO: what is this for?
        Dir.chdir('.')

        current = Dir.pwd
        path = path.sub current, ''
        if path == ''
          './'
        else
          path.sub(%r{^/}, '')
        end
      end

      def destination_includes_source?
        File.realpath(source).start_with?(File.realpath(destination))
      end

      def source_includes_destination?
        File.realpath(destination).start_with?(File.realpath(source))
      end
    end
  end
end
