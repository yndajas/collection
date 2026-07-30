User.find_or_create_by!(email: "user_with_2fa_set_up@example.com") do |user|
  user.password = "password123"
  user.otp_secret = "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"
  user.consumed_timestep = 1
end

User.find_or_create_by!(email: "user_without_2fa_set_up@example.com") do |user|
  user.password = "password123"
end

User.find_or_create_by!(email: "user_exempt_from_2fa@example.com") do |user|
  user.password = "password123"
  user.otp_required_for_login = false
end

# --- Demo data for the collection prototype -------------------------------
# These users are exempt from 2FA so the prototype is quick to sign into.

demo = User.find_or_create_by!(email: "demo@example.com") do |user|
  user.password = "password123"
  user.otp_required_for_login = false
end
demo.update!(
  username: "demo",
  display_name: "Demo Collector",
  public_profile: true,
  hidden_link_keys: []
)

friend = User.find_or_create_by!(email: "friend@example.com") do |user|
  user.password = "password123"
  user.otp_required_for_login = false
end
friend.update!(
  username: "ada",
  display_name: "Ada",
  public_profile: false,
  hidden_link_keys: Collectible::LINK_KEYS - %w[metacritic youtube goodreads]
)

if demo.collectibles.empty?
  comfort = demo.labels.find_or_create_by!(name: "Comfort games") do |l|
    l.colour = "orange"
    l.collectible_types = %w[video_game board_game]
  end
  backlog = demo.labels.find_or_create_by!(name: "Backlog") do |l|
    l.colour = "purple"
    l.collectible_types = %w[video_game book]
  end
  couch = demo.labels.find_or_create_by!(name: "Couch co-op") do |l|
    l.colour = "green"
    l.collectible_types = %w[video_game]
  end

  VideoGame.create!(user: demo, title: "Hades", system: "Switch", completed: true,
                    evergreen: true, cooperative: false, labels: [ comfort ],
                    notes: "Perfect run-based roguelike. Endless replayability.")
  VideoGame.create!(user: demo, title: "Overcooked 2", system: "PS5",
                    local_multiplayer: true, cooperative: true, labels: [ couch ],
                    notes: "Chaos with friends on the sofa.")
  VideoGame.create!(user: demo, title: "Elden Ring", system: "PS5",
                    online_multiplayer: true, cooperative: true, competitive: true,
                    labels: [ backlog ])
  VideoGame.create!(user: demo, title: "Stardew Valley", system: "Steam",
                    completed: false, evergreen: true, labels: [ comfort, couch ])
  VideoGame.create!(user: demo, title: "Rocket League", system: "PS5",
                    online_multiplayer: true, local_multiplayer: true, competitive: true)

  BoardGame.create!(user: demo, title: "Wingspan", min_players: 1, max_players: 5,
                    competitive: true, evergreen: true)
  BoardGame.create!(user: demo, title: "Pandemic", min_players: 2, max_players: 4,
                    cooperative: true)

  Book.create!(user: demo, title: "Dune", author: "Frank Herbert", completed: true)
  Book.create!(user: demo, title: "The Left Hand of Darkness", author: "Ursula K. Le Guin")
end

if friend.collectibles.empty?
  VideoGame.create!(user: friend, title: "Celeste", system: "Switch", completed: true,
                    evergreen: true)
  VideoGame.create!(user: friend, title: "Hollow Knight", system: "PC")
  Book.create!(user: friend, title: "A Wizard of Earthsea", author: "Ursula K. Le Guin",
               completed: true)
end

# Ada shares her private profile with the demo user, plus an open share link.
ProfileAccess.find_or_create_by!(owner: friend, viewer: demo)
friend.share_links.find_or_create_by!(description: "For my book club") do |link|
  link.token = "demo-share-token"
  link.expires_at = nil
end

puts "Seeded #{User.count} users and #{Collectible.count} collectibles."
puts "Sign in with demo@example.com / password123 (no 2FA)."
