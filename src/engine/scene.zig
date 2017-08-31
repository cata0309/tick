use @import("../math/index.zig");

const c = @import("../system/c.zig");
const lib = @import("../system/lib.zig");
const app = @import("../app/core.zig");
const tex = @import("../graphics/sprite.zig");
const render = @import("../graphics/renderer.zig");

const ArrayList = lib.ArrayList;
const Window = app.Window;

const InputManager = app.InputManager;
const Texture = tex.Texture;
const IMRenderer = render.IMRenderer;
const BatchRenderer = render.BatchRenderer;

// Camera system modes
const CameraMode = enum {
    Custom,
    Free,
    Orbital,
    First_person,
    Third_person
};

pub const Camera = struct {
    position: Vec3,
    rotation: Vec3,
    focalPoint: Vec3,
    scale: f32,
    screenWidth: usize,
    screenHeight: usize,
    view_matrix: Mat4,
    projection_matrix: Mat4,
    orthographic_matrix: Mat4,
    needs_update: bool,
    active: bool,

    pub fn init(screenWidth: usize, screenHeight: usize) -> Camera {
        Camera {
            .position = vec3(0,0,0),
            .rotation = vec3(0,0,0),
            .focalPoint = vec3(0,0,0),
            .scale = 1,
            .screenWidth = screenWidth,
            .screenHeight = screenHeight,
            .view_matrix = Mat4.diagonal(1),
            .projection_matrix = Mat4.diagonal(1),
            .orthographic_matrix = Mat4.orthographic( 0.0, f32(screenWidth), f32(screenHeight), 0.0, 0.0, 1.0 ),
            .needs_update = true,
            .active = true,
        }
    }

    pub fn getAspectRatio(self: &Camera) -> f32 { 
        return f32(self.screenWidth) / f32(self.screenHeight);
    }

    pub fn offsetPosition(self: &Camera, offset: Vec2) {
        self.position.offset(offset);
        self.needs_update = true;
    }

    pub fn offsetScale(self: &Camera, offset: f32) -> void {
        self.scale += offset;
        if ( self.scale < 0.001) self.scale = 0.001;
        self.needs_update = true;
    }

    pub fn convertScreenToWorld(self: &Camera, screenCoords: &const Vec2) -> Vec3 {
        var worldCoords = vec3(
            screenCoords.x,
            self.screenHeight - screenCoords.y, // Invert Y direction
            0.0
        );

        // Center at 0, 0
        screenCoords.offset(vec2(-self.screenWidth / 2, -self.screenHeight / 2));
        
        worldCoords.scale(1/self.scale);
        worldCoords.offset(self.position);

        return worldCoords;
    }

    pub fn isBoxInView(self: &Camera, position: &const Vec2, dimenstions: &const Vec2) -> bool {
        const scaled_screen = vec2(self.screenWidth / self.scale, self.screenHeight / self.scale);

        const min_distance_x = (dimensions.x + scaled_screen.x) / 2.0;
        const min_distance_y = (dimensions.y + scaled_screen.y) / 2.0;

        const centerPos = position.add(dimensions.div_scalar(2.0));
        const dist_vec = centerPos.sub(self.position.xy());

        const xDepth = min_distance_x - math.fabs(dist_vec.x);
        const yDepth = min_distance_y - math.fabs(dist_vec.y);

        return (xDepth > 0 or yDepth > 0);
    }

    pub fn update(self: &Camera) -> void {
        if (self.needs_update) return;

        const translation = vec3(
            -self.position.x + f32(self.screenWidth / 2),
            -self.position.y + f32(self.screenHeight / 2),
            0.0
        );

        self.projection_matrix = self.orthographic_matrix.translate_vec(translation);

        const scale = vec3(self.scale, self.scale, 0.0);

        self.projection_matrix = Mat4.scaling(scale).mul(self.projection_matrix);
        self.needs_update = false;
    }

    pub fn translate(self: &Camera, translation: &const Vec3) {
        self.position.offset(translation);
    }
    
    pub fn rotate(self: &Camera, rotation: &const Vec3) {
        self.rotation.offset(rotation);
    }
};

