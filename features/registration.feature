Feature: User registration

  Scenario: User signs up and completes 2FA setup
    Given I am on the home page
    When I follow "Sign up"
    And I fill in "Email" with "new_user@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I press "Sign up"
    Then I should see "Set up two-factor authentication"
    And I should see a QR code
    When I fill in "OTP" with a valid code for "new_user@example.com"
    And I press "Enable 2FA"
    Then I should see "Two-factor authentication enabled"
    And I should see "Hello, world"
    And I should see "Sign out"

  Scenario: User signs up and provides an invalid 2FA code
    Given I am on the home page
    When I follow "Sign up"
    And I fill in "Email" with "new_user@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I press "Sign up"
    Then I should see "Set up two-factor authentication"
    When I fill in "OTP" with "000000"
    And I press "Enable 2FA"
    Then I should see "Invalid OTP code"
