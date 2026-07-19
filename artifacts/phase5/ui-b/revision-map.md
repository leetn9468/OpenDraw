# U3-B revision map

| Revision | Purpose |
|---|---|
| `0a9619515d97226d6c0e531b3a319df8c583bafb` | Freeze VERIFY-034 before production implementation |
| `f3181ef54f865fa23eb58e72f0a552b1d253dea8` | Execute VERIFY-034 and enable all six align controls |
| `b95e4d61d53269505398270e7a762ede8f00300f` | Deliver chrome, gesture modifiers, anchor break, in-place text, tests, and UI journey |
| `a9f219c6b3f94befa55d7c5eba9409f4b80bd934` | Mechanical format pass; exact implementation validated by all evidence below |

| Evidence | Producing revision | Validates revision |
|---|---|---|
| `chrome-dark-mid-gesture.png` | `a9f219c6` | `a9f219c6` |
| `debug-tests.txt`, `release-tests.txt`, `asan-tests.txt` | working evidence set | `a9f219c6` |
| `coverage-tests.txt`, `coverage-summary.txt` | working evidence set | `a9f219c6` |
| `golden-tests.txt` | working evidence set | `a9f219c6` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-headless-proof.txt` | working evidence set | `a9f219c6` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | working evidence set | `a9f219c6` |
| `startup-p95.txt`, `reliability-100x100.txt` | working evidence set | `a9f219c6` |
| `theme-tokens.txt`, `format.txt` | working evidence set | `a9f219c6` |
| `dependency-check.txt`, `clean-room.txt`, `symbol-graph.txt`, `release-integrity.txt` | working evidence set | `a9f219c6` |
| `menu-audit.md`, `design-deviations.md`, `test-counts.txt`, `gate-summary.md` | evidence commit pending | `a9f219c6` |

The automated evidence commit is intentionally filled after committing this
map, so the record can name its own exact revision without rewriting test logs.
