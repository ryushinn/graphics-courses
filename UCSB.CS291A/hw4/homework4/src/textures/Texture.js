class Texture {
    constructor() {}
    CreateImageTexture(gl, image) {
        this.texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, this.texture);

        // Because images have to be download over the internet
        // they might take a moment until they are ready.
        // Until then put a single pixel in the texture so we can
        // use it immediately. When the image has finished downloading
        // we'll update the texture with the contents of the image.
        const level = 0;
        const internalFormat = gl.RGBA;
        const width = 1;
        const height = 1;
        const border = 0;
        const srcFormat = gl.RGBA;
        const srcType = gl.UNSIGNED_BYTE;
        const pixel = new Uint8Array([0, 0, 255, 255]); // opaque blue
        gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
            width, height, border, srcFormat, srcType,
            pixel);

        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
        gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
            srcFormat, srcType, image);

        gl.bindTexture(gl.TEXTURE_2D, null);

        let wrap = gl.CLAMP_TO_EDGE;
        let filter = gl.LINEAR;
        this.setTextureParameter(gl, wrap, wrap, filter, filter);

        this.CreateMipmap(gl, image.width, image.height);
    }

    CreateConstantTexture(gl, buffer) {
        this.texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, this.texture);

        // Because images have to be download over the internet
        // they might take a moment until they are ready.
        // Until then put a single pixel in the texture so we can
        // use it immediately. When the image has finished downloading
        // we'll update the texture with the contents of the image.
        const level = 0;
        const internalFormat = gl.RGB;
        const width = 1;
        const height = 1;
        const border = 0;
        const srcFormat = gl.RGB;
        const srcType = gl.UNSIGNED_BYTE;
        const pixel = new Uint8Array([buffer[0] * 255, buffer[1] * 255, buffer[2] * 255, 255]); // opaque blue
        gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
            width, height, border, srcFormat, srcType,
            pixel);

        gl.bindTexture(gl.TEXTURE_2D, null);

        this.setTextureParameter(gl, gl.CLAMP_TO_EDGE, gl.CLAMP_TO_EDGE, gl.LINEAR, gl.LINEAR);

        this.CreateMipmap(gl, width, height);
    }

    CreateMipmap(gl, width, height) {
        gl.bindTexture(gl.TEXTURE_2D, this.texture);

        // WebGL1 has different requirements for power of 2 images
        // vs non power of 2 images so check if the image is a
        // power of 2 in both dimensions.
        if (isPowerOf2(width) && isPowerOf2(height)) {
            // Yes, it's a power of 2. Generate mips.
            gl.generateMipmap(gl.TEXTURE_2D);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        } 
        gl.bindTexture(gl.TEXTURE_2D, null);
    }

    setTextureParameter(gl, wrap_s, wrap_t, min_filter, mag_filter) {
        gl.bindTexture(gl.TEXTURE_2D, this.texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_s);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_t);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min_filter);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, mag_filter);

        gl.bindTexture(gl.TEXTURE_2D, null);
    }
}

function isPowerOf2(value) {
    return (value & (value - 1)) == 0;
}