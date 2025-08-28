# Enricher: The Meaning Maker

The Enricher transforms normalized facts into actionable insights. While the Extractor collects raw data and the Normalizer creates a clean canonical model, the Enricher computes derived knowledge: relationships, metrics, patterns, and domain-specific intelligence that make the code map truly useful for humans and AI.

## Why an Enricher?

### 1. From facts to insight
Raw symbols and edges aren't enough. You want to know "who calls whom," "what's the public API," "which files are hotspots," "what patterns exist," and "what does this class actually do?"

### 2. Keep policy separate
Complexity formulas, public API rules, design pattern detection, and Rails conventions evolve. Centralizing them in one place keeps emitters and indexes simple and maintainable.

### 3. LLM-readiness
Produce concise, stable summaries and meaningful boundaries so retrieval works deterministically. No re-deriving metrics at query time means consistent, fast responses.

### 4. Actionable intelligence
Surface problems before they become critical: hotspots, coupling issues, missing tests, architectural violations. Enable data-driven refactoring decisions.

### 5. Domain-specific understanding
Rails apps aren't just Ruby code. Detect models, controllers, jobs, and their relationships. Understand REST patterns, ActiveRecord associations, and framework conventions.

## Current Implementation

### Core Features

#### 1. Metric Calculation
- **Complexity Metrics**: Cyclomatic complexity, ABC size, method length
- **Dependency Analysis**: Fan-in/fan-out, coupling strength, instability
- **Inheritance Metrics**: Depth, hierarchy analysis, deep inheritance detection
- **API Surface**: Public method exposure, interface size scoring
- **Test Coverage**: Coverage categorization, testing gap identification
- **Git Churn**: Change frequency, recency weighting, hotspot scoring
- **Stability Scores**: Composite metrics combining age, coverage, churn

```ruby
method.cyclomatic_complexity = 8  # Complex logic detected
method.complexity_category = "moderate"
class.fan_out = 12  # High coupling
class.stability_score = 0.72  # Fairly stable
```

#### 2. Pattern & Idiom Detection
- **Design Patterns**: Factory, Singleton, Observer, Strategy, Adapter, Decorator
- **Ruby Idioms**: Protocol implementations (to_s, to_h, each, <=>)
- **Rails Patterns**: RESTful controllers, ActiveRecord models, service objects
- **Code Smells**: God classes, data classes, feature envy, long methods

```ruby
PatternMatch.new(
  pattern: "Singleton",
  class: "DatabaseConnection",
  confidence: 0.85,
  evidence: ["instance", "private_new", "@@instance"]
)
```

#### 3. Quality Analysis
- **Method Quality**: Length, parameter count, nesting depth, ABC score
- **Class Quality**: Cohesion, abstraction level, responsibility analysis
- **Code Issues**: Commented code, unclear naming, mixed abstractions
- **Hotspot Detection**: Risk scoring, immediate action recommendations

```ruby
QualityIssue.new(
  type: "long_method",
  name: "OrderProcessor#process",
  issues: [
    {type: "high_complexity", severity: "high"},
    {type: "too_many_parameters", severity: "medium"}
  ],
  quality_score: 0.45
)
```

#### 4. Rails-Specific Enrichment
- **Model Analysis**:
  - Associations, validations, callbacks, scopes
  - N+1 risks, missing indexes, callback complexity
  - Model type detection (join tables, STI, polymorphic)
  
- **Controller Analysis**:
  - REST compliance, action complexity
  - Filter chains, strong parameters
  - Authentication/authorization patterns

```ruby
RailsModelInfo.new(
  name: "User",
  associations: [
    {type: "has_many", name: "posts", class: "Post"},
    {type: "belongs_to", name: "organization"}
  ],
  validations: [...],
  complexity_score: 45,
  issues: ["n_plus_one_risk", "callback_hell"]
)
```

#### 5. Relationship Inference
- **Call Graph**: Best-effort static analysis with confidence scoring
- **Usage Graph**: Who references this class/module/method
- **Dependency Graph**: Inter-class relationships and coupling
- **Rails Topology**: Controller ↔ Model ↔ Job relationships

## Architecture

