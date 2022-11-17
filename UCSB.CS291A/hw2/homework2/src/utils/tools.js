function getRotationPrecomputeL(precompute_L, rotationMatrix){
	let flatten = getMat3ValueFromRGB(precompute_L);
	let result = [];
	
	let rot_matrix_math = mat4Matrix2mathMatrix(rotationMatrix);
	rot_matrix_math = math.inv(rot_matrix_math);
	
	let m3x3 = computeSquareMatrix_3by3(rot_matrix_math);
	// console.log(m3x3);
	let m5x5 = computeSquareMatrix_5by5(rot_matrix_math);
	// console.log(m5x5);
	for (let i = 0; i < 3; ++i) {
		result[i] = [];
		result[i].push(flatten[i][0]);
		result[i] = result[i].concat(math.multiply(m3x3, Array.from(flatten[i].slice(1, 4))).toArray());
		result[i] = result[i].concat(math.multiply(m5x5, Array.from(flatten[i].slice(4, 9))).toArray());
	}
	return result;
}

function computeSquareMatrix_3by3(rotationMatrix){

	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [0, 1, 0, 0];

	let A = math.matrix([SHEval(n1[0], n1[1], n1[2], 3).slice(1, 4),
						 SHEval(n2[0], n2[1], n2[2], 3).slice(1, 4),
						 SHEval(n3[0], n3[1], n3[2], 3).slice(1, 4)]);

	let rot_n1 = math.multiply(rotationMatrix, n1).toArray();
	let rot_n2 = math.multiply(rotationMatrix, n2).toArray();
	let rot_n3 = math.multiply(rotationMatrix, n3).toArray();

	let S = math.matrix([SHEval(rot_n1[0], rot_n1[1], rot_n1[2], 3).slice(1, 4),
						 SHEval(rot_n2[0], rot_n2[1], rot_n2[2], 3).slice(1, 4),
						 SHEval(rot_n3[0], rot_n3[1], rot_n3[2], 3).slice(1, 4)]);
	// A^(-1) * S here, because I use row-major matrices rather than col-major
	return math.multiply(math.inv(A), S);
}

function computeSquareMatrix_5by5(rotationMatrix){
	
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [k, k, 0, 0]; 
	let n4 = [k, 0, k, 0]; let n5 = [0, k, k, 0];

	let A = math.matrix([SHEval(n1[0], n1[1], n1[2], 3).slice(4, 9),
						 SHEval(n2[0], n2[1], n2[2], 3).slice(4, 9),
						 SHEval(n3[0], n3[1], n3[2], 3).slice(4, 9),
						 SHEval(n4[0], n4[1], n4[2], 3).slice(4, 9),
						 SHEval(n5[0], n5[1], n5[2], 3).slice(4, 9)]);

	let rot_n1 = math.multiply(rotationMatrix, n1).toArray();
	let rot_n2 = math.multiply(rotationMatrix, n2).toArray();
	let rot_n3 = math.multiply(rotationMatrix, n3).toArray();
	let rot_n4 = math.multiply(rotationMatrix, n4).toArray();
	let rot_n5 = math.multiply(rotationMatrix, n5).toArray();

	let S = math.matrix([SHEval(rot_n1[0], rot_n1[1], rot_n1[2], 3).slice(4, 9),
						 SHEval(rot_n2[0], rot_n2[1], rot_n2[2], 3).slice(4, 9),
						 SHEval(rot_n3[0], rot_n3[1], rot_n3[2], 3).slice(4, 9),
						 SHEval(rot_n4[0], rot_n4[1], rot_n4[2], 3).slice(4, 9),
						 SHEval(rot_n5[0], rot_n5[1], rot_n5[2], 3).slice(4, 9)]);
	
	// A^(-1) * S here, because I use row-major matrices rather than col-major
	return math.multiply(math.inv(A), S);
}

function mat4Matrix2mathMatrix(rotationMatrix){

	let mathMatrix = [];
	for(let i = 0; i < 4; i++){
		let r = [];
		for(let j = 0; j < 4; j++){
			r.push(rotationMatrix[i*4+j]);
		}
		mathMatrix.push(r);
	}
	return math.transpose(math.matrix(mathMatrix))

}

function getMat3ValueFromRGB(precomputeL){

    let colorMat3 = [];
    for(var i = 0; i<3; i++){
        colorMat3[i] = mat3.fromValues( precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
										precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
										precomputeL[6][i], precomputeL[7][i], precomputeL[8][i] ); 
	}
    return colorMat3;
}