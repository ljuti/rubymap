# V4 Plan: Integration & Regression

**Slice:** V4 of [slices.md](slices.md)
**Requirements:** R3
**Depends on:** V1, V2, V3 (all must be complete)
**Demo:** `bundle exec rspec` — full test suite green, 0 failures, no regressions. End-to-end test with realistic Ruby files produces expected output.

---

## Scope

V4 is the integration and quality gate. No new features — this slice verifies that V1-V3 work together correctly, that no existing behavior is broken, and that the full pipeline (extract → normalize → enrich → emit) functions end-to-end with the new extractor data.

Specific work:
1. Run and fix the full existing test suite (1739 tests)
2. Write integration tests that exercise the full pipeline with realistic fixtures
3. Create a gold file test for a reference Ruby project
4. Fix any regressions discovered

---

## Affordances

No new affordances built. This slice exercises all V1-V3 affordances together with the existing system.

---

## Regression Gate

These test files MUST pass (no new failures, no behavior changes):

```bash
bundle exec rspec \
  spec/extractor_spec.rb \
  spec/extractor/models/*_spec.rb \
  spec/extractor/extraction_context_spec.rb \
  spec/extractor/node_visitor_spec.rb \
  spec/extractor/services/*_spec.rb \
  spec/extractor/extractors/base_extractor_spec.rb \
  spec/extractor/mutation_killing_spec.rb \
  spec/rubymap_spec.rb \
  spec/normalizer_spec.rb \
  spec/normalizer/**/*_spec.rb \
  spec/enricher_spec.rb \
  spec/enricher/**/*_spec.rb \
  spec/indexer_spec.rb \
  spec/indexer/**/*_spec.rb \
  spec/emitters_spec.rb \
  spec/emitters/**/*_spec.rb \
  spec/cli_spec.rb \
  spec/templates_spec.rb
```

And the new V1-V3 test files:

```bash
bundle exec rspec \
  spec/extractor/method_body_visitor_spec.rb \
  spec/extractor/models/method_info_spec.rb \
  spec/extractor/extractors/call_extractor_spec.rb
```

---

## Integration Tests to Write

### 1. End-to-end pipeline test

```ruby
# spec/integration/extractor_to_pipeline_spec.rb
RSpec.describe "Extractor → Pipeline integration" do
  it "produces enriched output with call data from real Ruby files" do
    # Test project with a model, controller, and service
    result = Rubymap.map("spec/fixtures/test_project", format: :llm)
    
    # Verify output exists
    expect(result[:format]).to eq(:llm)
    expect(Dir.exist?(result[:output_dir])).to be true
    
    # Verify manifest
    manifest = JSON.parse(File.read(File.join(result[:output_dir], "manifest.json")))
    expect(manifest["chunks"]).to_not be_empty
  end
end
```

### 2. Reference project gold file test

```ruby
# spec/integration/gold_file_spec.rb
RSpec.describe "Gold file output" do
  let(:fixture_dir) { "spec/fixtures/reference_project" }
  
  before(:all) do
    @output_dir = Dir.mktmpdir("rubymap-gold")
    Rubymap.map(fixture_dir, format: :llm, output: @output_dir)
  end
  
  after(:all) do
    FileUtils.rm_rf(@output_dir)
  end
  
  it "generates expected chunks for known classes" do
    expected_chunks = %w[user.md post.md users_controller.md]
    expected_chunks.each do |chunk|
      chunk_path = File.join(@output_dir, "chunks", chunk)
      expect(File.exist?(chunk_path)).to be true, "Missing chunk: #{chunk}"
    end
  end
  
  it "includes calls_made data in output" do
    user_chunk = File.read(File.join(@output_dir, "chunks", "user.md"))
    # The LLM output should reference methods that were called
    expect(user_chunk).to include("save")
  end
end
```

### 3. MethodInfo completeness test