```
Enricher
├── EnricherRegistry         # Component registration & discovery
├── Metrics/                 # Quantitative analysis
│   ├── ComplexityMetric    # Cyclomatic complexity, ABC size
│   ├── DependencyMetric    # Fan-in/out, coupling
│   ├── InheritanceMetric   # Depth, hierarchy analysis
│   ├── ApiSurfaceMetric    # Public interface size
│   ├── CoverageMetric      # Test coverage analysis
│   ├── ChurnMetric         # Git history analysis
│   └── StabilityMetric     # Composite stability scores
├── Analyzers/               # Pattern & quality detection
│   ├── PatternDetector     # Design patterns
│   ├── IdiomDetector       # Ruby protocols & conventions
│   ├── HotspotAnalyzer     # Risk identification
│   └── QualityAnalyzer     # Code quality issues
├── Rails/                   # Framework-specific
│   ├── ModelEnricher       # ActiveRecord analysis
│   └── ControllerEnricher  # ActionController analysis
└── EnrichmentResult         # Enhanced data structures
```

### Data Flow

```
Normalized Data ──► ENRICHER ──► Enriched Output
                    │             ├── metrics calculated
                    │             ├── patterns detected
                    │             ├── relationships inferred
                    │             ├── issues identified
                    │             └── Rails-aware
                    └──► EnrichmentResult
```

## Data Structures

```ruby
EnrichmentResult
├── classes: [EnrichedClass]      # Enhanced with metrics
├── modules: [EnrichedModule]
├── methods: [EnrichedMethod]
├── method_calls: [MethodCall]
├── metrics: {}                    # Global metrics
├── design_patterns: [PatternMatch]
├── quality_issues: [QualityIssue]
├── hotspots: [Hotspot]
├── problem_areas: [Problem]
├── ruby_idioms: [RubyIdiom]
├── rails_models: [RailsModelInfo]
├── rails_controllers: [RailsControllerInfo]
├── stability_analysis: StabilityAnalysis
├── quality_metrics: QualityMetrics
└── enriched_at: "2024-01-15T10:30:00.123Z"

EnrichedClass (extends NormalizedClass)
├── cyclomatic_complexity: Float
├── complexity_category: String
├── fan_in: Integer
├── fan_out: Integer
├── coupling_strength: Float
├── inheritance_depth: Integer
├── public_api_surface: Integer
├── test_coverage: Float
├── coverage_category: String
├── churn_score: Float
├── stability_score: Float
├── quality_score: Float
├── is_rails_model: Boolean
├── rails_model_info: RailsModelInfo
└── methods: [EnrichedMethod]

EnrichedMethod (extends NormalizedMethod)
├── cyclomatic_complexity: Integer
├── complexity_category: String
├── lines_of_code: Integer
├── test_coverage: Float
├── coverage_category: String
├── implements_protocol: String
├── quality_score: Float
└── has_quality_issues: Boolean

Hotspot
├── type: String               # "class" | "method"
├── name: String              # FQName
├── indicators: [Indicator]   # What makes it hot
├── risk_score: Float         # 0.0-1.0
└── recommendations: [String] # Actionable advice

PatternMatch
├── pattern: String           # "Factory", "Singleton", etc.
├── class: String            # Where found
├── confidence: Float        # Detection confidence
└── evidence: [String]       # Why we think this
```

## Example: Normalized → Enriched

### Normalized Input
```json
{
  "symbol_id": "c4f3d2e1a5b6789c",
  "name": "OrderProcessor",
  "fqname": "MyApp::OrderProcessor",
  "kind": "class",
  "superclass": "ApplicationService",
  "instance_methods": ["process", "validate", "send_notifications"],
  "provenance": {"sources": ["static"], "confidence": 0.9}
}
```

### Enriched Output
```json
{
  "symbol_id": "c4f3d2e1a5b6789c",
  "name": "OrderProcessor",
  "fqname": "MyApp::OrderProcessor",
  "kind": "class",
  "superclass": "ApplicationService",
  "instance_methods": ["process", "validate", "send_notifications"],
  "provenance": {"sources": ["static"], "confidence": 0.9},
  
  "cyclomatic_complexity": 12.5,
  "complexity_category": "complex",
  "fan_in": 3,
  "fan_out": 8,
  "coupling_strength": 0.73,
  "public_api_surface": 3,
  "test_coverage": 85.5,
  "coverage_category": "well_covered",
  "churn_score": 2.3,
  "stability_score": 0.78,
  "quality_score": 0.65,
  
  "patterns_detected": [
    {
      "pattern": "Service Object",
      "confidence": 0.9,
      "evidence": ["single public method", "process action", "ApplicationService parent"]
    }
  ],
  
  "quality_issues": [
    {
      "type": "high_complexity",
      "severity": "medium",
      "message": "process method has cyclomatic complexity of 15",
      "suggestion": "Consider breaking down into smaller methods"
    }
  ],
  
  "hotspot_indicators": [
    {"type": "high_churn", "value": 2.3},
    {"type": "high_coupling", "value": 8}
  ],
  "risk_score": 0.62,
  
  "summary": "Service object for order processing. High complexity and coupling suggest refactoring opportunity. Well-tested but frequently changed."
}
```

