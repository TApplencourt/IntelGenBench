__attribute__((reqd_work_group_size(16,1,1)))
__kernel void mcopy(__global float *a, __global float *b) {
    const int i = get_global_id(0);
    a[i] =  b[i]; 
};
