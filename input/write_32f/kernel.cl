__kernel void mcopy(__global float *a) {
    const int i = get_global_id(0);
    a[i] =  1; 
};
