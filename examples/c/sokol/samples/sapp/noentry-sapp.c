//------------------------------------------------------------------------------
//  noentry-sapp.c
//
//  This demonstrates the SOKOL_NO_ENTRY mode of sokol_app.h, in this mode
//  sokol_app.h doesn't "hijack" the platform's main() function instead the
//  application must provide this. The sokol_app.h implementation must be
//  compiled with the SOKOL_NO_ENTRY define (see sokol-noentry.c/.m, 
//  which is compiled into a static link lib sokol-noentry)
//
//  This sample also demonstrates the optional user-data callbacks.
//------------------------------------------------------------------------------
#define HANDMADE_MATH_IMPLEMENTATION
#define HANDMADE_MATH_NO_SSE
#include "HandmadeMath.h"
#include "sokol_gfx.h"
#include "sokol_app.h"
#if defined(_WIN32)
#include <Windows.h>    /* WinMain */
#endif
#include <stdlib.h>     /* calloc, free */

static const char *vs_src, *fs_src;
#define SAMPLE_COUNT (4)

typedef struct {
    float rx, ry;
    sg_pipeline pip;
    sg_bindings bind;
} app_state_t;

typedef struct {
    hmm_mat4 mvp;
} vs_params_t;

/* user-provided callback prototypes */
void init(void* user_data);
void frame(void* user_data);
void cleanup(void);

/* don't provide a sokol_main() callback, instead the platform's standard main() function */
#if !defined(_WIN32)
int main(int argc, char* argv[]) {
#else
int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nCmdShow) {
#endif
    app_state_t* state = calloc(1, sizeof(app_state_t));
    int exit_code = sapp_run(&(sapp_desc){
        .user_data = state,
        .init_userdata_cb = init,
        .frame_userdata_cb = frame,
        .cleanup_cb = cleanup,          /* cleanup doesn't need access to the state struct */
        .width = 800,
        .height = 600,
        .sample_count = SAMPLE_COUNT,
        .gl_force_gles2 = true,
        .window_title = "Noentry (sokol-app)",
    });
    free(state);    /* NOTE: on some platforms, this isn't reached on exit */
    return exit_code;
}

