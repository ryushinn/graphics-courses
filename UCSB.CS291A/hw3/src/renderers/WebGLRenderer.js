class WebGLRenderer {
    meshes = [];
    shadowMeshes = [];
    bufferMeshes = [];
    lights = [];

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;
    }

    addLight(light) {
        this.lights.push({
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)
        });
    }
    addMeshRender(mesh) { this.meshes.push(mesh); }
    addShadowMeshRender(mesh) { this.shadowMeshes.push(mesh); }
    addBufferMeshRender(mesh) { this.bufferMeshes.push(mesh); }

    render() {
        console.assert(this.lights.length != 0, "No light");
        console.assert(this.lights.length == 1, "Multiple lights");
        var light = this.lights[0];

        const gl = this.gl;
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clearDepth(1.0);
        gl.enable(gl.DEPTH_TEST);
        gl.depthFunc(gl.LEQUAL);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Update parameters
        let lightVP = light.entity.CalcLightVP();
        let lightDir = light.entity.CalcShadingDirection();
        let updatedParamters = {
            "uLightVP": lightVP,
            "uLightDir": lightDir,
        };

        // Draw light
        light.meshRender.mesh.transform.translate = light.entity.lightPos;
        light.meshRender.draw(this.camera, null, updatedParamters);

        // Shadow pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, light.entity.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.shadowMeshes.length; i++) {
            this.shadowMeshes[i].draw(this.camera, light.entity.fbo, updatedParamters);
            // this.shadowMeshes[i].draw(this.camera);
        }
        // return;

        // Buffer pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.camera.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.bufferMeshes.length; i++) {
            this.bufferMeshes[i].draw(this.camera, this.camera.fbo, updatedParamters);
            // this.bufferMeshes[i].draw(this.camera);
        }
        // return

        // generate mipmaps
        let GDepthTexture = this.camera.fbo.textures[1];
        let mipmap_fbo = this.camera.fbo.mipmap_fbo;
        let attachment = gl_draw_buffers["COLOR_ATTACHMENT0_WEBGL"];

        // bind quad
        gl.bindBuffer(gl.ARRAY_BUFFER, quadVBO);
        gl.vertexAttribPointer(
            mipmapShader.program.attribs["aVertexPosition"],
            2, gl.FLOAT, gl.FALSE, 0, 0);
        gl.enableVertexAttribArray(
            mipmapShader.program.attribs["aVertexPosition"]);
        
        // bind framebuffer and temporarily config gl context
        gl.bindFramebuffer(gl.FRAMEBUFFER, mipmap_fbo);
        gl.useProgram(mipmapShader.program.glShaderProgram);

        let w = window.screen.width;
        let h = window.screen.height;
        for (let i = 0; i < mipmap_fbo.maxLevel; i++) {
            // bind uniforms
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, i == 0? GDepthTexture : mipmap_fbo.mipmap[i - 1]);
            gl.uniform1i(mipmapShader.program.uniforms['uDepthBuffer'], 0);
            gl.uniform1i(mipmapShader.program.uniforms['preWidth'], w);
            gl.uniform1i(mipmapShader.program.uniforms['preHeight'], h);

            gl.framebufferTexture2D(gl.FRAMEBUFFER, attachment, gl.TEXTURE_2D, mipmap_fbo.mipmap[i], 0);
            gl.viewport(0, 0, w, h);
            gl.clear(gl.COLOR_BUFFER_BIT);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
            w /= 2;
            h /= 2;
        }
        // restore default configurations
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);

        // Camera pass
        for (let i = 0; i < this.meshes.length; i++) {
            this.meshes[i].draw(this.camera, null, updatedParamters);
        }
    }
}