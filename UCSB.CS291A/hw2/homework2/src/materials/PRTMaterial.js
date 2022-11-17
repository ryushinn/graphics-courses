class PRTMaterial extends Material {

    constructor(color, vertexShader, fragmentShader) {

        super({
            'albedo': { type: '3fv', value: color },
            // note that value is null here, pass values in WebGLRenderer.js to enable switch between cubemaps.
            'uPrecomputeRL' : {type: 'updatedInRealTime', value: null},
            'uPrecomputeGL' : {type: 'updatedInRealTime', value: null},
            'uPrecomputeBL' : {type: 'updatedInRealTime', value: null}
        }, [
            'aPrecomputeLT'
        ], vertexShader, fragmentShader, null);
    }
}

async function buildPRTMaterial(color, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(color, vertexShader, fragmentShader);

}