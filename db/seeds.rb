User.find_or_create_by!(email: "dev@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end
