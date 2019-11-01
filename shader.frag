layout (location=0) uniform float x_time;
layout (location=0) out vec4 x_fragColor;

mat2 rot( float theta )
{
    float c = cos( theta );
    float s = sin( theta );
    return mat2( c, s, -s, c );
}

float KIFS( vec3 p, float t )
{
    float scale = 1.;
    for( int i = 0; i < 12;  ++i )
    {
        vec3 n = normalize(vec3(cos(t), sin(1.1*t), 0));
        p -= n*2.*min(0.,dot(n, p));
        p.x -= .2;
        vec3 n1 = normalize(vec3(1, cos(1.7*t), sin(1.3*t)));
        p -= n1*2.*max(0.,dot(n1, p));
        p = abs(p);    
        p *= 2.;
        scale *= 2.;
        p -= vec3( 2., 2., 2. );
    }    
    return (length(p-vec3(1.,.5,1.1))-.5) / scale;
}

vec3 getOffset( vec3 coord )
{
    float lookup = 91.*coord.x + 11.*coord.y + 31.*coord.z;
    return 1.*vec3(
        sin(149.*lookup+97.),
        sin(177.*lookup+13.),
        sin(457.*lookup+11.)
    );
}

vec4 map( vec3 p, float z )
{
    const float c = 5.;
    vec3 coord = floor((p + c)/(2.*c));
    p += getOffset(coord);
    
    p.xy *= rot( (coord.y + coord.z) * 3.14159 / 2. );
    p.yz *= rot( (coord.z + coord.x) * 3.14159 / 2. );
    p.zx *= rot( (coord.x + coord.y) * 3.14159 / 2. );
    
    vec3 q = mod( p + c, 2.*c ) - c;
    vec3 flipper = (2.*mod(coord,2.)) - 1.;
    q.x *= -flipper.x;
    
    float t = .2*(z + dot(coord, vec3(1)));
    return vec4( flipper, KIFS( q, t ));
}

struct March
{
    vec3 pos;
    float dist;
    vec3 coord;
    float ao;
};

March march( vec3 ro, vec3 rd, float t )
{
    vec4 dist;
	float totalDist = 0.0;
    
    int i;
    for( i = 0; i < 120; ++i )
    {
        dist = map( ro, t );
        if( dist.w < .01 || totalDist > 200. ) break;
        totalDist += .6 * dist.w;
        ro += .6 * rd * dist.w;
    }
    
    return March( ro, dist.w < .01 ? totalDist : -1.0, dist.xyz, float(i) / 90. );
}

void main()
{
    float iTime = x_time;
    vec2 uv = gl_FragCoord.xy / vec2(720) - vec2(.5*1280./720., .5);
    
    vec3 ro = vec3(3.*iTime,5.,5.*iTime);
    vec3 rd = normalize(vec3(uv, 1));
    
    rd.xy *= rot( .11*iTime );
    rd.yz *= rot( .07*iTime );
    rd.zx *= rot( .05*iTime );
    
    March m = march( ro, rd, iTime );
    
    float lightness = 0.;
    vec3 color = .3*vec3(102, 139, 164) / 255.;
    
    if( m.dist >= 0.0 ) {
        float fog = exp( -.02*m.dist );
        lightness = fog * (1. - m.ao);
        
        vec3 coord01 = m.coord * .5 + .5;
        color = mix((vec3(151, 203, 169) / 255.), (vec3(254, 255, 223) / 255.), mod(dot(coord01,vec3(1)), 2.));
        
        vec3 shadow = mix((.1*vec3(102, 139, 164) / 255.), .3*vec3(102, 139, 164) / 255., 1. - fog);
        color = mix( shadow, color, lightness );        
    }

    x_fragColor = vec4(color,1);
}