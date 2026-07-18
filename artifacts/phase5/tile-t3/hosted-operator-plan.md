# T3 hosted closure operator plan

State: **OPEN — not dispatched**

After local acceptance, the operator must:

1. Resolve the final local evidence revision with `git rev-parse HEAD`, verify
   the worktree is clean, and push that exact revision without amendment.
2. Manually dispatch `.github/workflows/ci.yml` for the branch containing that
   exact revision; record the run ID, URL, requested SHA, and resolved SHA.
3. Require all eight jobs to finish green: `debug-release`, `sanitizer`,
   `adversarial-golden`, `benchmark`, `startup-memory`, `coverage`,
   `release-integrity`, and `nightly-reliability`.
4. Retain job logs and uploaded artifacts under
   `artifacts/phase5/tile-t3/hosted/`, including the complete hosted BENCH
   table and exact memory/startup/reliability summaries.
5. Treat hosted ratios, BENCH-5b timing, and BENCH-6 timing as informational
   under standing policy. Keep BENCH-1/2/2b/3/5a timing and all BENCH-6
   correctness preconditions blocking.
6. Require the BENCH-6 artifact row
   `bench6_timing_enforcement=off result=INFORMATIONAL
   reason=owner-decision-2026-07-18`, retain p50/p95/max verbatim, and require
   its nonzero-hit and exact-damage-mapping assertions to pass. Any correctness
   trap or BENCH-2b corridor failure stops closure; hosted BENCH-6 timing alone
   does not fail the job. Do not adjust a target, fixture, schedule, baseline
   policy, or implementation.
7. Add an evidence-only hosted closure commit linking the exact dispatch.
   Until then T3 S6 and the feature remain open.
