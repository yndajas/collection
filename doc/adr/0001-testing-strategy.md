# 1. Testing strategy

## Status

Accepted

## Context

We need a clear and consistent approach to testing that balances high-level
user journey verification with fast, reliable technical checks.

## Decision

We will use a multi-layered testing strategy focused on speed, reliability, and
clear responsibility for each test type.

- Cucumber features: will cover the full user journey from the browser's
  perspective. These tests stay "outside the black box," verifying success
  through UI elements (e.g., sign in/out links, primary calls to action)
  rather than database state.
- RSpec request specs: will verify the technical correctness of the controller
  and routing logic. These tests are faster and will include assertions on
  side effects, such as `expect { ... }.to change { User.count }.by(1)`, to
  ensure that critical database operations are performed correctly.
- RSpec model specs: will be used for any custom business logic, complex
  validations, or non-trivial data transformations. These unit tests provide
  fast, isolated verification of model-level behavior.
- RSpec view specs: will be excluded. User-facing content verification is
  handled by Cucumber, and granular component testing would be better served
  by ViewComponent unit tests if needed in the future.

## Consequences

- Redundancy: we avoid the overlap between RSpec system specs and Cucumber
  features.
- Clarity: developers have a clear guide on where to place different types of
  assertions.
- Performance: most technical edge cases are tested in fast request or model
  specs, while Cucumber remains focused on high-value user journeys.