pub const Scene2D = struct {
    renderer: &BatchRenderer,
    camera: &OrthographicCamera,
    agents: ArrayList(Agent),

    pub fn create(self: &Scene2D, width: usize, height: usize) -> Scene2D {
        const aspect = f32(width) / f32(height);

        self.camera = Camera.orthographic(
            Mat4.orthographic(-10.0 * aspect, 10.0 * aspect, -10.0, 10.0, -1.0, 1.0)
        );

        self.renderer = BatchRenderer.init(width, height);
        self.renderer.setCamera(self.camera);
    }

    pub fn create(self: &Scene2D, width: usize, height: usize, projection_matrix: Mat4) -> Scene2D {
        self.camera = Camera.orthographic(projection_matrix);
        self.renderer = BatchRenderer.init(width, height);
        self.renderer.setCamera(self.camera);
    }

    pub fn destroy(self: &Scene2D) -> void {
    }

    pub fn Add(self: &Scene2D, entity: &Agent) -> void {
        self.agents.push_back(entity);
    }

    pub fn Update(self: &Scene2D) -> void {
        for (self.agents) | agent, i | self.agents[i].update()
    }

    pub fn OnRender(self: &Scene2D) -> void {
        self.camera.update();

        self.renderer.begin();
        for (self.agents) | entity, i | {
            const sprite = entity.getComponent(SpriteComponent);
            if (sprite) {
                const tc = entity.getComponent(TransformComponent) ?? panic();
                sprite.sprite.submit(self.renderer);
            }
        }

        Render(self.renderer);

        self.renderer.end();
        self.renderer.present();
    }

    pub fn Render(self: &Scene2D, renderer: &BatchRenderer) -> void {
    
    }
};

const Scene3D = struct {
    renderer: &BatchRenderer,
    camera: &Camera,
    agents: ArrayList(Agent),
    lights: ArrayList(Light),

    pub fn create(camera: &Camera) -> Scene3D {
        self.camera(camera) {}
    }

    pub fn destroy(self: &Scene3D) -> Scene3D {
        for (self.agents) | agent, i | self.agents[i].destroy();

        self.agents.clear();
        self.camera.destroy();
    }

    pub fn Add(self: &Scene3D, entity: &Agent) -> void {
        self.agents.push_back(entity);
        entity.getComponent(TransformComponent) ?? {
            entity.addComponent(TransformComponent.create(Mat4.Identity()));
        }
    }

    pub fn PushLight(self: &Scene3D, light: &Light) -> void {
        self.lightStack.push_back(light);
    }

    pub fn PopLight(self: &Scene3D) -> &Light {
        const result = self.lights.back();
        self.lights.pop_back();
        return result;
    }

    pub fn SetCamera(self: &Scene3D, camera: &Camera) -> void {
        self.camera = camera;
        self.camera.focus();
    }

    pub fn Render(self: &Scene3D, renderer: &Renderer) -> void {
        self.camera.update();

        renderer.begin();
        renderer.beginScene(camera);

        for (self.lights) | light | renderer.submitLight(light);

        for (self.agents) {
            const mc = entity.GetComponent(MeshComponent);
            if (mesh) {
                const tc = entity.GetComponent(TransformComponent);
                renderer.submitMesh(mc.mesh, tc.transform);
            }
        }
        renderer.endScene();
        renderer.end();
    }
};

const MAX_LAYERS = 4;

const Layer = struct {
    window: &Window,
    renderer: &BatchRenderer,
    scene: &Scene,
    projection_matrix: mat4,
    visible: bool,
    renderables: []&Texture,

    pub fn add() {
    }
    
    pub fn submit() {
    }
    
    pub fn init() {
    }

    pub fn onInit() {
    }

    pub fn deinit() {
    }

    pub fn onDeinit() {
    }

    pub fn onTick() {
    }
    
    pub fn update() {
    }

    pub fn onUpdate() {
    }

    pub fn onRender() {
    }

    pub fn onResize() {
    }

    pub fn onEvent() {
    }
};

const Stack = struct {
    layers: [MAX_LAYERS]Layer,

    pub fn pushLayer(self: &Stack, layer: &Layer) {
        layers.push_back(layer);
        layer.Init();
    }

    pub fn popLayer(self: &Stack) -> &Layer {
        layer: &Layer = layers.back();
        layers.pop_back();
        return layer;
    }

    pub fn removeLayer(self: &Stack, layer: &Layer) -> &Layer {
        for ( layers ) | l |{
            if ( l == layer ) {
                layers.erase(layers.begin() + i);
                break;
            }
        }
        return layer;
    }

    pub fn onEvent(self: &Stack, event: Event) {
        for ( layers ) | l | l.onEvent(event);
    }

    pub fn onTick(self: &Stack) {
        for ( layers ) | l | l.onTick();
    }

    pub fn onUpdate(self: &Stack) {
        for (layers ) | l | l.onUpdate();
    }

    pub fn onRender(self: &Stack) {
        for ( layers ) | l | {
            if ( l.visible ) l.onRender();
        }
    }
};