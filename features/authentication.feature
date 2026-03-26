Feature: User authentication

  Scenario: User signs in
    Given a user exists with email "user@example.com" and password "password123"
    And I am on the home page
    When I follow "Sign in"
    And I fill in "Email" with "user@example.com"
    And I fill in "Password" with "password123"
    And I press "Log in"
    Then I should see "Signed in successfully"
    And I should see "Sign out"