void init(void* user_data) {
    app_state_t* state = (app_state_t*) user_data;
    sg_setup(&(sg_desc){
        .gl_force_gles2 = sapp_gles2(),
        .mtl_device = sapp_metal_get_device(),
        .mtl_renderpass_descriptor_cb = sapp_metal_get_renderpass_descriptor,
        .mtl_drawable_cb = sapp_metal_get_drawable,
        .d3d11_device = sapp_d3d11_get_device(),
        .d3d11_device_context = sapp_d3d11_get_device_context(),
        .d3d11_render_target_view_cb = sapp_d3d11_get_render_target_view,
        .d3d11_depth_stencil_view_cb = sapp_d3d11_get_depth_stencil_view
    });

    /* cube vertex buffer */
    float vertices[] = {
        -1.0, -1.0, -1.0,   1.0, 0.5, 0.0, 1.0,
         1.0, -1.0, -1.0,   1.0, 0.5, 0.0, 1.0,
         1.0,  1.0, -1.0,   1.0, 0.5, 0.0, 1.0,
        -1.0,  1.0, -1.0,   1.0, 0.5, 0.0, 1.0,

        -1.0, -1.0,  1.0,   0.5, 1.0, 0.0, 1.0,
         1.0, -1.0,  1.0,   0.5, 1.0, 0.0, 1.0,
         1.0,  1.0,  1.0,   0.5, 1.0, 0.0, 1.0,
        -1.0,  1.0,  1.0,   0.5, 1.0, 0.0, 1.0,

        -1.0, -1.0, -1.0,   0.0, 0.5, 1.0, 1.0,
        -1.0,  1.0, -1.0,   0.0, 0.5, 1.0, 1.0,
        -1.0,  1.0,  1.0,   0.0, 0.5, 1.0, 1.0,
        -1.0, -1.0,  1.0,   0.0, 0.5, 1.0, 1.0,

        1.0, -1.0, -1.0,    1.0, 0.5, 0.5, 1.0,
        1.0,  1.0, -1.0,    1.0, 0.5, 0.5, 1.0,
        1.0,  1.0,  1.0,    1.0, 0.5, 0.5, 1.0,
        1.0, -1.0,  1.0,    1.0, 0.5, 0.5, 1.0,

        -1.0, -1.0, -1.0,   0.5, 0.5, 1.0, 1.0,
        -1.0, -1.0,  1.0,   0.5, 0.5, 1.0, 1.0,
         1.0, -1.0,  1.0,   0.5, 0.5, 1.0, 1.0,
         1.0, -1.0, -1.0,   0.5, 0.5, 1.0, 1.0,

        -1.0,  1.0, -1.0,   0.5, 1.0, 0.5, 1.0,
        -1.0,  1.0,  1.0,   0.5, 1.0, 0.5, 1.0,
         1.0,  1.0,  1.0,   0.5, 1.0, 0.5, 1.0,
         1.0,  1.0, -1.0,   0.5, 1.0, 0.5, 1.0
    };
    sg_buffer vbuf = sg_make_buffer(&(sg_buffer_desc){
        .size = sizeof(vertices),
        .content = vertices,
    });

    /* create an index buffer for the cube */
    uint16_t indices[] = {
        0, 1, 2,  0, 2, 3,
        6, 5, 4,  7, 6, 4,
        8, 9, 10,  8, 10, 11,
        14, 13, 12,  15, 14, 12,
        16, 17, 18,  16, 18, 19,
        22, 21, 20,  23, 22, 20
    };
    sg_buffer ibuf = sg_make_buffer(&(sg_buffer_desc){
        .type = SG_BUFFERTYPE_INDEXBUFFER,
        .size = sizeof(indices),
        .content = indices,
    });

    /* create shader */
    sg_shader shd = sg_make_shader(&(sg_shader_desc) {
        .attrs = {
            [0] = { .name="position", .sem_name="POS" },
            [1] = { .name="color0", .sem_name="COLOR" }
        },
        .vs.uniform_blocks[0] = {
            .size = sizeof(vs_params_t),
            .uniforms = {
                [0] = { .name="mvp", .type=SG_UNIFORMTYPE_MAT4 }
            }
        },
        .vs.source = vs_src,
        .fs.source = fs_src
    });

    /* create pipeline object */
    state->pip = sg_make_pipeline(&(sg_pipeline_desc){
        .layout = {
            /* test to provide buffer stride, but no attr offsets */
            .buffers[0].stride = 28,
            .attrs = {
                [0].format = SG_VERTEXFORMAT_FLOAT3,
                [1].format = SG_VERTEXFORMAT_FLOAT4
            }
        },
        .shader = shd,
        .index_type = SG_INDEXTYPE_UINT16,
        .depth_stencil = {
            .depth_compare_func = SG_COMPAREFUNC_LESS_EQUAL,
            .depth_write_enabled = true,
        },
        .rasterizer.cull_mode = SG_CULLMODE_BACK,
        .rasterizer.sample_count = SAMPLE_COUNT,
    });

    /* setup resource bindings */
    state->bind = (sg_bindings) {
        .vertex_buffers[0] = vbuf,
        .index_buffer = ibuf
    };
}

