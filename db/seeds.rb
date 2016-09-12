types = Type.create([
  { name: 'Buffalo Safety Summit', multiple_locations: false },
  { name: 'Houston Safety Summit', multiple_locations: false },
  { name: 'Albany Safety Summit', multiple_locations: false },
  { name: 'Expo', multiple_locations: true },
  { name: 'Fire Expo', multiple_locations: true },
  { name: 'Power Series', multiple_locations: true }
])

locations = Location.create([
  { city: 'Buffalo' }, { city: 'Rochester' }, { city: 'Syracuse' },
  { city: 'Albany' }, { city: 'Houston' }
])

puts '-' * 50
puts "Event Types created: #{Type.count}/#{types.count}"
puts "Cities created: #{Location.count}/#{locations.count}"
puts '-' * 50