varying vec3 position;

void main(void)
{
  gl_Position = ftransform();
  position    = vec3(gl_Vertex);
}
