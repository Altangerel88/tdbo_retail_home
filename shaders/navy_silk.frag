#version 460 core
#include <flutter/runtime_effect.glsl>

// navy_silk.frag
// Iterative domain warp plus sine interference — the folded-fabric look. The
// most decorative of the four; best reserved for a splash or success screen.
//
// The colors come from Dart (lib/widgets/header_shader.dart), so the silk
// follows the brand tokens: charcoal #242424 with a #FCC006 sheen. The
// original navy stops were #001429, #003366, #0B3D91 and #1E40AF.
//
// Uniform indices for FragmentShader.setFloat:
//   0      -> uSize.x
//   1      -> uSize.y
//   2      -> uTime
//   3      -> uIntensity
//   4..6   -> uAbyss (darkest folds)
//   7..9   -> uBase  (dominant ground)
//   10..12 -> uMid   (sheen)
//   13..15 -> uLift  (brightest highlight)

uniform vec2  uSize;
uniform float uTime;
uniform float uIntensity;
uniform vec3  uAbyss;
uniform vec3  uBase;
uniform vec3  uMid;
uniform vec3  uLift;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float aspect = uSize.x / max(uSize.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y) * 2.4;

  float t = uTime * 0.07 * uIntensity;

  // Fold the domain into itself a few times, then read an interference value
  // out of the folded coordinates.
  vec2 q = p;
  float acc = 0.0;
  for (int i = 0; i < 6; i++) {
    float fi = float(i) + 1.0;
    q += vec2(sin(q.y * 2.6 + t * 1.1 + fi),
              cos(q.x * 2.3 - t * 0.8 + fi)) * 0.26;
    acc += sin(dot(q, vec2(3.4, 2.9)) + t * 0.9) / fi;
  }
  float v = clamp(acc * 0.45 + 0.5, 0.0, 1.0);

  // Three-stop ramp so the fabric never brightens past uLift.
  vec3 col = mix(uAbyss, uBase, smoothstep(0.00, 0.55, v));
  col = mix(col, uMid,  smoothstep(0.45, 0.80, v));
  col = mix(col, uLift, smoothstep(0.78, 1.00, v) * 0.75);

  // Pull the whole thing down toward the base so highlights stay a
  // highlight rather than a wash.
  col = mix(uBase, col, 0.88);

  col = mix(col, uAbyss, smoothstep(0.32, 0.0, uv.y) * 0.5);

  vec2 d = uv - 0.5;
  col *= 1.0 - 0.16 * dot(d, d) * 4.0;

  col += (hash21(FlutterFragCoord().xy) - 0.5) * 0.0039;

  fragColor = vec4(col, 1.0);
}
