
// Includes
#include <stdio.h>
#include <CL/cl.h>

//  _
// |_)  _  |  _  ._ ._  |  _. _|_  _
// |_) (_) | (/_ |  |_) | (_|  |_ (/_
//                  |

/* - - - -
IO
- - - - */
int read_from_binary(unsigned char **output, size_t *size, const char *name) {
  FILE *fp = fopen(name, "rb");
  if (!fp) {
    return -99;
  }

  fseek(fp, 0, SEEK_END);
  *size = ftell(fp);
  fseek(fp, 0, SEEK_SET);

  *output = (unsigned char *)malloc(*size * sizeof(unsigned char));
  if (!*output) {
    fclose(fp);
    return -99;
  }

  fread(*output, *size, 1, fp);
  fclose(fp);
  return 0;
}

/* - - - -
OpenCL Error
- - - - */

const char *getErrorString(cl_int error)
{
switch(error){
    // run-time and JIT compiler errors
    case 0: return "CL_SUCCESS";
    case -1: return "CL_DEVICE_NOT_FOUND";
    case -2: return "CL_DEVICE_NOT_AVAILABLE";
    case -3: return "CL_COMPILER_NOT_AVAILABLE";
    case -4: return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
    case -5: return "CL_OUT_OF_RESOURCES";
    case -6: return "CL_OUT_OF_HOST_MEMORY";
    case -7: return "CL_PROFILING_INFO_NOT_AVAILABLE";
    case -8: return "CL_MEM_COPY_OVERLAP";
    case -9: return "CL_IMAGE_FORMAT_MISMATCH";
    case -10: return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
    case -11: return "CL_BUILD_PROGRAM_FAILURE";
    case -12: return "CL_MAP_FAILURE";
    case -13: return "CL_MISALIGNED_SUB_BUFFER_OFFSET";
    case -14: return "CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST";
    case -15: return "CL_COMPILE_PROGRAM_FAILURE";
    case -16: return "CL_LINKER_NOT_AVAILABLE";
    case -17: return "CL_LINK_PROGRAM_FAILURE";
    case -18: return "CL_DEVICE_PARTITION_FAILED";
    case -19: return "CL_KERNEL_ARG_INFO_NOT_AVAILABLE";

    // compile-time errors
    case -30: return "CL_INVALID_VALUE";
    case -31: return "CL_INVALID_DEVICE_TYPE";
    case -32: return "CL_INVALID_PLATFORM";
    case -33: return "CL_INVALID_DEVICE";
    case -34: return "CL_INVALID_CONTEXT";
    case -35: return "CL_INVALID_QUEUE_PROPERTIES";
    case -36: return "CL_INVALID_COMMAND_QUEUE";
    case -37: return "CL_INVALID_HOST_PTR";
    case -38: return "CL_INVALID_MEM_OBJECT";
    case -39: return "CL_INVALID_IMAGE_FORMAT_DESCRIPTOR";
    case -40: return "CL_INVALID_IMAGE_SIZE";
    case -41: return "CL_INVALID_SAMPLER";
    case -42: return "CL_INVALID_BINARY";
    case -43: return "CL_INVALID_BUILD_OPTIONS";
    case -44: return "CL_INVALID_PROGRAM";
    case -45: return "CL_INVALID_PROGRAM_EXECUTABLE";
    case -46: return "CL_INVALID_KERNEL_NAME";
    case -47: return "CL_INVALID_KERNEL_DEFINITION";
    case -48: return "CL_INVALID_KERNEL";
    case -49: return "CL_INVALID_ARG_INDEX";
    case -50: return "CL_INVALID_ARG_VALUE";
    case -51: return "CL_INVALID_ARG_SIZE";
    case -52: return "CL_INVALID_KERNEL_ARGS";
    case -53: return "CL_INVALID_WORK_DIMENSION";
    case -54: return "CL_INVALID_WORK_GROUP_SIZE";
    case -55: return "CL_INVALID_WORK_ITEM_SIZE";
    case -56: return "CL_INVALID_GLOBAL_OFFSET";
    case -57: return "CL_INVALID_EVENT_WAIT_LIST";
    case -58: return "CL_INVALID_EVENT";
    case -59: return "CL_INVALID_OPERATION";
    case -60: return "CL_INVALID_GL_OBJECT";
    case -61: return "CL_INVALID_BUFFER_SIZE";
    case -62: return "CL_INVALID_MIP_LEVEL";
    case -63: return "CL_INVALID_GLOBAL_WORK_SIZE";
    case -64: return "CL_INVALID_PROPERTY";
    case -65: return "CL_INVALID_IMAGE_DESCRIPTOR";
    case -66: return "CL_INVALID_COMPILER_OPTIONS";
    case -67: return "CL_INVALID_LINKER_OPTIONS";
    case -68: return "CL_INVALID_DEVICE_PARTITION_COUNT";
    case -69:  return "CL_INVALID_PIPE_SIZE";
    case -70: return "CL_INVALID_DEVICE_QUEUE";

    default: return "Unknown OpenCL error";
 }
}

