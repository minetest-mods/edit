-- who would have thunked, but rotation for attachd objects works differently to direct object rotation
local rotations = {}
local d = 180
local r = d / 2
rotations.facedir = {
	[0] = vector.new(0, 0, 0),
	vector.new( 0,  r,  0),
	vector.new( 0,  d,  0),
	vector.new( 0, -r,  0),

	vector.new( r,  0,  0),
	vector.new( r,  0,  r),
	vector.new( r,  0,  d),
	vector.new( r,  0, -r),

	vector.new(-r,  0,  0),
	vector.new(-r,  0, -r),
	vector.new(-r,  0,  d),
	vector.new(-r,  0,  r),

	vector.new( 0,  0, -r),
	vector.new( 0,  r, -r),
	vector.new( 0,  d, -r),
	vector.new( 0, -r, -r),

	vector.new( 0,  0,  r),
	vector.new( 0,  r,  r),
	vector.new( 0,  d,  r),
	vector.new( 0,  -r,  r),

	vector.new( 0,  0,  d),
	vector.new( 0,  r,  d),
	vector.new( 0,  d,  d),
	vector.new( 0, -r,  d),
}

-- TODO: signlike nodes always display as an extrusion of texture, like in dropped item form
-- 		displaying them correctly will require makeing a custom display obect for them

return rotations
