types = EventType.create([{ name: 'Power Series' }, { name: 'Safety Summit' },
													{ name: 'Expo' }, { name: 'Fire Expo' }])

cities = Location.create([{ city: 'Buffalo' }, { city: 'Rochester' },
								 { city: 'Syracuse' }, { city: 'Albany' },
								 { city: 'Houston' }])

puts '-' * 50
puts "Event Types created: #{EventType.count}/#{types.count}"
puts "Cities created: #{Location.count}/#{cities.count}"
puts '-' * 50