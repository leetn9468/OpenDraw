# U3-B revision map

| Revision | Purpose |
|---|---|
| `0a9619515d97226d6c0e531b3a319df8c583bafb` | Freeze VERIFY-034 before production implementation |
| `f3181ef54f865fa23eb58e72f0a552b1d253dea8` | Execute VERIFY-034 and enable all six align controls |
| `b95e4d61d53269505398270e7a762ede8f00300f` | Deliver chrome, gesture modifiers, anchor break, in-place text, tests, and UI journey |
| `a9f219c6b3f94befa55d7c5eba9409f4b80bd934` | Mechanical format pass; exact implementation validated by all evidence below |
| `58bcf8e6f5d6a3828bc9e16c85303a514ada6c37` | Retain the complete automated evidence set, screenshot, audits, and execution record |
| `c8e3784a135b3e51e7f2b5570e1bdf17e10fb26a` | Record TN LEE's visual acceptance and mark U3-B/UI redesign DELIVERED |

| Evidence | Producing revision | Validates revision |
|---|---|---|
| `chrome-dark-mid-gesture.png` | `58bcf8e6` | `a9f219c6` |
| `debug-tests.txt`, `release-tests.txt`, `asan-tests.txt` | `58bcf8e6` | `a9f219c6` |
| `coverage-tests.txt`, `coverage-summary.txt` | `58bcf8e6` | `a9f219c6` |
| `golden-tests.txt` | `58bcf8e6` | `a9f219c6` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-headless-proof.txt` | `58bcf8e6` | `a9f219c6` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | `58bcf8e6` | `a9f219c6` |
| `startup-p95.txt`, `reliability-100x100.txt` | `58bcf8e6` | `a9f219c6` |
| `theme-tokens.txt`, `format.txt` | `58bcf8e6` | `a9f219c6` |
| `dependency-check.txt`, `clean-room.txt`, `symbol-graph.txt`, `release-integrity.txt` | `58bcf8e6` | `a9f219c6` |
| `menu-audit.md`, `design-deviations.md`, `test-counts.txt`, `gate-summary.md` | `58bcf8e6` | `a9f219c6` |
| `owner-visual-acceptance.md` and DELIVERED state | `c8e3784a` | `a9f219c6` |
| `hosted/` CI #32 closure evidence | `67a956cb` | `8d604586` |
