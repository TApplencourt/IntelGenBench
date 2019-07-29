__attribute__((reqd_work_group_size(8,1,1)))
__kernel void mcopy(__global float *a) {
    const int i = get_global_id(0);
    a[i] =  1; 
};