void frame(void* user_data) {
    app_state_t* state = (app_state_t*) user_data;
    vs_params_t vs_params;
    const float w = (float) sapp_width();
    const float h = (float) sapp_height();
    hmm_mat4 proj = HMM_Perspective(60.0f, w/h, 0.01f, 10.0f);
    hmm_mat4 view = HMM_LookAt(HMM_Vec3(0.0f, 1.5f, 6.0f), HMM_Vec3(0.0f, 0.0f, 0.0f), HMM_Vec3(0.0f, 1.0f, 0.0f));
    hmm_mat4 view_proj = HMM_MultiplyMat4(proj, view);
    state->rx += 1.0f; state->ry += 2.0f;
    hmm_mat4 rxm = HMM_Rotate(state->rx, HMM_Vec3(1.0f, 0.0f, 0.0f));
    hmm_mat4 rym = HMM_Rotate(state->ry, HMM_Vec3(0.0f, 1.0f, 0.0f));
    hmm_mat4 model = HMM_MultiplyMat4(rxm, rym);
    vs_params.mvp = HMM_MultiplyMat4(view_proj, model);

    sg_pass_action pass_action = {
        .colors[0] = { .action = SG_ACTION_CLEAR, .val = { 0.5f, 0.25f, 0.75f, 1.0f } }
    };
    sg_begin_default_pass(&pass_action, (int)w, (int)h);
    sg_apply_pipeline(state->pip);
    sg_apply_bindings(&state->bind);
    sg_apply_uniforms(SG_SHADERSTAGE_VS, 0, &vs_params, sizeof(vs_params));
    sg_draw(0, 36, 1);
    sg_end_pass();
    sg_commit();
}

void cleanup() {
    sg_shutdown();
}

#if defined(SOKOL_GLCORE33)
static const char* vs_src =
    "#version 330\n"
    "uniform mat4 mvp;\n"
    "in vec4 position;\n"
    "in vec4 color0;\n"
    "out vec4 color;\n"
    "void main() {\n"
    "  gl_Position = mvp * position;\n"
    "  color = color0;\n"
    "}\n";
static const char* fs_src =
    "#version 330\n"
    "in vec4 color;\n"
    "out vec4 frag_color;\n"
    "void main() {\n"
    "  frag_color = color;\n"
    "}\n";
#elif defined(SOKOL_GLES3) || defined(SOKOL_GLES2)
static const char* vs_src =
    "uniform mat4 mvp;\n"
    "attribute vec4 position;\n"
    "attribute vec4 color0;\n"
    "varying vec4 color;\n"
    "void main() {\n"
    "  gl_Position = mvp * position;\n"
    "  color = color0;\n"
    "}\n";
static const char* fs_src =
    "precision mediump float;\n"
    "varying vec4 color;\n"
    "void main() {\n"
    "  gl_FragColor = color;\n"
    "}\n";
#elif defined(SOKOL_METAL)
static const char* vs_src =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct params_t {\n"
    "  float4x4 mvp;\n"
    "};\n"
    "struct vs_in {\n"
    "  float4 position [[attribute(0)]];\n"
    "  float4 color [[attribute(1)]];\n"
    "};\n"
    "struct vs_out {\n"
    "  float4 pos [[position]];\n"
    "  float4 color;\n"
    "};\n"
    "vertex vs_out _main(vs_in in [[stage_in]], constant params_t& params [[buffer(0)]]) {\n"
    "  vs_out out;\n"
    "  out.pos = params.mvp * in.position;\n"
    "  out.color = in.color;\n"
    "  return out;\n"
    "}\n";
static const char* fs_src =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "fragment float4 _main(float4 color [[stage_in]]) {\n"
    "  return color;\n"
    "}\n";
#elif defined(SOKOL_D3D11)
static const char* vs_src =
    "cbuffer params: register(b0) {\n"
    "  float4x4 mvp;\n"
    "};\n"
    "struct vs_in {\n"
    "  float4 pos: POS;\n"
    "  float4 color: COLOR0;\n"
    "};\n"
    "struct vs_out {\n"
    "  float4 color: COLOR0;\n"
    "  float4 pos: SV_Position;\n"
    "};\n"
    "vs_out main(vs_in inp) {\n"
    "  vs_out outp;\n"
    "  outp.pos = mul(mvp, inp.pos);\n"
    "  outp.color = inp.color;\n"
    "  return outp;\n"
    "};\n";
static const char* fs_src =
    "float4 main(float4 color: COLOR0): SV_Target0 {\n"
    "  return color;\n"
    "}\n";
#endif
