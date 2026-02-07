shader_type spatial;

uniform sampler2D albedo_tex : source_color;
// Bloque del atlas: 8 columnas (0-7), 4 filas (0-3). Ej: (0,0)=gris oscuro, (0,1)=gris claro, (7,3)=gradiente gris.
uniform int block_col = 0;
uniform int block_row = 0;
// Cuántas veces repetir esa baldosa en X e Y
uniform float repeat_x = 4.0;
uniform float repeat_y = 4.0;

void fragment() {
	// Repetir el cuadrado 0-1 y quedarnos con la parte fraccional (una baldosa)
	vec2 tile_uv = fract(UV * vec2(repeat_x, repeat_y));
	// Mapear esa baldosa a la región del atlas (8 cols x 4 rows)
	float bw = 1.0 / 8.0;
	float bh = 1.0 / 4.0;
	vec2 atlas_uv = vec2(float(block_col) * bw, float(block_row) * bh) + tile_uv * vec2(bw, bh);
	ALBEDO = texture(albedo_tex, atlas_uv).rgb;
	ROUGHNESS = 0.9;
}
