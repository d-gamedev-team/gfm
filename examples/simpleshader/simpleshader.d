import std.math,
       std.random,
       std.typecons;

import std.experimental.logger;

import gfm.logger,
       gfm.sdl2,
       gfm.opengl,
       gfm.math;

// This example show how to use shaders and textures

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

    // You have to initialize each SDL subsystem you want by hand
    sdl2.subSystemInit(SDL_INIT_VIDEO);
    sdl2.subSystemInit(SDL_INIT_EVENTS);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    // create an OpenGL-enabled SDL window
    auto window = scoped!SDL2Window(sdl2,
                                    SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                    width, height,
                                    SDL_WINDOW_OPENGL);

    // reload OpenGL now that a context exists
    gl.reload();

    // create a shader program made of a single fragment shader
    string tunnelProgramSource =
        q{#version 330 core

        #if VERTEX_SHADER
        in vec3 position;
        in vec2 coordinates;
        out vec2 fragmentUV;
        uniform mat4 mvpMatrix;
        void main()
        {
            gl_Position = mvpMatrix * vec4(position, 1.0);
            fragmentUV = coordinates;
        }
        #endif

        #if FRAGMENT_SHADER
        in vec2 fragmentUV;
        uniform float time;
        uniform sampler2D noiseTexture;
        out vec4 color;

        void main()
        {
            vec2 pos = fragmentUV - vec2(0.5, 0.5);
            vec4 noise = texture(noiseTexture, pos + vec2(0.5, 0.5));
            float u = length(pos);
            float v = atan(pos.y, pos.x) + noise.y * 0.04;
            float t = time / 0.5 + 1.0 / u;
            float intensity = abs(sin(t * 10.0 + v)+sin(v*8.0)) * .25 * u * 0.25 * (0.1 + noise.x);
            vec3 col = vec3(-sin(v*4.0+v*2.0+time), sin(u*8.0+v-time), cos(u+v*3.0+time))*16.0;
            color = vec4(col * intensity * (u * 4.0), 1.0);
        }
        #endif
    };

    auto program = scoped!GLProgram(gl, tunnelProgramSource);

    // create noise texture
    int texWidth = 1024;
    int texHeight = 1024;
    auto random = Random();
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
                sample += sin(freq * x / cast(float)texWidth) * cos(freq * y / cast(float)texHeight);
                amplitude /= 2;
                freq *= 2;
            }
            ubyte grey = cast(ubyte)(clamp(128.0 + 128.0 * sample, 0.0, 255.0));
            texData[ind++] = grey;
            texData[ind++] = grey;
            texData[ind++] = grey;
        }
    auto noiseTexture = scoped!GLTexture2D(gl);

    noiseTexture.setMinFilter(GL_LINEAR_MIPMAP_LINEAR);
    noiseTexture.setMagFilter(GL_LINEAR);
    noiseTexture.setWrapS(GL_REPEAT);
    noiseTexture.setWrapT(GL_REPEAT);
    noiseTexture.setImage(0, GL_RGB, texWidth, texHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, texData.ptr);
    noiseTexture.generateMipmap();


    struct Vertex
    {
        vec3f position;
        vec2f coordinates;
    }

    Vertex[] quad;
    quad ~= Vertex(vec3f(-1, -1, 0), vec2f(0, 0));
    quad ~= Vertex(vec3f(+1, -1, 0), vec2f(1, 0));
    quad ~= Vertex(vec3f(+1, +1, 0), vec2f(1, 1));
    quad ~= Vertex(vec3f(+1, +1, 0), vec2f(1, 1));
    quad ~= Vertex(vec3f(-1, +1, 0), vec2f(0, 1));
    quad ~= Vertex(vec3f(-1, -1, 0), vec2f(0, 0));

    auto quadVBO = scoped!GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW, quad[]);

    // Create an OpenGL vertex description from the Vertex structure.
    auto quadVS = new VertexSpecification!Vertex(program);

    auto vao = scoped!VAO(gl);
    double time = 0;

    uint lastTime = SDL_GetTicks();


    // prepare VAO
    {
        vao.bind();
        quadVBO.bind();
        quadVS.use();
        vao.unbind();
    }

    window.setTitle("Simple shader");

    while(!sdl2.keyboard().isPressed(SDLK_ESCAPE))
    {
        sdl2.processEvents();

        uint now = SDL_GetTicks();
        double dt = now - lastTime;
        lastTime = now;
        time += 0.001 * dt;

        // clear the whole window
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        int texUnit = 0;
        noiseTexture.use(texUnit);

        // uniform variables must be set before program use
        program.uniform("time").set(cast(float)time);
        program.uniform("noiseTexture").set(texUnit);
        program.uniform("mvpMatrix").set(mat4f.identity);
        program.use();


        // draw a full quad
        vao.bind();
        glDrawArrays(GL_TRIANGLES, 0, cast(int)(quadVBO.size() / quadVS.vertexSize()));
        vao.unbind();
        program.unuse();

        window.swapBuffers();
    }
}
