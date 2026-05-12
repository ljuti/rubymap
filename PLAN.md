 Needs formal shaping:                                                                                                                                 
                                                                                                                                                       
 ┌───────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 
 │ Phase             │ Why                                                                                                                           │ 
 ├───────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 1:          │ MethodBodyVisitor's AST traversal strategy has open design questions — which Prism node types to handle, schema for           │ 
 │ Extractor         │ calls_made, how to distinguish class-level vs method-level calls, what counts as a "branch" vs "conditional." Getting the     │ 
 │                   │ taxonomy wrong here cascades into every downstream system.                                                                    │ 
 ├───────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 5: Rails    │ The JobEnricher, MailerEnricher, and RouteParser don't exist yet — they need design. The route parser especially has a scope  │ 
 │                   │ question: static-only, or design for runtime merge? What's the output schema for routes? Also, the existing ModelEnricher and │ 
 │                   │ ControllerEnricher were designed against an assumed data format that has never been tested with real data — shaping should    │ 
 │                   │ verify those assumptions hold or adjust the design.                                                                           │ 
 ├───────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 6: Runtime  │ Most open questions of any phase. Fork-vs-thread isolation strategy, TracePoint vs Module#prepend for dynamic detection,      │ 
 │                   │ sandboxing mechanism (read-only transaction? database user? snapshot?), precedence rules for merging runtime vs static data,  │ 
 │                   │ timeout and error recovery strategy, security boundary design. This is a greenfield subsystem that needs proper shaping       │ 
 │                   │ before anyone writes code.                                                                                                    │ 
 ├───────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 7           │ The change-detection strategy has design implications: checksum-based vs mtime-based vs git-diff-based? How to handle renames │ 
 │ (incremental      │ (detect via similarity or treat as delete+add)? What's the state file format? How does incremental merge with caching? The    │ 
 │ mapping)          │ rest of Phase 7 (CLI view, cache, polish) is sufficiently specified.                                                          │ 
 └───────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ 
                                                                                                                                                       
 Sufficiently specified — can implement directly:                                                                                                      
                                                                                                                                                       
 ┌─────────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 
 │ Phase                   │ Why                                                                                                                     │ 
 ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 2: Data flow fix  │ Mechanical. The specific files, the specific fields, and the specific conversions are all identified. Each task is      │ 
 │                         │ "extend X to include Y" with a clear source and destination. No architectural decisions remain.                         │ 
 ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 3 (JSON/YAML      │ Both are trivial wrappers around JSON.pretty_generate and YAML.dump of the enriched data hash. The schema is whatever   │ 
 │ emitters)               │ the pipeline produces. No design decisions needed.                                                                      │ 
 ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 3 (GraphViz +     │ These have open questions and should be shaped alongside Phase 3's mechanical parts — or extracted into a mini-shaping. │ 
 │ templates)              │ GraphViz: node layout strategy, what metrics to surface in labels, subgraph grouping rules. Templates: the data mapping │ 
 │                         │ between the current inline code path and the Presenters needs reconciliation.                                           │ 
 ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 4: Tests          │ Clear scope. The only small shaping question is what the reference project fixture should contain to be representative  │ 
 │                         │ without being bloated — but that's a 15-minute decision, not a shaping cycle.                                           │ 
 ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
 │ Phase 7 (CLI view,      │ Each is a well-understood feature. CLI view reads manifest + chunk files. Cache is a standard key→Marshal pattern.      │ 
 │ cache, polish, Web UI   │ Polish is a list of specific improvements. The Web UI and GitHub specs are shaping artifacts, not implementation.       │ 
 │ spec)                   │                                                                                                                         │ 
 └─────────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ 