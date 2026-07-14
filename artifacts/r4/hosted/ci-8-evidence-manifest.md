# CI #8 retained evidence manifest

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29347892897>

Run revision: `94fb0f057510639b93d9802fe93ab4aa5f0b18de`

Event/result: `workflow_dispatch` / `success`

All extracted text evidence has the run URL in its own header. Each retained
job log has a two-line `run_url` / `job_id` provenance header prepended to the
otherwise unchanged authenticated GitHub job log.

| Artifact | ID | Retained archive SHA-256 |
|---|---:|---|
| `benchmark-results` | 8316880203 | `dbec9f05681649ff78499914cc5da0f15cca31ed3daf462305e66b27bf6c1aa1` |
| `benchmark-comparison` | 8316880628 | `bd447393b4490f252e238cf4fb002b503880f9e4140f08217a9f07f98ddbd60f` |
| `hosted-benchmark-baseline-candidate` | 8316881233 | `5f59f693cf64982fe1d2218a5789878cdb8f9c44c6f1661cbf32085ea4e4b538` |
| `startup-memory-results` | 8316895945 | `d546dbc748d4933ff2c89369c6d2c479908084642b8811e43cb9d1554a984d1b` |
| `reliability-100x100` | 8316864146 | `2c3e1fa473861bf6aaa1cc94b76e0b871c9806957692ec753ed67ae7d3e9cb1f` |
| `OpenDraw-app` (digest only, archive not committed) | 8316865395 | `1140dc4f1d91190ff2b34c278551a34699e4dd935188cbe5e1f706a5d74905f3` |

The hosted baseline committed at
`benchmarks/hosted-macos15-arm64-baseline.tsv` is byte-identical to extracted
evidence `ci-8-hosted-benchmark-baseline-candidate.tsv`; both have SHA-256
`c4aa95633aff400507ee6639b1a824b51c8e4e10dc5b95fac42073e833bbac35`.

Eight authenticated job logs are retained as
`ci-8-job-<job-id>-<job-name>.log`, alongside the run, jobs and artifact API
responses and the five downloaded non-app archives.
