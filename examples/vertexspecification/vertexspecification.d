import gfm.opengl,
       gfm.sdl2;

import std.typecons,
       std.string;

void main()
{
    int width = 800;
    int height = 600;
    auto sdl = scoped!SDL2(null);
    auto gl  = scoped!OpenGL(null);

    auto window = scoped!SDL2Window(sdl, SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_OPENGL);
    gl.reload();

    //standard OpenGL calls
    glViewport(0, 0, width, height);
    glClearColor(0, 0, 0, 1);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    alias GLfloat[3] Position;
    alias GLfloat[3] Color;
    struct Vertex 
    {
        Position position;
        Color color;
    }
    Vertex[4] squareVertices = [{[0, 0, 0], [1, 1, 1]},
                                {[1, 0, 0], [0, 1, 1]},
                                {[1, 1, 0], [0, 0, 1]},
                                {[0, 1, 0], [0.5, 0.5, .5]}     ];
    GLuint[6] squareIndices = [0, 1, 2, 0, 2, 3];

    Vertex[3] triangleVertices = [{[-0.5, -0.5, 0], [1, 0, 0]},
                                  {[ 0.5, -0.5, 0], [0, 1, 0]},
                                  {[   0,  0.5, 0], [1, 1, 0]}  ];

    Vertex[8] hexFanVertices = [{[   0,   0, 0], [1, 1, 1]},
                                {[   0,   1, 0], [0, 1, 0]},
                                {[ 0.5, 0.5, 0], [0, 1, 0]},
                                {[ 0.5,-0.5, 0], [0, 1, 0]},
                                {[   0,  -1, 0], [0, 1, 0]},
                                {[-0.5,-0.5, 0], [0, 1, 0]},
                                {[-0.5, 0.5, 0], [0, 1, 0]},
                                {[   0,   1, 0], [0, 1, 0]}     ];

    VertexSpecification squareVS, triangleVS, hexVS;


    // SQUARE
    squareVS   = new VertexSpecification(gl);
    // create and bind the buffer used by the square vertices.
    squareVS.VBO = new GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW);
    squareVS.VBO.setData(squareVertices.sizeof, squareVertices.ptr);
    // create and bind the buffer used by the square indices.
    squareVS.IBO = new GLBuffer(gl, GL_ELEMENT_ARRAY_BUFFER, GL_STATIC_DRAW);
    squareVS.IBO.setData(squareIndices.sizeof, squareIndices.ptr);

    // write and compile the shaders for the SQUARE
    string[] squareVertSource = 
    [
        "#version 110\n",
        "void main() {",
        "  gl_FrontColor = gl_Color;",
        "  gl_Position = vec4(0.5, 0.5, 0.5, 1) * gl_Vertex;",
        "}"
    ];

    string[] squareFragSource = 
    [
        "#version 110\n",
        "void main() {",
        "    gl_FragColor = gl_Color;",
        "}"
    ];

    auto squareVertex = new GLShader(gl, GL_VERTEX_SHADER, squareVertSource);
    auto squareFrag = new GLShader(gl, GL_FRAGMENT_SHADER, squareFragSource);
    auto squareProgram = new GLProgram(gl, squareVertex, squareFrag);

    // Add attributes for the square: position and color with "legacy" code (OpenGL 2.0 style), 3 floats each.
    // Variables will be accessible in the shader by 'gl_Vertex' and 'gl_Color' variables
    squareVS.addLegacy(VertexAttribute.Role.POSITION, GL_FLOAT, 3);
    squareVS.addLegacy(VertexAttribute.Role.COLOR, GL_FLOAT, 3);


    // TRIANGLE
    triangleVS = new VertexSpecification(gl);
    // create and bind the buffer used by the triangle vertices
    GLBuffer triangleVBO; // this buffer will hold the vertex data
    triangleVBO = new GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW);
    triangleVBO.setData(triangleVertices.sizeof, triangleVertices.ptr);
    //please note: we will NOT use indices for the triangle, and will NOT confer VBO controll over the triangleVS object

    //write and compile the shaders for the TRIANGLE
    string[] triangleVertSource = 
    [
        "#version 110\n",
        "attribute vec4 color_attribute;",
        "varying vec4 Color;",
        "void main() {",
        "  Color = color_attribute;",
        "  gl_Position = vec4(0.5, 0.5, 0.5, 1) * gl_Vertex;",
        "}"
    ];

    string[] triangleFragSource = 
    [
        "#version 110\n",
        "varying vec4 Color;"
        "void main() {",
        "    gl_FragColor = vec4(Color.xyz, 0.7);",
        "}"
    ];

    auto triangleVertex = new GLShader(gl, GL_VERTEX_SHADER, triangleVertSource);
    auto triangleFrag = new GLShader(gl, GL_FRAGMENT_SHADER, triangleFragSource);
    auto triangleProgram = new GLProgram(gl, triangleFrag, triangleVertex);

    // add one attribute to the triangle: position, as "legacy" Role.POSITION (OpenGL 2.0 style);
    // add another attribute: color, as GENERIC attribute (OpenGL 3.0+ style); the color is added by attribute name
    // Variables will be accessible in the shader by 'gl_Vertex' and 'color_attribute' respectively
    triangleVS.addLegacy(VertexAttribute.Role.POSITION, GL_FLOAT, 3);
    triangleVS.addGeneric(GL_FLOAT, 3, "color_attribute");


    // HEXAGON
    hexVS     = new VertexSpecification(gl);
    // create and bind the buffer used by the hexagon vertices.
    hexVS.VBO = new GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW);
    hexVS.VBO.setData(hexFanVertices.sizeof, hexFanVertices.ptr);

    //write and compile the shaders for the HEXAGON
    string[] hexVertSource = 
    [
        "#version 330\n",                    //NOTE: OpenGL 3 + extensions / OpenGL3.3 required for this shader!
        "#extension GL_ARB_explicit_attrib_location : enable\n",
        "layout(location = 0) in vec4 position_attribute;",
        "layout(location = 1) in vec4 color_attribute;",
        "out vec4 out_Color;",
        "void main() {",
        "  out_Color = color_attribute;", //pass the color to the post-vertex and to the fragment shader
        "  gl_Position = vec4(0.5, 0.4, 1, 1) * position_attribute + vec4(-0.4, 0.4, 0, 0);",
        "}"
    ];

    string[] hexFragSource = 
    [
        "#version 330\n",                    //NOTE: OpenGL 3.0 REQUIRED FOR VERSION 330!
        "in vec4 out_Color;",
        "out vec4 final_Color;",
        "void main() {",
        "    final_Color = out_Color;",
        "}"
    ];

    auto hexVertex = new GLShader(gl, GL_VERTEX_SHADER, hexVertSource);
    auto hexFrag = new GLShader(gl, GL_FRAGMENT_SHADER, hexFragSource);
    auto hexProgram = new GLProgram(gl, hexFrag, hexVertex);

    // add attributes for the hexagon: position and color as GENERIC attributes (OpenGL 3.0+ style), 3 floats each
    // both are added by attribute location (the location is fixed in the shader via "layout(location = N) in ...")
    hexVS.addGeneric(GL_FLOAT, 3, 0);
    hexVS.addGeneric(GL_FLOAT, 3, 1);


    // unbind buffers: not really needed, but it's nice to clean your own mess.
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    /* While the program is running */
    while(!sdl.keyboard().isPressed(SDLK_ESCAPE)) 
    {
        sdl.processEvents();

        // clear the whole window
        glClear(GL_COLOR_BUFFER_BIT);

        // draw the square
        squareVS.use();         // use this VertexSpecification
        squareProgram.use();    // use the square shader program
        glDrawElements(GL_TRIANGLES, cast(int)(squareVS.IBO.size() / uint.sizeof), GL_UNSIGNED_INT, cast(void*)0);
        squareProgram.unuse();  // unuse this VertexSpecification
        squareVS.unuse();       // unuse the square shader program

        // draw the triangle
        triangleVBO.bind();     // manually bind the VBO
        triangleProgram.use();
        triangleVS.use(triangleProgram);
        glDrawArrays(GL_TRIANGLES, 0, cast(int)(triangleVBO.size() / triangleVS.vertexSize()));
        triangleProgram.unuse();
        triangleVS.unuse();

        // draw the hexagon
        hexProgram.use();       // use the hexagon shader program
        hexVS.use();            // use this VertexSpecification
        glDrawArrays(GL_TRIANGLE_FAN, 0, cast(int)(hexVS.VBO.size() / hexVS.vertexSize()));
        hexProgram.unuse();     // unuse th VertexSpecification
        hexVS.unuse();          // unuse the shader program

        window.setTitle("Test: a green hexagon, a blue rectangle, a yellow transparent triangle");
        window.swapBuffers();
    }
}
