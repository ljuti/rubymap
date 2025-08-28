# frozen_string_literal: true

require "ostruct"

module Rubymap
  class Indexer
    # Search engine with fuzzy matching capabilities
    class SearchEngine
      class << self
        def fuzzy_search(symbol_index, query, threshold = 0.7)
          return [] if query.nil? || query.empty?
          
          results = []
          
          symbol_index.all.each do |symbol|
            score = calculate_similarity(query.downcase, symbol.name.downcase)
            
            if score >= threshold
              results << FuzzyResult.new(symbol, score)
            end
          end
          
          # Sort by score descending and return wrapped results
          results.sort_by { |r| -r.score }.map do |result|
            # Return OpenStruct with name and score attributes
            OpenStruct.new(
              name: result.symbol.name,
              score: result.score,
              symbol: result.symbol
            )
          end
        end

        private

        # Simple Levenshtein distance-based similarity
        def calculate_similarity(str1, str2)
          return 1.0 if str1 == str2
          return 0.0 if str1.empty? || str2.empty?
          
          # Use length-based similarity for simplicity
          # In production, would use proper Levenshtein distance
          longer = [str1.length, str2.length].max.to_f
          shorter = [str1.length, str2.length].min.to_f
          
          # Check if one string contains the other
          if str1.include?(str2) || str2.include?(str1)
            return 0.9 + (shorter / longer * 0.1)
          end
          
          # Check if query is a prefix (common for autocomplete)
          if str2.start_with?(str1)
            # Score based on how much of the target string matches
            return 0.8 + (str1.length.to_f / str2.length * 0.2)
          end
          
          # Check common prefix
          common_prefix = 0
          [str1.length, str2.length].min.times do |i|
            if str1[i] == str2[i]
              common_prefix += 1
            else
              break
            end
          end
          
          if common_prefix > 0
            # Give higher score for prefix matches
            prefix_ratio = common_prefix.to_f / str1.length
            return [0.7 * prefix_ratio + 0.3 * (common_prefix.to_f / longer), 0.95].min
          end
          
          # Simple character overlap
          chars1 = str1.chars.uniq
          chars2 = str2.chars.uniq
          overlap = (chars1 & chars2).size
          union = (chars1 | chars2).size
          
          overlap.to_f / union
        end
      end

      # Result wrapper for fuzzy search
      class FuzzyResult
        attr_reader :symbol, :score

        def initialize(symbol, score)
          @symbol = symbol
          @score = score
        end
      end
    end
  end
end