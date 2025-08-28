# Normalizer Architecture

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                       Normalizer (Facade)                    │
│                    Orchestrates all components               │
└─────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                      │
                    ▼                      ▼
        ┌──────────────────┐    ┌──────────────────┐
        │ NormalizerRegistry│    │   SymbolIndex    │
        │   (DI Container)  │    │  (Fast Lookup)   │
        └──────────────────┘    └──────────────────┘
                    │
        ┌───────────┴─────────────┬─────────────┬──────────────┐
        ▼                         ▼             ▼              ▼
┌──────────────┐        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Processors  │        │  Resolvers   │ │ Normalizers  │ │Deduplication │
│ (6 classes)  │        │ (4 classes)  │ │ (4 classes)  │ │ (2 classes)  │
└──────────────┘        └──────────────┘ └──────────────┘ └──────────────┘
```

## Component Breakdown

### 1. Core Orchestrator

#### `Normalizer`
- **Responsibility**: Orchestrates the normalization pipeline
- **Pattern**: Facade Pattern
- **SOLID**: Acts as a high-level interface, delegating to specialized components

### 2. Infrastructure Components

#### `NormalizerRegistry`
- **Responsibility**: Dependency injection container
- **Pattern**: Registry/Service Locator
- **SOLID**: Enables Open/Closed Principle by allowing new strategies to be registered

#### `SymbolIndex`
- **Responsibility**: Fast symbol lookup and indexing
- **Pattern**: Repository Pattern
- **SOLID**: Single responsibility for symbol storage and retrieval

### 3. Processing Pipeline

#### Processors (Strategy Pattern)
Each processor handles a specific symbol type:

```ruby
module Processors
  class BaseProcessor
    # Template method pattern for common processing workflow
    def process(data, result, context)
      validate(data)
      normalized = normalize(data, context)
      store(normalized, result)
      index(normalized, context)
    end
  end
  
  class ClassProcessor < BaseProcessor
    # Only knows how to process classes
  end
  
  class ModuleProcessor < BaseProcessor
    # Only knows how to process modules
  end
  
  class MethodProcessor < BaseProcessor
    # Only knows how to process methods
  end
end
```

**SOLID Compliance**:
- **SRP**: Each processor has one reason to change
- **OCP**: Add new processors without modifying existing ones
- **LSP**: All processors are interchangeable through base interface
- **ISP**: Processors only implement what they need
- **DIP**: Depend on BaseProcessor abstraction

### 4. Resolution Pipeline

#### Resolvers (Single Responsibility)
Each resolver builds specific relationships:

```ruby
module Resolvers
  class NamespaceResolver
    # Builds namespace hierarchies only
    def resolve(result, context); end
  end
  
  class InheritanceResolver
    # Resolves inheritance chains only
    def resolve(result, context); end
  end
  
  class CrossReferenceResolver
    # Links methods to classes only
    def resolve(result, context); end
  end
  
  class MixinMethodResolver
    # Resolves mixin methods only
    def resolve(result, context); end
  end
end
```

### 5. Normalization Strategies

#### Normalizers (Strategy Pattern)
Each normalizer handles a specific data normalization:

```ruby
module Normalizers
  class NameNormalizer
    def normalize(name)
      # Handles FQName, canonical names, snake_case conversion
    end
  end
  
  class VisibilityNormalizer
    def normalize(visibility)
      # Handles visibility normalization and inference
    end
  end
  
  class LocationNormalizer
    def normalize(location)
      # Handles path normalization, line numbers
    end
  end
  
  class ParameterNormalizer
    def normalize(params)
      # Handles parameter type mapping, defaults
    end
  end
end
```

### 6. Deduplication System

#### Deduplication Components
```ruby
module Deduplication
  class Deduplicator
    def deduplicate(symbols)
      # Groups symbols by ID and delegates to merge strategy
    end
  end
  
  class MergeStrategy
    def merge(duplicates)
      # Applies precedence rules for conflict resolution
    end
  end
end
```

## Benefits of the Design

### 1. Maintainability
- Clear separation of concerns
- Easy to locate and fix bugs

### 2. Testability
- Each component can be tested in isolation
- Easy to mock/stub dependencies
- Clear test boundaries

### 3. Extensibility
- Add new symbol types by creating new processors
- Add new normalization rules without touching existing code
- Plugin architecture for custom strategies

### 4. Performance
- Lazy loading of components
- Potential for parallel processing
- Efficient symbol indexing

### 5. Code Quality
- Follows Ruby best practices
- Clear naming conventions
- Consistent patterns throughout

## Usage Example

```ruby
# Basic usage remains unchanged (backward compatible)
normalizer = Rubymap::Normalizer.new
result = normalizer.normalize(raw_data)

# Advanced usage with custom components
registry = NormalizerRegistry.new
registry.register_processor(:custom, CustomProcessor.new)
registry.register_normalizer(:special, SpecialNormalizer.new)

normalizer = Rubymap::Normalizer.new(registry)
result = normalizer.normalize(raw_data)
```

## Testing Strategy

### Unit Tests
Each component can be tested independently:

```ruby
RSpec.describe Processors::ClassProcessor do
  let(:processor) { described_class.new }
  
  it "processes class data correctly" do
    result = processor.process(class_data, [], context)
    expect(result).to have_attributes(...)
  end
end

RSpec.describe Normalizers::VisibilityNormalizer do
  let(:normalizer) { described_class.new }
  
  it "normalizes visibility values" do
    expect(normalizer.normalize(:private)).to eq("private")
    expect(normalizer.normalize(nil)).to eq("public")
  end
end
```

### Integration Tests
The main Normalizer tests continue to pass unchanged, verifying the refactoring maintains all functionality.

## Migration Guide

No migration needed! The public API remains unchanged:

```ruby
# This still works exactly as before
normalizer = Rubymap::Normalizer.new
result = normalizer.normalize(data)
```

## Future Enhancements

The modular architecture enables:

1. **Parallel Processing**: Process different symbol types concurrently
2. **Plugin System**: Load custom processors from gems
3. **Caching Layer**: Cache normalized symbols by ID
4. **Streaming Mode**: Process symbols as they arrive
5. **Configuration DSL**: Configure normalizer behavior declaratively
