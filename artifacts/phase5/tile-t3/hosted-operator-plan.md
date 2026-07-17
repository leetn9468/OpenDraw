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
5. Treat hosted ratios and BENCH-5b as informational under standing policy.
   Keep BENCH-1/2/2b/3/5a/6 absolute gates blocking.
6. If BENCH-2b corridor p95 exceeds 16.7 ms or BENCH-6 p95 exceeds 8.0 ms,
   report the result verbatim and stop for owner decision. Do not adjust a
   target, fixture, schedule, baseline policy, or implementation preemptively.
7. Add an evidence-only hosted closure commit linking the exact dispatch.
   Until then T3 S6 and the feature remain open.
