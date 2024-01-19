shader_type spatial;

uniform float chunk_size;
uniform int num_cells;
uniform sampler2D height_map;
uniform vec2 height_range;

varying vec2 tex_position;

void vertex() {
	// VERTEX.xz: [-chunk_size/2;chunk_size/2]
	// height_map: [0;1], values: [0;1], rgb = normals, alpha = height
	vec2 vertex_num = (VERTEX.xz + chunk_size / 2.0) / (chunk_size / float(num_cells));
	tex_position = 0.5 / (float(num_cells) + 1.0) * (1.0 + vertex_num * 2.0);
	VERTEX.y += texture(height_map, tex_position).a * (height_range.y - height_range.x) + height_range.x;
}

void fragment() {
	NORMAL = texture(height_map, tex_position).xyz;
}
