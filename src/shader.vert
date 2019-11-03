layout(location=0) in vec2 g;

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    gl_Position = vec4( g, 0, 1 );
}