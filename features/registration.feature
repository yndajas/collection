Feature: User registration

  Scenario: User signs up and is required to set up 2FA
    Given I am on the home page
    When I follow "Sign up"
    And I fill in "Email" with "new_user@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I press "Sign up"
    Then I should see "Set up two-factor authentication"
    And I should see a QR code
