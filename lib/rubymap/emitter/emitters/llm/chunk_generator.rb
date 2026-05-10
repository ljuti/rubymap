# frozen_string_literal: true

require "digest"

module Rubymap
  module Emitter
    module Emitters
      class LLM < BaseEmitter
        # Generates chunk data structures from indexed symbol data.
        #
        # Orchestrates the creation of class, module, and hierarchy chunks,
        # handling splitting of large classes across multiple chunks.
        class ChunkGenerator
          def initialize(markdown_renderer:, redactor: nil, progress_callback: nil, cross_linker: nil, max_tokens_per_chunk: nil)
            @markdown_renderer = markdown_renderer
            @redactor = redactor
            @progress_callback = progress_callback
            @cross_linker = cross_linker
            @max_tokens_per_chunk = max_tokens_per_chunk
          end

          def generate_chunks(indexed_data)
            chunks = []

            return [empty_analysis_chunk] if indexed_data.nil? || indexed_data.empty?

            chunks << no_classes_chunk if indexed_data[:classes].nil? || indexed_data[:classes].empty?

            total_items = count_total_items(indexed_data)
            processed = 0

            if indexed_data[:classes] && !indexed_data[:classes].empty?
              indexed_data[:classes].each do |klass|
                klass = Rubymap::SymbolData.new(klass)
                chunks.concat(create_class_chunks(klass))
                processed += 1
                report_progress(processed, total_items, "Processing class #{klass.fqname}")
              end
            end

            indexed_data[:modules]&.each do |mod|
              mod = Rubymap::SymbolData.new(mod)
              chunks.concat(create_module_chunks(mod))
              processed += 1
              report_progress(processed, total_items, "Processing module #{mod.fqname}")
            end

            if indexed_data[:graphs] && indexed_data[:graphs][:inheritance]
              chunks << create_hierarchy_chunk(indexed_data[:graphs][:inheritance])
              report_progress(processed, total_items, "Generating hierarchy")
            end

            chunks = @cross_linker.link_chunks(chunks) if @cross_linker

            chunks
          end

          def count_total_items(indexed_data)
            count = 0
            count += indexed_data[:classes].size if indexed_data[:classes]
            count += indexed_data[:modules].size if indexed_data[:modules]
            count += 1 if indexed_data.dig(:graphs, :inheritance)
            count
          end

          private

          def estimate_single_chunk_tokens(klass)
            content = @markdown_renderer.class_markdown(klass, include_class_keyword: true)
            estimate_tokens(content)
          end

          def report_progress(current, total, message)
            return unless @progress_callback

            percentage = (current.to_f / total * 100).round(2)
            @progress_callback.call(
              current: current,
              total: total,
              percentage: percentage,
              message: message
            )
          end

          def create_class_chunks(klass)
            total_methods = (klass.instance_methods&.size || 0) + (klass.class_methods&.size || 0)

            if total_methods > 10
              create_split_class_chunks(klass)
            else
              [create_single_class_chunk(klass)]
            end
          end

          def create_single_class_chunk(klass)
            content = @markdown_renderer.class_markdown(klass, include_class_keyword: true)

            {
              chunk_id: generate_chunk_id(klass.fqname),
              symbol_id: klass.fqname,
              type: "class",
              content: apply_redaction(content),
              tokens: estimate_tokens(content),
              metadata: {
                fqname: klass.fqname,
                type: "class",
                complexity: klass.dig(:metrics, :complexity_score),
                chunk_type: "class",
                primary_symbols: [klass.fqname],
                complexity_level: determine_complexity_level(klass),
                prerequisites: []
              }
            }
          end

          def create_split_class_chunks(klass)
            chunks = []

            overview_content = @markdown_renderer.class_overview(klass)
            chunks << {
              chunk_id: "#{generate_chunk_id(klass.fqname)}_overview",
              symbol_id: klass.fqname,
              type: "class_overview",
              content: apply_redaction(overview_content),
              tokens: estimate_tokens(overview_content),
              subtitle: "Overview and Constants",
              metadata: {
                fqname: klass.fqname,
                part: "overview",
                chunk_type: "class",
                primary_symbols: [klass.fqname],
                complexity_level: determine_complexity_level(klass),
                prerequisites: []
              }
            }

            if klass.instance_methods && !klass.instance_methods.empty?
              mid = klass.instance_methods.size / 2
              core_methods = klass.instance_methods[0...mid]
              core_content = @markdown_renderer.methods_chunk_content(klass, core_methods, "Core Methods", 2, 3)
              chunks << methods_chunk(klass, core_content, "core_methods", "Core Methods", "medium")

              if klass.instance_methods.size > 1
                helper_methods = klass.instance_methods[mid..]
                helper_content = @markdown_renderer.methods_chunk_content(klass, helper_methods, "Helper Methods", 3, 3)
                chunks << methods_chunk(klass, helper_content, "helper_methods", "Helper Methods", "low")
              end
            end

            chunks
          end

          def create_module_chunks(mod)
            content = @markdown_renderer.module_markdown(mod)

            [{
              chunk_id: generate_chunk_id(mod.fqname),
              symbol_id: mod.fqname,
              type: "module",
              content: apply_redaction(content),
              tokens: estimate_tokens(content),
              metadata: {
                fqname: mod.fqname,
                type: "module",
                chunk_type: "module",
                primary_symbols: [mod.fqname],
                complexity_level: "low",
                prerequisites: []
              }
            }]
          end

          def create_hierarchy_chunk(inheritance_data)
            content = @markdown_renderer.hierarchy_markdown(inheritance_data)

            {
              chunk_id: "hierarchy_overview",
              symbol_id: nil,
              type: "hierarchy",
              content: content,
              tokens: estimate_tokens(content),
              metadata: {
                type: "inheritance_hierarchy",
                chunk_type: "hierarchy",
                primary_symbols: [],
                complexity_level: "low",
                prerequisites: []
              }
            }
          end

          private

          def methods_chunk(klass, content, part, subtitle, complexity_level)
            {
              chunk_id: "#{generate_chunk_id(klass.fqname)}_#{part}",
              symbol_id: klass.fqname,
              type: "methods",
              content: apply_redaction(content),
              tokens: estimate_tokens(content),
              subtitle: subtitle,
              metadata: {
                fqname: klass.fqname,
                part: part,
                chunk_type: "methods",
                primary_symbols: [klass.fqname],
                complexity_level: complexity_level,
                prerequisites: []
              }
            }
          end

          def apply_redaction(content)
            return content unless @redactor
            @redactor.process_content(content)
          end

          def estimate_tokens(content)
            (content.length / 4.0).ceil
          end

          def generate_chunk_id(symbol_name)
            "chunk_#{Digest::MD5.hexdigest(symbol_name.to_s)[0..7]}"
          end

          def determine_complexity_level(klass)
            score = klass.dig(:metrics, :complexity_score) || 0
            if score > 7
              "high"
            elsif score > 4
              "medium"
            else
              "low"
            end
          end

          def empty_analysis_chunk
            {
              chunk_id: "empty_analysis",
              symbol_id: nil,
              type: "analysis",
              content: "# Code Analysis\n\nNote: Some metadata unavailable\n\nNo code structure data was provided for analysis.",
              tokens: 50,
              metadata: {chunk_type: "analysis", primary_symbols: [], complexity_level: "low", prerequisites: []}
            }
          end

          def no_classes_chunk
            {
              chunk_id: "no_classes",
              symbol_id: nil,
              type: "analysis",
              content: "# Code Analysis\n\nNo class information available\n\nThe codebase analysis did not find any class definitions.",
              tokens: 50,
              metadata: {chunk_type: "analysis", primary_symbols: [], complexity_level: "low", prerequisites: []}
            }
          end
        end
      end
    end
  end
end
