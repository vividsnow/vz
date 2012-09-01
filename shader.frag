uniform vec2 time;
uniform vec4 ctl;
uniform mat4 ctm;
varying vec3 position;

void main() {
    float d = distance(position.xy, vec2(0.5)) * 2.;
    vec2 rc = (position.xy - vec2(0.5)) * 2.;
    float a = atan(rc.y, rc.x);
    vec3 rgb = vec3(
         (ctl.y/3.+ctl.z/3.+ctl.x/3.)
                 * sin(d*ctm[0][2]*ctm[2][2]/2000.)
                 * cos((a+d*ctm[1][2]*ctl.y/600.*(0.5-ctl.z))*9.)
                 * sin(d*40.*ctl.x)*0.4, 
         ctl.y*distance(ctl.xz, rc.xy)*sin(position.x*ctm[2][2]/2500.*a*ctl.y*(-ctl.z))*cos(ctl.y*a*position.y*ctm[1][2]/20.),
         abs(1.-ctl.z/(1.+d*ctl.x*ctm[2][2]/400.))*distance(ctl.xy, rc.xy)*abs(cos(d*ctm[2][2]/3000.+ctm[0][3]/60.))
                 * cos(ctl.x+position.y*(1.-ctl.z)));
                 
    gl_FragColor = vec4(normalize(rgb.yxz), 1.) * clamp(1. - d, 0., 1.);
}     