```ruby
# spec/extractor/method_info_completeness_spec.rb
RSpec.describe "MethodInfo data flow" do
  it "populates all new fields after V1-V3 extraction" do
    code = <<~RUBY
      class User < ApplicationRecord
        has_many :posts
        validates :name, presence: true
        
        def full_name
          if first_name && last_name
            "\#{first_name} \#{last_name}"
          end
        end
        
        def publish_post(post)
          post.publish! if post.draft?
          post.save
        end
      end
    RUBY
    
    result = Rubymap::Extractor.new.extract_from_code(code)
    
    # Check patterns (V3)
    patterns = result.patterns.select { |p| p.type == "rails_dsl" }
    expect(patterns.size).to eq(2)  # has_many + validates
    
    # Check methods (V1 + V2)
    full_name_method = result.methods.find { |m| m.name == "full_name" }
    expect(full_name_method).to_not be_nil
    expect(full_name_method.calls_made).to be_an(Array)
    expect(full_name_method.branches).to be > 0  # if statement
    expect(full_name_method.conditionals).to be > 0
    
    publish_method = result.methods.find { |m| m.name == "publish_post" }
    expect(publish_method.calls_made.size).to be >= 2  # publish! and save
    expect(publish_method.branches).to be > 0  # if modifier
    
    # Check to_h serialization (R4)
    hash = publish_method.to_h
    expect(hash[:calls_made]).to be_an(Array)
    expect(hash[:branches]).to be_an(Integer)
    expect(hash[:loops]).to be_an(Integer)
    expect(hash[:conditionals]).to be_an(Integer)
    expect(hash[:body_lines]).to be_an(Integer)
  end
end
```

---

## Regression Risk Areas

| Area | Risk | Mitigation |
|------|------|------------|
| NodeVisitor dispatch | handle_method changes could break other handlers | Run full node_visitor_spec |
| ExtractionContext | with_class and with_method could leak state between files | Test nested class extraction, file-after-file extraction |
| CallExtractor | New when clauses could shadow or conflict with existing ones | Test all existing patterns (attr_*, include, require, etc.) in same class with Rails DSL |
| MethodInfo#to_h | Adding fields could break downstream consumers expecting old hash shape | Run normalizer_spec, enricher_spec, indexer_spec |
| Memory/performance | MethodBodyVisitor walks entire body tree — deep nesting could blow stack | Test with deeply nested methods (10+ levels of if-inside-each) |

---

## Task List

1. **Run full test suite** — `bundle exec rspec` — capture all failures
2. **Fix any regressions** — triage failures: are they caused by V1-V3 changes, or pre-existing?
3. **Write integration tests** — gold file, MethodInfo completeness, pipeline end-to-end
4. **Test edge cases:**
   - Empty methods (`def foo; end`)
   - Methods with only comments
   - Deeply nested structures (10+ levels)
   - Methods with early return on first line
   - Singleton methods (`def self.foo`)
   - Methods defined inside blocks
5. **Run mutation tests** — `bundle exec mutant run` on extractor — verify no new surviving mutants
6. **Lint** — `bundle exec standardrb` — fix any issues
7. **Update test_self_mapping.rb** — run rubymap on itself, verify output includes call data
8. **Document** — update CHANGELOG.md with V1-V3 changes

## Completion Criteria

- [ ] `bundle exec rspec` — 0 failures (existing 5 environmental failures may remain)
- [ ] All V1-V3 new tests pass
- [ ] Integration tests pass: gold file, completeness, pipeline
- [ ] No regression in existing extractor, normalizer, enricher, indexer, or emitter behavior
- [ ] `bundle exec standardrb` — clean
- [ ] test_self_mapping.rb runs successfully
- [ ] Extract a realistic Rails model — verify calls_made, branches, loops, conditionals, body_lines all populated
- [ ] Extract a realistic Rails controller — verify Rails DSL patterns detected
- [ ] MethodInfo#to_h includes all new fields in correct format
