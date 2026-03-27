Feature: User authentication

  Scenario: User signs in without 2FA setup and completes it
    Given a user exists with email "user@example.com" and password "password123"
    And the user has not set up 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Set up two-factor authentication"
    And I should see a QR code
    When I fill in "OTP" with a valid code for "user@example.com"
    And I press "Enable 2FA"
    Then I should see "Two-factor authentication enabled"
    And I should see "Hello, world"
    And I should see "Sign out"

  Scenario: User signs in with 2FA already set up
    Given a user exists with email "user@example.com" and password "password123"
    And the user has set up 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Verify two-factor authentication"
    When I fill in "OTP" with a valid code for "user@example.com"
    And I press "Verify"
    Then I should see "Signed in successfully"
    And I should see "Sign out"

  Scenario: User signs in with 2FA already set up and provides an invalid code
    Given a user exists with email "user@example.com" and password "password123"
    And the user has set up 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Verify two-factor authentication"
    When I fill in "OTP" with "000000"
    And I press "Verify"
    Then I should see "Invalid OTP code"

  Scenario: User exempt from 2FA signs in
    Given a user exists with email "exempt@example.com" and password "password123"
    And the user is exempt from 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "exempt@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Signed in successfully"
    And I should see "Hello, world"
    And I should see "Sign out"
