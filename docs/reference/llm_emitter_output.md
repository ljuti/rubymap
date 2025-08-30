  # Component: Ruby Code Extractor

  ## Executive Summary
  - **Purpose**: Statically analyzes Ruby source code to extract structural information
  without execution
  - **Role**: First stage of the Rubymap pipeline - transforms source code into structured
   data
  - **Technology**: Built on Prism parser for robust AST analysis
  - **Scope**: Handles files, directories, and code strings
  - **Output**: Structured extraction results with symbols and metadata

  ## Core Architecture

  ### Class Hierarchy
  Rubymap::Extractor
      ├── includes: Concerns::ResultMergeable
      ├── uses: ExtractionContext (state management)
      ├── uses: NodeVisitor (AST traversal)
      └── produces: Result (output container)

  ## Public API

  ### Rubymap::Extractor
  ```ruby
  class Extractor
    # Initialization
    .new → Extractor  # Stateless, creates fresh context per extraction

    # Core extraction methods
    #extract_from_file(file_path: String) → Result
      # Raises: ArgumentError if file doesn't exist
      # Returns: Result with file_path set

    #extract_from_code(code: String) → Result
      # Handles: Parse errors gracefully (included in result.errors)
      # Returns: Result with extracted symbols

    #extract_from_directory(directory_path: String, pattern: String = "**/*.rb") → Result
      # Raises: ArgumentError if directory doesn't exist
      # Behavior: Merges results from all matching files
      # Returns: Combined Result from all files
  end

  Rubymap::Extractor::Result

  class Result
    # Symbol collections (all arrays)
    attr_accessor :classes      # [ClassInfo]     - Class definitions
    attr_accessor :modules      # [ModuleInfo]    - Module definitions  
    attr_accessor :methods      # [MethodInfo]    - Method definitions
    attr_accessor :constants    # [ConstantInfo]  - Constant definitions
    attr_accessor :attributes   # [AttributeInfo] - attr_* declarations
    attr_accessor :mixins       # [MixinInfo]     - include/extend/prepend
    attr_accessor :dependencies # [DependencyInfo]- require/load statements
    attr_accessor :class_variables # [ClassVariableInfo] - @@variables
    attr_accessor :aliases      # [AliasInfo]     - Method aliases
    attr_accessor :patterns     # [PatternInfo]   - Detected patterns
    attr_accessor :errors       # [Hash]          - Parse/extraction errors
    attr_accessor :file_path    # String|nil      - Source file if applicable

    #add_error(error: Exception, context: String|nil) → nil
      # Stores: {message:, type:, context:} in errors array
  end

  Data Flow

  Extraction Pipeline

  Input (file/code/directory)
           ↓
      Prism.parse
           ↓
      AST (Abstract Syntax Tree)
           ↓
      NodeVisitor traversal
           ↓
      ExtractionContext (tracks namespace/visibility)
           ↓
      Symbol extraction (via specialized extractors)
           ↓
      Result object (aggregated symbols)

  Key Components & Responsibilities

  Internal Extractors

  - ClassExtractor: Extracts class definitions, superclasses, location
  - ModuleExtractor: Extracts modules, identifies concerns
  - MethodExtractor: Extracts methods with parameters, visibility, scope
  - ConstantExtractor: Extracts constants with values
  - MixinExtractor: Tracks include/extend/prepend relationships
  - AliasExtractor: Tracks method aliases
  - CallExtractor: Identifies method calls (for dependency analysis)

  Context Management

  - ExtractionContext: Maintains parsing state
    - Current namespace stack (for nested classes/modules)
    - Current visibility (public/private/protected)
    - Current class context
    - Comment associations for documentation

  Extraction Examples

  What Gets Extracted

  # Input code:
  module MyApp
    class User < ApplicationRecord
      include Searchable

      ROLES = ['admin', 'user']

      attr_reader :name

      def full_name
        "#{first_name} #{last_name}"
      end

      private

      def validate_email
        # validation logic
      end
    end
  end

  # Extracted Result:
  Result {
    modules: [
      {name: "MyApp", type: "module", namespace: "", location: {line: 1}}
    ],
    classes: [
      {name: "User", superclass: "ApplicationRecord", namespace: "MyApp", location: {line:
   2}}
    ],
    mixins: [
      {type: "include", module: "Searchable", class: "MyApp::User"}
    ],
    constants: [
      {name: "ROLES", value: "['admin', 'user']", owner: "MyApp::User"}
    ],
    attributes: [
      {name: "name", type: "reader", owner: "MyApp::User"}
    ],
    methods: [
      {name: "full_name", visibility: "public", owner: "User", namespace: "MyApp::User"},
      {name: "validate_email", visibility: "private", owner: "User", namespace:
  "MyApp::User"}
    ]
  }

  Usage Patterns

  Single File Analysis

  extractor = Rubymap::Extractor.new
  result = extractor.extract_from_file("app/models/user.rb")

  # Access extracted data
  result.classes.each { |c| puts "Found class: #{c.name}" }
  result.errors.any? # Check for parse errors

  Directory Scanning

  result = extractor.extract_from_directory("lib/")
  puts "Extracted #{result.classes.size} classes"
  puts "Extracted #{result.methods.size} methods"

  Code String Analysis

  code = File.read("snippet.rb")
  result = extractor.extract_from_code(code)

  Error Handling

  Parse Error Management

  - Behavior: Continues extraction despite errors
  - Error Storage: All errors collected in result.errors
  - Error Format: {message: String, type: String, context: String|nil}
  - Common Errors: Syntax errors, encoding issues, malformed Ruby

  Performance Characteristics

  Complexity

  - Time: O(n) where n is lines of code
  - Memory: O(m) where m is number of symbols
  - Scalability: Handles thousands of files efficiently

  Limitations

  - Static Only: No runtime information (no dynamic methods)
  - No Execution: Cannot detect metaprogrammed elements
  - Documentation: Requires YARD-style comments for doc extraction

  Integration Points

  Pipeline Position

  [Extractor] → Normalizer → Indexer → Enricher → Emitter
       ↑
   (You are here)

  Output Consumers

  - Normalizer: Takes Result, standardizes names and references
  - Direct Usage: Can be used standalone for simple AST analysis

  Common Customizations

  Custom File Patterns

  # Only extract from specific directories
  result = extractor.extract_from_directory("app/", "**/models/**/*.rb")

  Error Recovery

  result = extractor.extract_from_file(path)
  if result.errors.any?
    result.errors.each do |error|
      log.warn "Parse error in #{path}: #{error[:message]}"
    end
    # Continue with partial results
  end

  Related Components

  - Next: normalizer.md - Standardizes extracted data
  - Uses: https://github.com/ruby/prism - Ruby parsing engine
  - Produces: result.md - Output data format

  This format provides:
  1. **High-level understanding** of what the Extractor does
  2. **API reference** without implementation details
  3. **Data flow visualization** to understand the process
  4. **Practical examples** showing input/output transformation
  5. **Integration context** showing where it fits in the pipeline
  6. **Usage patterns** for common scenarios