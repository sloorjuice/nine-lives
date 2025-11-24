shader_type canvas_item;

// --- VISUAL SETTINGS ---
uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float border_width : hint_range(0.0, 0.5) = 0.05; 
uniform float softness : hint_range(0.0, 0.5) = 0.02;

// --- INTENSITY CONTROLS ---
uniform float max_opacity : hint_range(0.0, 1.0) = 0.8; // CAP: Never gets more opaque than this
uniform float brightness_boost : hint_range(1.0, 5.0) = 1.5; // MULTIPLIER: How fast it lights up

// --- DATA FROM SCRIPT ---
uniform int enemy_count; 
uniform vec2 enemy_angles[10]; 
uniform float enemy_intensities[10]; 

void fragment() {
    // 1. Create the Box Border Mask
    vec2 uv = UV;
    
    // Calculate distance from center on X and Y axes
    float dist_x = abs(uv.x - 0.5) * 2.0;
    float dist_y = abs(uv.y - 0.5) * 2.0;
    
    // Which axis is closer to the edge?
    float box_dist = max(dist_x, dist_y);
    
    // Create a smooth edge for the border
    float border_mask = smoothstep(1.0 - border_width - softness, 1.0 - border_width, box_dist);
    
    if (border_mask <= 0.001) {
        discard;
    }

    // 2. Calculate Lighting from Enemies
    float total_light = 0.0;
    vec2 center = vec2(0.5);
    vec2 pixel_dir = normalize(uv - center);
    
    for (int i = 0; i < enemy_count; i++) {
        vec2 enemy_dir = normalize(enemy_angles[i]);
        
        // Check alignment
        float alignment = dot(pixel_dir, enemy_dir);
        float focus = clamp(alignment, 0.0, 1.0);
        focus = pow(focus, 6.0); // Tightness of the glow arc
        
        total_light += focus * enemy_intensities[i];
    }

    // 3. Final Output with CAPS
    vec4 final_color = glow_color;
    
    // Calculate raw alpha
    float raw_alpha = border_mask * total_light * brightness_boost;
    
    // APPLY THE CAP: Ensure it never exceeds 'max_opacity'
    final_color.a = min(raw_alpha, max_opacity);
    
    COLOR = final_color;
}