Feature: User registration

  Scenario: User signs up
    Given I am on the home page
    When I follow "Sign up"
    And I fill in "Email" with "new_user@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I press "Sign up"
    Then I should see "Welcome! You have signed up successfully"
    And I should see "Sign out"
