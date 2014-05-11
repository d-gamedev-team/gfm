import std.math,
       std.typecons;

import std.logger;

import gfm.core,
       gfm.sdl2,
       gfm.opengl;

// This example show how to draw an OpenGL triangle

void main()
{
    int width = 1280;
    int height = 720;
    double ratio = width / cast(double)height;

    // create a logger
    auto log = new ConsoleLogger();

    // load dynamic libraries
    auto sdl2 = scoped!SDL2(log);
    auto gl = scoped!OpenGL(log);

    // create an OpenGL-enabled SDL window
    auto window = scoped!SDL2Window(sdl2, 
                                    SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                    width, height,
                                    SDL_WINDOW_OPENGL);

    // reload OpenGL now that a context exists
    gl.reload();

    double time = 0;
    while(!sdl2.keyboard().isPressed(SDLK_ESCAPE))
    {
        sdl2.processEvents();

        time += 0.10;

        // clear the whole window
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // load projection and model-view matrices
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(-ratio, +ratio, -1.0, 1.0, -1.0, 1.0);

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        glRotatef(time * 10, 0, 0, 1);

        // draw a single triangle
        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f);
            glVertex2f(-0.5, -0.5);
            glColor3f(0.0f, 1.0f, 0.0f);
            glVertex2f(+0.5f, -0.5f);
            glColor3f(0.0f, 0.0f, 1.0f);
            glVertex2f(0.0f, 0.6f);
        glEnd();

        window.swapBuffers();
    }
}

