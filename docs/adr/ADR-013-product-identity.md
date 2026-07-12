# ADR-013 — Product identity

- Status: Accepted
- Date: 2026-07-12
- Decision owner: Project owner

## Decision

The product name is **OpenDraw**. The native working extension is `.odraw`, and the
logging subsystem is `org.opendraw.editor`. Product-facing strings, identifiers, and
new documentation must not use legacy-vendor or legacy-product names.

Internal Swift target names may remain unchanged during remediation to avoid mixing
mechanical churn with correctness work.
