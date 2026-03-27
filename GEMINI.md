# Gemini CLI mandates for this repository

## Tooling and environment

- Node.js: use Node 24.14.0 for all tooling and CI tasks. Ensure
  `.node-version` is maintained.
- Minimalist configuration: keep `package.json` lean (only `name`, `version`,
  `scripts`, and `devDependencies`). Remove default boilerplate.
- Dependency hygiene: proactively remove unused or unwanted ecosystem
  defaults (e.g., Kamal).

## Git and commit standards

- Commit messages: use concise subjects (50 characters or less). Enforce a
  strict 72-character line limit for commit bodies.
- History management: prefer amending the previous commit for minor
  follow-up refinements rather than creating new "fix-up" commits.
- File cleanliness: ensure no consecutive empty lines in configuration
  files (`.gitignore`, `.dockerignore`, etc.).

## CI and testing strategy

- Concurrency: prioritize parallelized jobs in GitHub Actions workflows for
  maximum speed.
- Development lifecycle: follow a strict TDD approach (failing test first).
- Cucumber features: move any step definitions used in multiple feature
  files to `shared_steps.rb`. Ensure feature specs cover entire user journeys.
- Local verification: maintain `bin/ci` (via `config/ci.rb`) as the
  comprehensive local "source of truth" mirroring the full CI suite.

## Documentation

- AI attribution: specifically mention "Gemini" in the AI disclosure
  section of `README.md`.
- Developer experience: maintain `README.md` as a high-signal, practical
  guide for setup and testing.

## Writing style

- Case: use sentence case for all headings throughout the project and for the terms preceding a colon in a list item.
- Language: use British English for all project communication, including commit messages and documentation.
- Line length: keep lines within 80 characters in general.
- Colon: do not use a capital letter after a colon.

- Conjunctions: never use ampersands when "and" makes sense.
- List items: do not bold the terms preceding a colon in a list item.
- Spacing: include an empty line after every heading.
