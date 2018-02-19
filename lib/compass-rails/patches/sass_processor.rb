class Sprockets::SassProcessor
  def call(input)
    puts "Sup"
    puts input
    context = input[:environment].context_class.new(input)

    paths  = input[:environment].paths.map { |path| CompassRails::SpriteImporter.new(path) }
    paths += input[:environment].paths

    options = {
      filename: input[:filename],
      syntax: self.class.syntax,
      cache_store: build_cache_store(input, @cache_version),
      load_paths: paths,
      sprockets: {
        context: context,
        environment: input[:environment],
        dependencies: context.metadata[:dependencies]
      }
    }

    engine = Autoload::Sass::Engine.new(input[:data], options)

    # Track all imported files
    sass_dependencies = Set.new([input[:filename]])
    engine.dependencies.map do |dependency|
      filename = dependency.options[:filename]
      if filename.include?('*') # Handle sprite globs
        image_path = Rails.root.join(Compass.configuration.images_dir).to_s
        Dir[File.join(image_path, filename)].each do |f|
          sass_dependencies << f.basename
          context.metadata[:dependencies] << URIUtils.build_file_digest_uri(f.basename)
        end
      else
        sass_dependencies << dependency.options[:filename]
        context.metadata[:dependencies] << URIUtils.build_file_digest_uri(dependency.options[:filename])
      end
    end

    css = Utils.module_include(Autoload::Sass::Script::Functions, @functions) do
      engine.render
    end

    context.metadata.merge(data: css, sass_dependencies: sass_dependencies)
  end
end
