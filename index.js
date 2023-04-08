function sliderUpdate(name) {
    var slider = document.getElementById(name);
    var slider_val = document.getElementById(name + "_val");
    slider_val.innerHTML = name + ": " + slider.value;
    slider.oninput = function () {
        slider_val.innerHTML = name + ": " + this.value;
    }
}

async function loadImage() {
    const fileInput = document.getElementById("fileInput");
    const canvas = document.getElementById("canvas");
    const ctx = canvas.getContext("2d");
    const file = fileInput.files[0];
    const reader = new FileReader();
    reader.onload = function (e) {
        const img = new Image();
        img.onload = function () {
            canvas.width = 512;
            canvas.height = (canvas.width / img.width) * img.height;
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        };
        img.src = e.target.result;
        console.log("loaded image \"" + img.src + "\"");

        main(img);
    };
    reader.readAsDataURL(file);
}

function loadTexture(gl, img) {
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);

    const level = 0;
    const internalFormat = gl.RGBA;
    const width = 1;
    const height = 1;
    const border = 0;
    const srcFormat = gl.RGBA;
    const srcType = gl.UNSIGNED_BYTE;

    gl.texImage2D(
        gl.TEXTURE_2D,
        level,
        internalFormat,
        srcFormat,
        srcType,
        img
    );

    if (isPowerOf2(img.width) && isPowerOf2(img.height)) {
        gl.generateMipmap(gl.TEXTURE_2D);
    }
    else {
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    }

    return texture;
}

function isPowerOf2(value) {
    return (value & value - 1) == 0;
}

function initTextureBuffer(gl) {
    const textureCoordBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, textureCoordBuffer);

    const textureCoordinates = [
        0.0, 0.0,
        0.0, 1.0,
        1.0, 1.0,
        1.0, 1.0,
        1, 0,
        0, 0
    ];

    gl.bufferData(
        gl.ARRAY_BUFFER,
        new Float32Array(textureCoordinates),
        gl.STATIC_DRAW
    );

    return textureCoordBuffer;
}

function setTextureAttribute(gl, texture_coord_buffer, program_info) {
    const num = 2; // each coord has 2 vals
    const type = gl.FLOAT; // the data is 32 bit buffer
    const normalize = false; // don't normalize
    const stride = 0; // how many bytes to get from one set to the next
    const offset = 0; // how many bytes inside the buffer to start from
    gl.bindBuffer(gl.ARRAY_BUFFER, texture_coord_buffer);
    gl.vertexAttribPointer(
        program_info.attribute_locations.texture_coord,
        num,
        type,
        normalize,
        stride,
        offset
    );
    gl.enableVertexAttribArray(program_info.attribute_locations.texture_coord);
}

async function main(img) {
    var vert;
    var frag;

    const response1 = await fetch('vertexDOGShader.glsl');
    vert = await response1.text();

    const response2 = await fetch('fragmentDOGShader.glsl');
    frag = await response2.text();

    console.log("vert: " + vert);
    console.log("frag: " + frag);

    var canvas = document.getElementById("webgl-canvas");
    canvas.height = img.height;
    canvas.width = img.width;

    var gl = document.getElementById("webgl-canvas").getContext('webgl');

    var vertexShader = createShader(gl, gl.VERTEX_SHADER, vert);
    var fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, frag);
    var program = createProgram(gl, vertexShader, fragmentShader);

    const program_info = {
        program: program,
        attribute_locations: {
            vertex_position: gl.getAttribLocation(program, "a_position"),
            texture_coord: gl.getAttribLocation(program, "aTextureCoord")
        },
        uniformLocations: {
            u_sampler: gl.getUniformLocation(program, "uSampler")
        }
    };

    const texture = loadTexture(gl, img);
    var texture_coord_buffer = initTextureBuffer(gl);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

    var positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);

    var positions = [
        -1, -1,
        -1, 1,
        1, 1,
        1, 1,
        1, -1,
        -1, -1,
    ];

    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);

    var fps_counter = document.getElementById("fps_counter");
    var elapsed_time = 0;

    function render(time) {
        gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
        gl.clearColor(0, 0, 0, 0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.useProgram(program);
        gl.enableVertexAttribArray(program_info.attribute_locations.vertex_position);
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        // // Tell the attribute how to get data out of positionBuffer (ARRAY_BUFFER)
        var size = 2;          // 2 components per iteration
        var type = gl.FLOAT;   // the data is 32bit floats
        var normalize = false; // don't normalize the data
        var stride = 0;        // 0 = move forward size * sizeof(type) each iteration to get the next position
        var offset = 0;        // start at the beginning of the buffer
        gl.vertexAttribPointer(
            program_info.attribute_locations.vertex_position, size, type, normalize, stride, offset)

        setTextureAttribute(gl, texture_coord_buffer, program_info);

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.uniform1i(program_info.uniformLocations.u_sampler, 0);

        var primitiveType = gl.TRIANGLES;
        var offset = 0;
        var count = 6;
        gl.drawArrays(primitiveType, offset, count);

        var fps = 1000 / (performance.now() - time);
        elapsed_time += performance.now() - time;
        if (elapsed_time > 200) {
            fps_counter.innerHTML = "FPS: " + Math.round(fps);
            elapsed_time = 0;
        }
    }

    requestAnimationFrame(render);
}

// main();

function createProgram(gl, vs, fs) {
    const p = gl.createProgram();
    gl.attachShader(p, vs);
    gl.attachShader(p, fs);
    gl.linkProgram(p);
    return p;
}

function createShader(gl, type, src) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error('An error occurred compiling the shaders: ' + gl.getShaderInfoLog(s));
        text = document.getElementById("log")
        text.innerHTML += gl.getShaderInfoLog(s) + "\n\n";
        gl.deleteShader(s);
        return null;
    }
    else {
        console.log("successfully loaded shader " + type);
        text = document.getElementById("log")
        text.innerHTML += "successfully loaded shader " + type + "\n\n";
    }
    return s;
}