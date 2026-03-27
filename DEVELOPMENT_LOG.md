# Development log: Collection

This document summarizes the technical decisions, implementation steps, and
rationale established during the development of the Collection application.

## 1. Project initialization

- Environment: Ruby 4.0.2, Rails 8.1.3.
- Architecture:
  - Standard Rails MVC.
  - No JavaScript, Action Mailer, Action Mailbox, Active Job, Action Cable,
    or Jbuilder.
  - SQLite3 for the database.
- Testing suite:
  - RSpec: for unit and request-level testing.
  - Cucumber: for feature-level acceptance testing.
  - Capybara: for browser simulation.
- Conventions:
  - Double quotes for strings.
  - Imperative mood for commit messages.
  - Sentence case for headings and UI content.

## 2. Infrastructure and layout

- `Gemfile`: tidied to be alphabetical, comment-free, and organized by group.
- Layout:
  - Implementation of a global `<header>` for authentication links.
  - Use of a `<main>` element for flash messages (`notice`, `alert`) and
    yielded content.
- RuboCop:
  - Configured via `rubocop-rails-omakase`.
  - Custom rules to enforce double quotes and include `spec/`, `features/`,
    and `db/` directories.

## 3. Core authentication

- Framework: Devise.
- Features:
  - User registration flow.
  - Basic login flow.
  - Password confirmation preserved for WCAG compliance in a no-JS environment
    (avoiding "cognitive function tests" versus "redundant entry" trade-offs).

## 4. Two-factor authentication (TOTP)

- Gems: `devise-two-factor`, `rqrcode`, `rotp`.
- Security:
  - `otp_secret_encryption_key` managed via Rails encrypted credentials.
  - `ActiveRecord` Encryption configured for database-level secret protection.
  - Replay attack prevention: mandatory `current_user.save!` in verification
    controllers to persist `consumed_timestep`.
- Mandatory setup flow:
  - Global redirection in `ApplicationController` forcing any signed-in user
    without 2FA setup to the setup page.
  - `TwoFactorAuthentication::SetupController` for QR code generation and
    initial verification.
- Login flow:
  - Overridden `Devise::SessionsController#create` to intercept successful
    password challenges.
  - Temporary session storage of `otp_user_id` while awaiting TOTP verification.
  - `TwoFactorAuthentication::SessionsController` for final OTP verification
    and full sign-in.

## 5. Documentation and tooling

- `README`: documented database preparation (`db:prepare`, `db:seed`,
  `db:reset`) and credential management using `master.key`.
- Linting: continuous use of `bin/rubocop -A` to maintain style consistency.
- Development log: creation of `DEVELOPMENT_LOG.md` to track technical
  decisions.

## 6. Exempt user logic

- Implementation: leveraged the existing `otp_required_for_login` column to
  handle 2FA exemptions.
- Controllers: updated `ApplicationController` and `Users::SessionsController`
  to skip 2FA setup and challenge for users with `otp_required_for_login: false`.
- Seeds: added three users in `db/seeds.rb` to cover all authentication states:
  - `user_with_2fa_set_up@example.com` (realistic 32-char secret provided).
  - `user_without_2fa_set_up@example.com`.
  - `user_exempt_from_2fa@example.com`.

## 7. Tooling and CI refinement

- Markdown linting: added `markdownlint-cli` via Node.js (v24.14.0) with a
  default 80-character line limit. Added `lint:md` and `lint:md:fix` scripts.
- CI/CD: renamed the standard lint job to `lint_ruby` and added a
  `lint_markdown` job to the GitHub Actions workflow.
- AI disclosure: added a formal disclosure to the `README.md` mentioning the
  use of Gemini in the development process.

## 8. Finalizing and documentation

- CI and test documentation: updated `.github/workflows/ci.yml` and
  `config/ci.rb` to include comprehensive test suites (RSpec and Cucumber).
  Added a "Running tests" section to `README.md`.
- Kamal removal: purged all Kamal configuration and dependencies from the
  repository, including `.kamal/`, `bin/kamal`, and `config/deploy.yml`.
- Gemini mandates: created `GEMINI.md` to document persistent
  repository-specific preferences for future sessions.

## 9. Test infrastructure modernisation

- 100% coverage milestone: reached 100% line coverage across both RSpec and
  Cucumber, and 100% branch coverage for RSpec, by adding missing scenarios
  and specs for 2FA error paths and edge cases.
- FactoryBot integration: introduced `factory_bot_rails` to manage test data.
  Refactored the entire test suite to use factories instead of direct
  ActiveRecord creation, providing a scalable foundation for upcoming model
  complexity.
- Supporting tasks: added a `coverage:identify_gaps` Rake task to maintain the
  high coverage standard.
- Todo management: established `todo.md` and a corresponding mandate in
  `GEMINI.md` to ensure remaining tasks are tracked and prioritised.

---

Last updated: Friday, 27 March 2026
