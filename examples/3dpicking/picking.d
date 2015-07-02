import std.math,
       std.random,
       std.typecons;

import std.experimental.logger;

import derelict.util.loader;

import gfm.logger,
       gfm.sdl2,
       gfm.opengl,
       gfm.math;

// This example demonstrate 3D picking

void main()
{
    int width = 1280;
    int height = 720;
    double ratio = width / cast(double)height;

    // create a logger
    auto log = new ConsoleLogger();

    // load dynamic libraries
    auto sdl2 = scoped!SDL2(log, SharedLibVersion(2, 0, 0));
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

    // redirect OpenGL output to our Logger
    gl.redirectDebugOutput();

    // create a shader program made of a single fragment shader
    string programSource =
        q{#version 330 core

        #if VERTEX_SHADER
        in vec4 position;
        in vec4 color;
        flat out int objectId;
        out vec4 fragColor;
        uniform mat4 mvpMatrix;
        void main()
        {
            gl_Position = mvpMatrix * vec4(position.xyz, 1.0);
            fragColor = color;
            objectId = int(position.w);
        }
        #endif

        #if FRAGMENT_SHADER
        in vec4 fragColor;
        flat in int objectId;
        out vec4 color;
        uniform int primitiveId;
        uniform int currentObjectId;
        uniform int contour;

        void main()
        {
            if(objectId == currentObjectId)
            {
                if(gl_PrimitiveID == primitiveId)
                    color = vec4(0.5, 0.5, 1.0, 1.0);
                else
                    color = fragColor;
                if(contour != 0)
                    color = vec4(1, 0.2, 0.2, 1.);
            }
            else
                color = fragColor;
        }
        #endif
    };

    auto program = scoped!GLProgram(gl, programSource);

    struct Vertex
    {
        vec4f position;
        vec4f color;
    }

    Vertex[] objects;
    objects = [
        // first object
        Vertex(vec4f(0.2, 0.6, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.6, 0.6, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.4, 0.2, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),

        Vertex(vec4f(0.2, 0.6, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.4, 0.8, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.6, 0.6, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),

        Vertex(vec4f(0.6, 0.6, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.4, 0.8, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        Vertex(vec4f(0.8, 0.8, 0, 1), vec4f(1.0, 1.0, 0.5, 1.0)),
        // second object
        Vertex(vec4f(0.6, 0.2, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.7, 0.5, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.8, 0.2, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),

        Vertex(vec4f(0.8, 0.2, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.7, 0.5, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.8, 0.5, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),

        Vertex(vec4f(0.7, 0.5, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.8, 0.7, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
        Vertex(vec4f(0.8, 0.5, 0, 2), vec4f(1.0, 0.5, 1.0, 1.0)),
    ];

    auto objectsVBO  = scoped!GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW, objects[]);
    
    // Create an OpenGL vertex description from the Vertex structure.
    auto vertSpec = new VertexSpecification!Vertex(program);

    auto vao = scoped!VAO(gl);

    PickingObject pickingObject = new PickingObject(gl,  width, height);
    scope(exit) pickingObject.close();

    // prepare VAO
    {
        vao.bind();
        objectsVBO.bind();
        vertSpec.use();
        vao.unbind();
    }

    window.setTitle("3D picking");

    auto mouse = sdl2.mouse();

    while(!sdl2.keyboard.isPressed(SDLK_ESCAPE))
    {
        sdl2.processEvents();

        void drawObjects()
        {
            vao.bind();
            glDrawArrays(GL_TRIANGLES, 0, cast(int)(objectsVBO.size() / vertSpec.vertexSize()));
            vao.unbind();
        }

        pickingObject.setDrawing();
        pickingObject.bindFBO();
        
        // clear the whole window
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        pickingObject.renderToTexture(&drawObjects);
        pickingObject.unbindFBO();

        import std.stdio;
        auto res = pickingObject.readPixel(mouse.x, height-mouse.y);
        
        // clear the whole window
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // uniform variables must be set before program use
        program.uniform("mvpMatrix").set(mat4f.identity);
        program.uniform("currentObjectId").set(cast(int)res.objectId);
        program.uniform("primitiveId").set(cast(int)res.primitiveId-1);
        program.uniform("contour").set(1);
        program.use();

        glLineWidth(5);
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

        drawObjects();

        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        program.uniform("contour").set(0);

        drawObjects();

        program.unuse();

        window.swapBuffers();
    }
}

class PickingObject
{
public:
    // Structure describes format of shader output data
    static struct PixelInfo
    {
        float objectId;
        float drawIndex;
        float primitiveId;
    }

    this(OpenGL gl, int screenWidth, int screenHeight)
    {
        _screenBuf = new GLTexture2D(gl);
        _screenBuf.setMagFilter(GL_LINEAR);
        _screenBuf.setImage(0, GL_RGB32F, screenWidth, screenHeight, 0, GL_RGB, GL_FLOAT, null);
        
        _fbo = new GLFBO(gl);
        _fbo.use();
        _fbo.color(0).attach(_screenBuf);
        _fbo.unuse();

        // create a shader program that render primitive number in our texture
        string pickingProgramSource =
            q{#version 330 core

                #if VERTEX_SHADER
                in vec4 position;
                in vec4 color;
                flat out int objectId;
                uniform mat4 mvpMatrix;

                void main()
                {
                    gl_Position = mvpMatrix * vec4(position.xyz, 1.0);
                    objectId = int(position.w);
                }
                #endif

                #if FRAGMENT_SHADER
                flat in int objectId;
                uniform int gDrawIndex;

                out vec3 fragColor;

                void main()
                {
                    fragColor = vec3(float(objectId), float(gDrawIndex),float(gl_PrimitiveID + 1));
                }
                #endif
            };

        _program = new GLProgram(gl, pickingProgramSource);
    }

    ~this()
    {
        close();
    }

    void close()
    {
        _program.close();
        _fbo.close();
        _screenBuf.close();
    }

    void setDrawing()
    {
        _fbo.setTarget(GLFBO.Usage.DRAW);
    }

    void setReading()
    {
        _fbo.setTarget(GLFBO.Usage.READ);
    }

    void bindFBO()
    {
        _fbo.use();
    }

    void unbindFBO()
    {
        _fbo.unuse();
    }

    // Post-processing pass
    void renderToTexture(void delegate() drawGeometry)
    {
        _program.uniform("gDrawIndex").set(1);
        _program.uniform("mvpMatrix").set(mat4f.identity);
        _program.use();

        drawGeometry();
        _program.unuse();
    }

    auto readPixel(uint x, uint y)
    {
        import derelict.opengl3.constants: GL_NONE;
        
        setReading();
        bindFBO();
        glReadBuffer(GL_COLOR_ATTACHMENT0);

        PixelInfo pixelInfo;
        glReadPixels(x, y, 1, 1, GL_RGB, GL_FLOAT, &pixelInfo);

        glReadBuffer(GL_NONE);
        unbindFBO();

        return pixelInfo;
    }

private:
    GLFBO _fbo;
    GLTexture2D _screenBuf;
    GLProgram _program;
}