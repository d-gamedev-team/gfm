module gfm.opengl;

// OpenGL OO wrapper
//
// TODO add support for:
//  - uniform blocks
//  - SSBO
//  - Sampler objects
//  - "storage" calls
//  - barriers

public
{
    import derelict.opengl3.gl3,
           derelict.opengl3.gl;

    import gfm.opengl.opengl,
           gfm.opengl.buffer,
           gfm.opengl.renderbuffer,
           gfm.opengl.shader,
           gfm.opengl.uniform,
           gfm.opengl.program,
           gfm.opengl.matrixstack,
           gfm.opengl.texture,
           gfm.opengl.fbo,
           gfm.opengl.vertex,
           gfm.opengl.vao;
}
