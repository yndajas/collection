Feature: User authentication

  Scenario: User signs in without 2FA setup
    Given a user exists with email "user@example.com" and password "password123"
    And the user has not set up 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Set up two-factor authentication"
    And I should see a QR code

  Scenario: User signs in with 2FA already set up
    Given a user exists with email "user@example.com" and password "password123"
    And the user has set up 2FA
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Verify two-factor authentication"
    When I fill in "OTP" with a valid code
    And I press "Verify"
    Then I should see "Signed in successfully"
    And I should see "Sign out"
