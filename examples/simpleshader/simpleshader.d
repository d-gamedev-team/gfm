import std.math,
       std.random,
       std.typecons;

import gfm.common.all,
       gfm.sdl2.all,
       gfm.opengl.all,
       gfm.math.all;

// This example show how to use shaders and textures

void main()
{
    int width = 1280;
    int height = 720;
    double ratio = width / cast(double)height;

    // create a default logger
    auto log = defaultLog();

    // load dynamic libraries
    auto sdl2 = scoped!SDL2(log);
    auto gl = scoped!OpenGL(log);

    // create an OpenGL-enabled SDL window
    auto window = scoped!SDL2Window(sdl2, 
                                    SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                    width, height,
                                    SDL_WINDOW_OPENGL);    

    // create an event queue and register that window
    auto eventQueue = scoped!SDL2EventQueue(sdl2);
    eventQueue.registerWindow(window);

    // reload OpenGL now that a context exists
    gl.reload();

    // the FrameCounter object gives the clock and maintain statistics about framerate
    auto fc = scoped!FrameCounter(sdl2);

    // create a shader program made of a single fragment shader
    string tunnelProgramSource = 
        r"#version 110
        #if FRAGMENT_SHADER

        uniform float time;
        uniform vec2 resolution;
        uniform sampler2D noiseTexture;
        #define pi 3.1415927410125

        void main()
        {
            vec2 pos = gl_FragCoord.xy / resolution - vec2(0.5, 0.5);
            vec4 noise = texture2D(noiseTexture, pos + vec2(0.5, 0.5));
            pos.x *= (resolution.x / resolution.y);

            float u = length(pos);
            float v = atan(pos.y, pos.x) + noise.y * 0.04;
            float t = time / 0.5 + 1.0 / u;

            float intensity = abs(sin(t * 10.0 + v)+sin(v*8.0)) * .25 * u * 0.25 * (0.1 + noise.x);
            vec3 col = vec3(-sin(v*4.0+v*2.0+time), sin(u*8.0+v-time), cos(u+v*3.0+time))*16.0;

            gl_FragColor = vec4(col * intensity * (u * 4.0), 1.0);
        }
        #endif
    ";

    auto program = new GLProgram(gl, tunnelProgramSource);

    // create noise texture
    int texWidth = 1024;
    int texHeight = 1024;
    auto random = Random();
    auto simplex = new SimplexNoise!Random(random);
    ubyte texData[] = new ubyte[texWidth * texHeight * 3];
    int ind = 0;
    for (int y = 0; y < texHeight; ++y)
        for (int x = 0; x < texWidth; ++x)
        {
            float sample = 0;
            float amplitude = 100;
            float freq = 1;
            for (int level = 0; level < 8; ++level)
            {
                sample += simplex.noise(freq * x / cast(float)texWidth, freq * y / cast(float)texHeight);                
                amplitude /= 2;
                freq *= 2;
            }
            ubyte grey = cast(ubyte)(clamp(128.0 + 128.0 * sample, 0.0, 255.0));
            texData[ind++] = grey;
            texData[ind++] = grey;
            texData[ind++] = grey;
        }
    auto noiseTexture = new GLTexture2D(gl);
    
    noiseTexture.setMinFilter(GL_LINEAR_MIPMAP_LINEAR);
    noiseTexture.setMagFilter(GL_LINEAR);
    noiseTexture.setWrapS(GL_REPEAT);
    noiseTexture.setWrapT(GL_REPEAT);
    noiseTexture.setImage(0, GL_RGB, texWidth, texHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, texData.ptr);    
    noiseTexture.generateMipmap();

    double time = 0;
    while(!eventQueue.keyboard().isPressed(SDLK_ESCAPE))
    {
        eventQueue.processEvents();

        double dt = fc.tickMs();
        time += 0.001 * dt;

        // clear the whole window
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // load projection and model-view matrices
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        // uniform variable can be set at any time
        program.uniform("resolution").set(vec2f(width, height));
        program.uniform("time").set(cast(float)time);
        program.uniform("noiseTexture").set(0);

        noiseTexture.use(0);

        program.use();        

        // draw a full quad
        glBegin(GL_QUADS);
            glVertex2i(+1, -1);
            glVertex2i(+1, +1);
            glVertex2i(-1, +1);
            glVertex2i(-1, -1);            
        glEnd();

        program.unuse();

        window.setTitle(fc.getFPSString());
        window.swapBuffers();        
    }
}
