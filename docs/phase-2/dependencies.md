# Dependency and license inventory

`swift package show-dependencies` reports no third-party package dependency.

| Component | Purpose | Source/terms | Distribution action |
|---|---|---|---|
| Swift standard library/runtime | Language/runtime | Apple Swift project licensing; Apache 2.0 components with Runtime Library Exception | Recheck shipped runtime notices during packaging |
| Foundation | Data, UUID, Codable | Apple system framework / SDK agreement | Link as system framework |
| AppKit | Native application shell/input/accessibility | Apple system framework / SDK agreement | Link as system framework |
| Core Graphics | Rendering and bitmap contexts | Apple system framework / SDK agreement | Link as system framework |
| Core Text | Shaping and font metrics | Apple system framework / SDK agreement | Link as system framework |
| OSLog | Structured logging | Apple system framework / SDK agreement | Link as system framework |
| Swift Testing | Test runner/assertions | Swift open-source toolchain licensing | Development only |

Before any external package or asset is added, record its exact version/hash, URL,
SPDX expression, copyright notice, obligations, security/update owner, and approval.
This is an engineering inventory, not legal advice.
