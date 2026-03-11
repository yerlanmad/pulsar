# Admin user
admin = User.find_or_create_by!(email_address: 'admin@pulsar.local') do |u|
  u.name = 'Admin'
  u.password = 'password'
  u.password_confirmation = 'password'
  u.role = :admin
end

puts "Admin user: admin@pulsar.local / password"

# Demo supervisor
supervisor = User.find_or_create_by!(email_address: 'supervisor@pulsar.local') do |u|
  u.name = 'Supervisor'
  u.password = 'password'
  u.password_confirmation = 'password'
  u.role = :supervisor
end

# Demo agents
3.times do |i|
  user = User.find_or_create_by!(email_address: "agent#{i + 1}@pulsar.local") do |u|
    u.name = "Agent #{i + 1}"
    u.password = 'password'
    u.password_confirmation = 'password'
    u.role = :agent
  end

  Agent.find_or_create_by!(user: user) do |a|
    a.name = user.name
    a.sip_account = "SIP/#{1000 + i + 1}"
    a.status = :offline
  end
end

# Demo queues
support = QueueConfig.find_or_create_by!(name: 'Support') do |q|
  q.strategy = :ringall
  q.timeout = 30
  q.max_wait_time = 300
  q.timeout_action = :voicemail
end

sales = QueueConfig.find_or_create_by!(name: 'Sales') do |q|
  q.strategy = :leastrecent
  q.timeout = 25
  q.max_wait_time = 180
  q.timeout_action = :redirect
end

# Assign agents to queues
Agent.all.each do |agent|
  QueueMembership.find_or_create_by!(agent: agent, queue_config: support)
end

# Demo route rules
RouteRule.find_or_create_by!(name: 'US Support') do |r|
  r.pattern = '+1800*'
  r.queue_config = support
  r.position = 0
end

RouteRule.find_or_create_by!(name: 'Sales Line') do |r|
  r.pattern = '+1900*'
  r.queue_config = sales
  r.position = 1
end

puts 'Seed data created.'
