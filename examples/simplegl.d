import std.stdio;
import std.math;
import gfm.sdl2.all;
import gfm.common.all;
import gfm.opengl.all;


class MyWindow : SDL2Window
{
    this(SDL2 sdl2, box2i position, bool fullscreen)
    {
        super(sdl2, position, fullscreen, true, false);
    }
}

void main()
{
    auto log = new ConsoleLog();

    auto sdl2 = new SDL2(log);
    scope(exit) sdl2.close();

    auto gl = new OpenGL(log);
    scope(exit) gl.close();

    auto displays = sdl2.getDisplays();

    if (displays.length == 0)
        return; // no display

    auto bounds = displays[0].bounds().shrink(vec2i(40));

    auto window = new MyWindow(sdl2, bounds, false);
    scope(exit) window.close();

    auto eventQueue = new SDL2EventQueue(sdl2, log);
    eventQueue.registerWindow(window);

    FrameCounter fc = new FrameCounter(sdl2);

    gl.reload();

    auto shader = new GLShader(gl, GL_FRAGMENT_SHADER, 
    [
    r"uniform vec4 col;

      void main()
      {
          gl_FragColor = col;
      }
     "]);

    auto program = new GLProgram(gl, shader);
   
    double t = 0;
    while(!eventQueue.keyboard().isPressed(SDLK_ESCAPE))
    {
        eventQueue.processEvents();

        auto dt = fc.tickMs();

        glViewport(0, 0, bounds.width, bounds.height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();

        glDisable(GL_DEPTH_TEST);
        t += dt * 0.001;

        glBegin(GL_QUADS);
        glColor3f(1,0,0);
        glVertex2f(-1,-1);
        glColor3f(0,0,sin(t));
        glVertex2f(+1,-1);
        glColor3f(1,cos(t),1);
        glVertex2f(+1,+1);
        glColor3f(1,1,cos(t));
        glVertex2f(-1,+1);
        glEnd();

        program.uniform("col").set(vec4f(1.0f, 0.5f, 0.3f, 0.5f));
        program.use();

        glRotatef(t * 10, 0, 0, 1);
        glBegin(GL_TRIANGLES);
        glColor3f(0,0,0);
        glVertex2f(-0.5,-0.5);
        glVertex2f(+0.5,-0.5);
        glColor3f(1,1,1);
        glVertex2f(0,+1.5);
        glEnd();

        program.unuse();
        
        window.setTitle(fc.getFPSString());
        window.swapBuffers();        
    }
}
