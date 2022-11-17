class WebGLRenderer {
    // meshes = [];
    // shadowMeshes = [];
    /* 
    Items in lights
    {
        "light" : { entity : light, meshRender : light_mesh_renderer}, 
        "meshes" : [],
        shadowMeshes : []
    }
    */
    lights = [];

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;
    }

    addLight(light) {
        this.lights.push({ 

            light : {
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)}, 

            meshes : [],

            shadowMeshes : []
    });
    }
    addMeshRender(mesh, i) { this.lights[i].meshes.push(mesh); }
    addShadowMeshRender(mesh, i) { this.lights[i].shadowMeshes.push(mesh); }

    render() {
        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
        gl.clearDepth(1.0); // Clear everything
        gl.enable(gl.DEPTH_TEST); // Enable depth testing
        gl.depthFunc(gl.LEQUAL); // Near things obscure far things

        console.assert(this.lights.length != 0, "No light");
        // console.assert(this.lights.length == 1, "Multiple lights");

        let t = new Date().getTime() / 1000.0;
        let r = 20.0;
        let animation = [r * Math.cos(t), 0, r * Math.sin(t)];

        for (let l = 0; l < this.lights.length; l++) {
            gl.disable(gl.BLEND);

            // Shadow pass
            if (this.lights[l].light.entity.hasShadowMap == true) {
                gl.disable(gl.BLEND);
                gl.bindFramebuffer(gl.FRAMEBUFFER, this.lights[l].light.entity.fbo);
                gl.clearColor(1.0, 1.0, 1.0, 1.0);
                gl.clearDepth(1.0);
                gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

                for (let i = 0; i < this.lights[l].shadowMeshes.length; i++) {
                    this.lights[l].shadowMeshes[i].animated_trans = animation;
                    this.lights[l].shadowMeshes[i].draw(this.camera);
                }
            }

            if (l > 0) {
                gl.enable(gl.BLEND);
                gl.blendEquation(gl.FUNC_ADD);
                gl.blendFunc(gl.ONE, gl.ONE);
            }

            // Draw light
            // TODO: Support all kinds of transform
            this.lights[l].light.meshRender.mesh.transform.translate = this.lights[l].light.entity.lightPos;
            this.lights[l].light.meshRender.draw(this.camera);

            // Camera pass
            for (let i = 0; i < this.lights[l].meshes.length; i++) {
                this.lights[l].meshes[i].animated_trans = animation;
                this.gl.useProgram(this.lights[l].meshes[i].shader.program.glShaderProgram);
                this.gl.uniform3fv(this.lights[l].meshes[i].shader.program.uniforms.uLightPos, this.lights[l].light.entity.lightPos);
                this.lights[l].meshes[i].draw(this.camera);
            }
        }
    }
}