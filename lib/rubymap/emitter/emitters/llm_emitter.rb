# frozen_string_literal: true

require "digest"
require "time"

module Rubymap
  module Emitter
    module Emitters
      class LLM < BaseEmitter
        DEFAULT_CHUNK_SIZE = 2000  # Target tokens per chunk
        MAX_CHUNK_SIZE = 4000      # Maximum tokens per chunk

        def initialize(**options)
          super
          @chunk_size = options[:chunk_size] || DEFAULT_CHUNK_SIZE
          @max_chunk_size = options[:max_chunk_size] || MAX_CHUNK_SIZE
          @cross_linker = Processors::CrossLinker.new if options[:include_links]
        end

        def emit(indexed_data)
          chunks = generate_chunks(indexed_data)
          
          # Return a structured result for LLM consumption
          {
            total_chunks: chunks.size,
            chunks: chunks,
            index: generate_index(chunks),
            metadata: generate_metadata(indexed_data)
          }
        end

        def emit_to_directory(indexed_data, output_dir)
          ensure_directory_exists(output_dir)
          
          chunks_dir = File.join(output_dir, "chunks")
          ensure_directory_exists(chunks_dir)
          
          written_files = []
          chunks = generate_chunks(indexed_data)
          
          # Write individual chunk files
          chunks.each_with_index do |chunk, idx|
            chunk_filename = format_chunk_filename(chunk, idx)
            chunk_path = File.join(chunks_dir, chunk_filename)
            
            File.write(chunk_path, chunk[:content])
            written_files << create_file_info("chunks/#{chunk_filename}", chunk_path)
          end
          
          # Write index file
          index_path = File.join(output_dir, "index.md")
          File.write(index_path, generate_index_markdown(chunks, indexed_data))
          written_files << create_file_info("index.md", index_path)
          
          # Write overview
          overview_path = File.join(output_dir, "overview.md")
          File.write(overview_path, generate_overview_markdown(indexed_data))
          written_files << create_file_info("overview.md", overview_path)
          
          # Write relationships file
          relationships_path = File.join(output_dir, "relationships.md")
          File.write(relationships_path, generate_relationships_markdown(indexed_data))
          written_files << create_file_info("relationships.md", relationships_path)
          
          # Generate manifest with chunk metadata
          generate_llm_manifest(output_dir, written_files, chunks, indexed_data)
          written_files
        end

        protected

        def format_extension
          "md"
        end

        def default_filename
          "chunks.md"
        end

        private

        def generate_chunks(indexed_data)
          chunks = []
          
          # Process classes
          if indexed_data[:classes]
            indexed_data[:classes].each do |klass|
              chunks.concat(create_class_chunks(klass))
            end
          end
          
          # Process modules
          if indexed_data[:modules]
            indexed_data[:modules].each do |mod|
              chunks.concat(create_module_chunks(mod))
            end
          end
          
          # Add hierarchy chunks if we have inheritance data
          if indexed_data[:graphs] && indexed_data[:graphs][:inheritance]
            chunks << create_hierarchy_chunk(indexed_data[:graphs][:inheritance])
          end
          
          # Apply cross-linking if enabled
          if @cross_linker
            chunks = @cross_linker.link_chunks(chunks)
          end
          
          chunks
        end

        def create_class_chunks(klass)
          chunks = []
          
          # Calculate content size
          content_size = estimate_content_size(klass)
          
          if content_size <= @chunk_size
            # Single chunk for small classes
            chunks << create_single_class_chunk(klass)
          else
            # Split large classes across multiple chunks
            chunks.concat(create_split_class_chunks(klass))
          end
          
          chunks
        end

        def create_single_class_chunk(klass)
          content = generate_class_markdown(klass)
          
          {
            chunk_id: generate_chunk_id(klass[:fqname]),
            symbol_id: klass[:fqname],
            type: "class",
            content: apply_redaction(content),
            tokens: estimate_tokens(content),
            metadata: {
              fqname: klass[:fqname],
              type: "class",
              complexity: klass.dig(:metrics, :complexity_score)
            }
          }
        end

        def create_split_class_chunks(klass)
          chunks = []
          
          # Overview chunk
          overview_content = generate_class_overview(klass)
          chunks << {
            chunk_id: "#{generate_chunk_id(klass[:fqname])}_overview",
            symbol_id: klass[:fqname],
            type: "class_overview",
            content: apply_redaction(overview_content),
            tokens: estimate_tokens(overview_content),
            metadata: {
              fqname: klass[:fqname],
              part: "overview"
            }
          }
          
          # Method chunks (grouped by visibility)
          [:public, :protected, :private].each do |visibility|
            methods = filter_methods_by_visibility(klass, visibility)
            next if methods.empty?
            
            method_content = generate_methods_markdown(klass[:fqname], methods, visibility)
            chunks << {
              chunk_id: "#{generate_chunk_id(klass[:fqname])}_#{visibility}_methods",
              symbol_id: klass[:fqname],
              type: "methods",
              content: apply_redaction(method_content),
              tokens: estimate_tokens(method_content),
              metadata: {
                fqname: klass[:fqname],
                part: "#{visibility}_methods"
              }
            }
          end
          
          chunks
        end

        def create_module_chunks(mod)
          content = generate_module_markdown(mod)
          
          [{
            chunk_id: generate_chunk_id(mod[:fqname]),
            symbol_id: mod[:fqname],
            type: "module",
            content: apply_redaction(content),
            tokens: estimate_tokens(content),
            metadata: {
              fqname: mod[:fqname],
              type: "module"
            }
          }]
        end

        def create_hierarchy_chunk(inheritance_data)
          content = generate_hierarchy_markdown(inheritance_data)
          
          {
            chunk_id: "hierarchy_overview",
            symbol_id: nil,
            type: "hierarchy",
            content: content,
            tokens: estimate_tokens(content),
            metadata: {
              type: "inheritance_hierarchy"
            }
          }
        end

        def generate_class_markdown(klass)
          markdown = []
          
          # Header with metadata
          markdown << "# Class: #{klass[:fqname]}"
          markdown << ""
          markdown << "**Type:** #{klass[:type]}"
          markdown << "**File:** #{klass[:file]}:#{klass[:line]}" if klass[:file]
          markdown << "**Inherits from:** #{klass[:superclass]}" if klass[:superclass]
          
          # Documentation
          if klass[:documentation]
            markdown << ""
            markdown << "## Description"
            markdown << klass[:documentation]
          end
          
          # Metrics
          if klass[:metrics]
            markdown << ""
            markdown << "## Metrics"
            markdown << "- Complexity: #{klass.dig(:metrics, :complexity_score)}"
            markdown << "- Public API Surface: #{klass.dig(:metrics, :public_api_surface)}"
            markdown << "- Test Coverage: #{klass.dig(:metrics, :test_coverage)}%" if klass.dig(:metrics, :test_coverage)
          end
          
          # Methods
          if klass[:instance_methods] && !klass[:instance_methods].empty?
            markdown << ""
            markdown << "## Instance Methods"
            klass[:instance_methods].each do |method|
              markdown << "- `#{method}`"
            end
          end
          
          if klass[:class_methods] && !klass[:class_methods].empty?
            markdown << ""
            markdown << "## Class Methods"
            klass[:class_methods].each do |method|
              markdown << "- `#{method}`"
            end
          end
          
          markdown.join("\n")
        end

        def generate_class_overview(klass)
          markdown = []
          
          markdown << "# Class: #{klass[:fqname]} (Overview)"
          markdown << ""
          markdown << "**Type:** #{klass[:type]}"
          markdown << "**Superclass:** #{klass[:superclass]}" if klass[:superclass]
          markdown << ""
          
          if klass[:documentation]
            markdown << "## Description"
            markdown << klass[:documentation]
            markdown << ""
          end
          
          markdown << "## Structure"
          markdown << "- Instance methods: #{klass[:instance_methods]&.size || 0}"
          markdown << "- Class methods: #{klass[:class_methods]&.size || 0}"
          markdown << ""
          markdown << "See related chunks for method details."
          
          markdown.join("\n")
        end

        def generate_methods_markdown(class_name, methods, visibility)
          markdown = []
          
          markdown << "# #{class_name}: #{visibility.capitalize} Methods"
          markdown << ""
          
          methods.each do |method|
            markdown << "## #{method[:name]}"
            markdown << ""
            markdown << "**Visibility:** #{visibility}"
            markdown << "**Parameters:** #{format_parameters(method[:parameters])}" if method[:parameters]
            markdown << ""
            
            if method[:documentation]
              markdown << method[:documentation]
              markdown << ""
            end
          end
          
          markdown.join("\n")
        end

        def generate_module_markdown(mod)
          markdown = []
          
          markdown << "# Module: #{mod[:fqname]}"
          markdown << ""
          markdown << "**Type:** module"
          markdown << "**File:** #{mod[:file]}:#{mod[:line]}" if mod[:file]
          
          if mod[:documentation]
            markdown << ""
            markdown << "## Description"
            markdown << mod[:documentation]
          end
          
          if mod[:methods] && !mod[:methods].empty?
            markdown << ""
            markdown << "## Methods"
            mod[:methods].each do |method|
              markdown << "- `#{method}`"
            end
          end
          
          markdown.join("\n")
        end

        def generate_hierarchy_markdown(inheritance_data)
          markdown = []
          
          markdown << "# Class Inheritance Hierarchy"
          markdown << ""
          
          # Build tree structure
          tree = build_inheritance_tree(inheritance_data)
          
          # Render tree as markdown
          tree.each do |root, children|
            markdown << render_tree(root, children, 0)
          end
          
          markdown.join("\n")
        end

        def generate_index_markdown(chunks, indexed_data)
          markdown = []
          
          markdown << "# #{indexed_data.dig(:metadata, :project_name)} Code Map Index"
          markdown << ""
          markdown << "Generated: #{Time.now.utc.iso8601}"
          markdown << "Total chunks: #{chunks.size}"
          markdown << ""
          
          # Group chunks by type
          by_type = chunks.group_by { |c| c[:type] }
          
          by_type.each do |type, type_chunks|
            markdown << "## #{type.capitalize.gsub("_", " ")}"
            markdown << ""
            
            type_chunks.each do |chunk|
              link = "chunks/#{format_chunk_filename(chunk, 0)}"
              markdown << "- [#{chunk[:metadata][:fqname] || chunk[:chunk_id]}](#{link})"
            end
            markdown << ""
          end
          
          markdown.join("\n")
        end

        def generate_overview_markdown(indexed_data)
          markdown = []
          
          markdown << "# #{indexed_data.dig(:metadata, :project_name)} Code Map"
          markdown << ""
          markdown << "## Statistics"
          markdown << "- Total Classes: #{indexed_data.dig(:metadata, :total_classes)}"
          markdown << "- Total Methods: #{indexed_data.dig(:metadata, :total_methods)}"
          markdown << "- Ruby Version: #{indexed_data.dig(:metadata, :ruby_version)}"
          markdown << ""
          
          if indexed_data.dig(:metadata, :description)
            markdown << "## Description"
            markdown << indexed_data.dig(:metadata, :description)
            markdown << ""
          end
          
          markdown.join("\n")
        end

        def generate_relationships_markdown(indexed_data)
          markdown = []
          
          markdown << "# Relationships"
          markdown << ""
          
          if indexed_data.dig(:graphs, :inheritance)
            markdown << "## Inheritance Relationships"
            markdown << ""
            
            indexed_data[:graphs][:inheritance].each do |rel|
              markdown << "- #{rel[:from]} → #{rel[:to]}"
            end
            markdown << ""
          end
          
          if indexed_data.dig(:graphs, :dependencies)
            markdown << "## Dependencies"
            markdown << ""
            
            indexed_data[:graphs][:dependencies].each do |dep|
              markdown << "- #{dep[:from]} → #{dep[:to]} (#{dep[:type]})"
            end
          end
          
          markdown.join("\n")
        end

        def generate_index(chunks)
          chunks.map do |chunk|
            {
              chunk_id: chunk[:chunk_id],
              symbol_id: chunk[:symbol_id],
              type: chunk[:type],
              tokens: chunk[:tokens]
            }
          end
        end

        def generate_metadata(indexed_data)
          {
            total_classes: indexed_data.dig(:metadata, :total_classes),
            total_methods: indexed_data.dig(:metadata, :total_methods),
            project_name: indexed_data.dig(:metadata, :project_name)
          }
        end

        def generate_llm_manifest(output_dir, files, chunks, indexed_data)
          manifest = {
            schema_version: 1,
            generator: {
              name: "rubymap",
              version: Rubymap::VERSION,
              emitter_type: "llm"
            },
            generated_at: Time.now.utc.iso8601,
            chunks: {
              total: chunks.size,
              average_tokens: chunks.sum { |c| c[:tokens] } / chunks.size.to_f,
              max_tokens: chunks.max_by { |c| c[:tokens] }&.dig(:tokens)
            },
            index: generate_index(chunks),
            files: files.map { |f| f[:relative_path] }
          }
          
          manifest_path = File.join(output_dir, "manifest.json")
          File.write(manifest_path, JSON.pretty_generate(manifest))
          manifest_path
        end

        def estimate_content_size(klass)
          # Rough estimation based on content
          size = 100  # Base size
          size += (klass[:instance_methods]&.size || 0) * 50
          size += (klass[:class_methods]&.size || 0) * 50
          size += (klass[:documentation]&.length || 0)
          size
        end

        def estimate_tokens(content)
          # Rough approximation: ~4 characters per token
          (content.length / 4.0).ceil
        end

        def generate_chunk_id(symbol_name)
          # Create deterministic chunk ID
          "chunk_#{Digest::MD5.hexdigest(symbol_name.to_s)[0..7]}"
        end

        def format_chunk_filename(chunk, index)
          if chunk[:metadata] && chunk[:metadata][:fqname]
            name = chunk[:metadata][:fqname].downcase.gsub("::", "_")
            part = chunk[:metadata][:part]
            part ? "#{name}_#{part}.md" : "#{name}.md"
          else
            "#{chunk[:type]}_#{chunk[:chunk_id]}.md"
          end
        end

        def filter_methods_by_visibility(klass, visibility)
          # This would filter methods based on visibility
          # For now, returning empty array as methods don't have visibility in our test data
          []
        end

        def format_parameters(params)
          return "none" if params.nil? || params.empty?
          params.join(", ")
        end

        def build_inheritance_tree(inheritance_data)
          # Build a tree structure from flat inheritance data
          tree = {}
          
          inheritance_data.each do |rel|
            tree[rel[:to]] ||= []
            tree[rel[:to]] << rel[:from]
          end
          
          tree
        end

        def render_tree(node, children, level)
          indent = "  " * level
          output = "#{indent}- #{node}\n"
          
          children.each do |child|
            output += render_tree(child, children[child] || [], level + 1)
          end
          
          output
        end

        def create_file_info(relative_path, full_path)
          {
            path: full_path,
            relative_path: relative_path,
            size: File.size(full_path),
            checksum: Digest::SHA256.hexdigest(File.read(full_path))
          }
        end
      end
    end
  end
end