static void check_error(cl_int error, char const *name) {
    if (error != CL_SUCCESS) {
        fprintf(stderr, "Non-successful return code %d (%s) for %s.  Exiting.\n", error, getErrorString(error), name);
        exit(EXIT_FAILURE);
    }
}

static void exit_msg(char const *str){
        fprintf(stderr, "%s \n", str);
        exit(EXIT_FAILURE);
}

// =================================================================================================

int main(int argc, char* argv[]) {

   cl_int err;

   if (argc != 7)
        exit_msg("Not enought arguments.");

   //  _              _                      _
   // |_) |  _. _|_ _|_ _  ._ ._ _    ()    | \  _     o  _  _
   // |   | (_|  |_  | (_) |  | | |   (_X   |_/ (/_ \/ | (_ (/_
   //
    printf(">>> Initializing OpenCL Platform and Device...\n");

    cl_uint platform_idx = (cl_uint) atoi(argv[1]);
    cl_uint device_idx =  (cl_uint) atoi(argv[2]);

    char name[128];
    /* - - -
    Plateform
    - - - - */
    //A platform is a specific OpenCL implementation, for instance AMD, NVIDIA or Intel.
    // Intel may have a different OpenCL implementation for the CPU and GPU.

    // Discover the number of platforms:
    cl_uint platform_count;
    err = clGetPlatformIDs(0, NULL, &platform_count);
    check_error(err, "clGetPlatformIds");

    // Now ask OpenCL for the platform IDs:
    cl_platform_id* platforms = (cl_platform_id*)malloc(sizeof(cl_platform_id) * platform_count);
    err = clGetPlatformIDs(platform_count, platforms, NULL);
    check_error(err, "clGetPlatformIds");

    cl_platform_id platform = platforms[platform_idx];
    err = clGetPlatformInfo(platform, CL_PLATFORM_NAME, 128, name, NULL);
    check_error(err, "clGetPlatformInfo");

    printf("Platform #%d: %s\n", platform_idx, name);

    /* - - - -
    Device
    - - - - */
    // Device gather data
    cl_uint device_count;
    err = clGetDeviceIDs(platform,  CL_DEVICE_TYPE_GPU, 0, NULL, &device_count);
    check_error(err, "clGetdeviceIds");

    cl_device_id* devices = (cl_device_id*)malloc(sizeof(cl_device_id) * device_count);
    err = clGetDeviceIDs(platform,  CL_DEVICE_TYPE_ALL , device_count, devices, NULL);
    check_error(err, "clGetdeviceIds");

    cl_device_id device = devices[device_idx];
    err = clGetDeviceInfo(device, CL_DEVICE_NAME, 128, name, NULL);
    check_error(err, "clGetPlatformInfo");

    printf("-- Device #%d: %s\n", device_idx, name);

    //  _                               _
    // /   _  ._ _|_  _    _|_   ()    / \      _       _
    // \_ (_) | | |_ (/_ >< |_   (_X   \_X |_| (/_ |_| (/_
    //

    /* - - - -
    Context
    - - - - */
    // A context is a platform with a set of available devices for that platform.
    cl_context context = clCreateContext(0, device_count, devices, NULL, NULL, &err);
    check_error(err,"clCreateContext");

    /* - - - -
    Command queue
    - - - - */
    // The OpenCL functions that are submitted to a command-queue are enqueued in the order the calls are made but can be configured to execute in-order or out-of-order.
    const cl_queue_properties properties[] =  { CL_QUEUE_PROPERTIES, (CL_QUEUE_PROFILING_ENABLE), 0 };

    cl_command_queue queue = clCreateCommandQueueWithProperties(context, device, properties, &err);
    check_error(err,"clCreateCommandQueueWithProperties");

    //  _       _   _
    // |_)    _|_ _|_ _  ._
    // |_) |_| |   | (/_ |

    // Length of vectors
    size_t n =  {   (size_t) atoi(argv[5]) };
    size_t bytes = n*sizeof(float);

    float *h_a = (float*)malloc(bytes);
    cl_mem d_a = clCreateBuffer(context, CL_MEM_READ_WRITE, bytes, NULL, &err);
    check_error(err,"cclCreateBuffer A");

    float *h_b = (float*)malloc(bytes);
    cl_mem d_b = clCreateBuffer(context, CL_MEM_READ_WRITE, bytes, NULL, &err);
    check_error(err,"cclCreateBuffer B");

    // |/  _  ._ ._   _  |
    // |\ (/_ |  | | (/_ |
    //
    printf(">>> Kernel configuration...\n");

    // Readed from file
    unsigned char* program_file; size_t program_size;
    err = read_from_binary(&program_file, &program_size, argv[3]);
    check_error(err,"read_from_binary");
    
    // Create the program from binary
    cl_program program = clCreateProgramWithBinary(context, 1, &device, &program_size,
                              (const unsigned char **)&program_file,
                              NULL, &err);
    check_error(err,"clCreateProgramWithBinary");

    //Build / Compile the program executable
    err = clBuildProgram(program, device_count, devices, "", NULL, NULL);
    if (err != CL_SUCCESS)
    {
        printf("Error: Failed to build program executable!\n");

        size_t logSize;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &logSize);

        // there's no information in the reference whether the string is 0 terminated or not.
        char* messages = (char*)malloc((1+logSize)*sizeof(char));
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, logSize, messages, NULL);
        messages[logSize] = '\0';

        printf("%s", messages);
        free(messages);
        return EXIT_FAILURE;
    }

   /* - - - -
    Create
    - - - - */
    cl_kernel kernel = clCreateKernel(program, argv[4], &err);
    check_error(err,"clCreateKernel");

    err   = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_a);
    err  |= clSetKernelArg(kernel, 1, sizeof(cl_mem), &d_b);
    check_error(err,"clSetKernelArg");

    /* - - - -
    ND range
    - - - - */
    printf(">>> NDrange configuration...\n");

    const size_t work_dim = 1;
    
    // Describe the number of global work-items in work_dim dimensions that will execute the kernel function
    const size_t global[work_dim] = {   (size_t) n };
    const size_t local[work_dim] = {   (size_t) atoi(argv[6]) };
    printf("Global work size: %zu \n", global[0]);
    printf("Local work size: %zu \n", local[0]);

    /* - - - -
    Execute
    - - - - */
    printf(">>> Kernel Execution...\n");
    cl_event events[1];

    err  = clEnqueueNDRangeKernel(queue, kernel, work_dim, NULL, global, local, 0, NULL, &events[0]);
    check_error(err,"clEnqueueNDRangeKernel");

    /* - - -
    Sync & check
    - - - */
    clWaitForEvents(1,events);


    // Read the results from the device
    err = clEnqueueReadBuffer(queue, d_a, CL_TRUE, 0, bytes, h_a, 0, NULL, NULL );
    check_error(err,"clEnqueueReadBuffer");

    //  _         _
    // |_) ._ _ _|_ o | o ._   _
    // |   | (_) |  | | | | | (_|
    //                         _|
    cl_ulong time_start, time_end;

    err = clGetEventProfilingInfo(events[0], CL_PROFILING_COMMAND_START, sizeof(time_start), &time_start, NULL);
    err |= clGetEventProfilingInfo(events[0], CL_PROFILING_COMMAND_END, sizeof(time_end), &time_end, NULL);
    check_error(err, "clGetEventProfilingInfo");

    cl_ulong nanoSeconds = time_end-time_start;
    printf("OpenCl Execution time is: %lu nanoSeconds \n",nanoSeconds);

    float sum = 0;
    for(int i=0; i<n; i++)
        sum += h_a[i];
     printf("final result: %f, should have been %lu\n", sum, n);

    //  _
    // /  |  _   _. ._  o ._   _
    // \_ | (/_ (_| | | | | | (_|
    //                         _|
    clReleaseCommandQueue(queue);
    clReleaseContext(context);
    clReleaseProgram(program);
    clReleaseKernel(kernel);

    // Exit
    return 0;
}