## Design Principles

### Pure & Deterministic
Same input always produces identical enriched output. No randomness, no time-dependent calculations (except explicit timestamps).

### Configurable Policy
Thresholds and weights live in configuration:
```ruby
{
  complexity_threshold: 10,
  api_size_threshold: 20,
  churn_threshold: 10,
  coverage_threshold: 80,
  hotspot_weights: {
    complexity: 0.3,
    churn: 0.4,
    coupling: 0.3
  }
}
```

### Composable Passes
Small, testable enrichers that run in a pipeline. Each can be enabled/disabled independently.

### Additive Only
Never removes or modifies normalized data, only adds enrichment fields. Original data preserved for traceability.

### Framework Aware
Special handling for Rails, Sinatra, Hanami patterns. Extensible for other frameworks.

## Testing Strategy

### Current Test Coverage
- ✅ **26 test scenarios** covering all enrichers
- ✅ **Metric calculation** verified against known values
- ✅ **Pattern detection** with confidence scoring
- ✅ **Rails enrichment** for models and controllers
- ✅ **Deterministic output** through sorted collections

### Test Types
1. **Golden tests**: Known code → expected metrics
2. **Property tests**: Invariants (e.g., fan_in + fan_out > 0)
3. **Pattern tests**: Known patterns detected correctly
4. **Threshold tests**: Edge cases around configured limits
5. **Integration tests**: Full pipeline with real code

## Performance & Scalability

### Current Performance
- **Linear complexity**: O(n) for most metrics where n = symbols
- **Memory efficient**: Streaming-ready architecture
- **Parallelizable**: Independent enrichers can run concurrently

### Optimizations
- Lazy calculation of expensive metrics
- Caching of intermediate results
- Skip unchanged symbols in incremental mode

## What Breaks Without It

- ❌ No visibility into code quality or complexity
- ❌ Can't identify problematic areas proactively
- ❌ Missing Rails-specific understanding
- ❌ No design pattern recognition
- ❌ Manual calculation of metrics in every tool
- ❌ Inconsistent quality assessments

## Future Enhancements

### Near-term (v1.1)
- [ ] Type flow analysis for better call graph
- [ ] Security vulnerability detection
- [ ] Performance bottleneck identification
- [ ] Custom pattern definitions via DSL

### Long-term (v2.0)
- [ ] Machine learning-based pattern detection
- [ ] Cross-repository pattern mining
- [ ] Architectural fitness functions
- [ ] Real-time enrichment via LSP

## API Usage

```ruby
# Basic usage
enricher = Rubymap::Enricher.new
enriched = enricher.enrich(normalized_data)

# Access enriched data
enriched.classes.each do |klass|
  puts "#{klass.fqname}:"
  puts "  Complexity: #{klass.complexity_category}"
  puts "  Stability: #{klass.stability_score}"
  puts "  Coverage: #{klass.coverage_category}"
end

# Find hotspots
enriched.hotspots.select { |h| h.risk_score > 0.8 }.each do |hotspot|
  puts "HOTSPOT: #{hotspot.name} (risk: #{hotspot.risk_score})"
  hotspot.recommendations.each { |r| puts "  - #{r}" }
end

# Check design patterns
enriched.design_patterns.each do |pattern|
  puts "#{pattern.pattern} found in #{pattern.class} (confidence: #{pattern.confidence})"
end

# Rails-specific insights
enriched.rails_models.each do |model|
  puts "Model #{model.name}:"
  puts "  Associations: #{model.association_count}"
  puts "  Complexity: #{model.complexity_score}"
  model.issues.each { |issue| puts "  ⚠️  #{issue[:message]}" }
end
```

## Summary

The Enricher is your **intelligence layer**. It transforms the normalized symbol graph into an actionable knowledge base by calculating metrics, detecting patterns, identifying problems, and understanding framework-specific constructs. With pluggable analyzers, configurable thresholds, and deterministic output, it provides the insights needed for informed decisions about code quality, architecture, and maintenance priorities.

The combination of quantitative metrics (complexity, coverage, churn) with qualitative analysis (patterns, idioms, smells) creates a comprehensive view of your codebase's health. Rails-aware enrichment ensures framework-specific patterns are recognized and analyzed appropriately. The result is a rich, queryable dataset that powers everything from IDE hints to architectural dashboards to LLM-assisted refactoring.