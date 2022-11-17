class SSRMaterial extends Material {
    constructor(diffuseMap, specularMap, light, camera, vertexShader, fragmentShader) {
        let lightIntensity = light.mat.GetIntensity();
        let lightVP = light.CalcLightVP();
        let lightDir = light.CalcShadingDirection();

        let uniforms = {
            'uLightRadiance': { type: '3fv', value: lightIntensity },
            'uLightDir': { type: '3fv', value: lightDir },
            'uGDiffuse': { type: 'texture', value: camera.fbo.textures[0] },
            'uGDepth': { type: 'texture', value: camera.fbo.textures[1] },
            'uGNormalWorld': { type: 'texture', value: camera.fbo.textures[2] },
            'uGShadow': { type: 'texture', value: camera.fbo.textures[3] },
            'uGPosWorld': { type: 'texture', value: camera.fbo.textures[4],
            'uWidth' : {type: '1i', value: window.screen.width},
            'uHeight' : {type: '1i', value: window.screen.height} }
        };
        for (let i = 0; i < camera.fbo.mipmap_fbo.maxLevel; i++) {
            uniforms['uGDepthMipmap[' + i + ']'] = {type : 'texture', value : camera.fbo.mipmap_fbo.mipmap[i]};
        }

        super(uniforms, [], vertexShader, fragmentShader);
    }
}

async function buildSSRMaterial(diffuseMap, specularMap, light, camera,  vertexPath, fragmentPath) {
    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new SSRMaterial(diffuseMap, specularMap, light, camera, vertexShader, fragmentShader);
}