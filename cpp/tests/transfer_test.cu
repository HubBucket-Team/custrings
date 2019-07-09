
#include <stdio.h>
#include <string>
#include <cuda_runtime.h>
#include <rmm/rmm.h>
#include <thrust/device_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/for_each.h>
#include <thrust/count.h>
#include "../include/NVStrings.h"
#include "../include/NVCategory.h"
#include "../include/ipc_transfer.h"


//
// cd ../build
// nvcc -w -std=c++11 --expt-extended-lambda -gencode arch=compute_70,code=sm_70 ../tests/transfer_test.cu -I../../thirdparty/rmm/include -lrmm -L. -lNVStrings -lNVCategory -o transfer_test --linker-options -rpath,.:
// nvcc -g -G -w -std=c++11 --expt-extended-lambda -gencode arch=compute_70,code=sm_70 ../tests/transfer_test.cu -I../../thirdparty/rmm/include -lrmm -L. -lNVStrings -lNVCategory -o transfer_test --linker-options -rpath,.:
//

void print_transfer(nvcategory_transfer& ptr)
{
    printf("strs_size %d: ", ptr.strs_size);
    printf("vals_size %d: ", ptr.vals_size);
    printf("\n");
}

int category_test( std::string& mode )
{
    cudaError_t cuda_error;

    NVCategory* cat = 0;
    if( mode.compare("client")==0 )
    {
        nvcategory_transfer ptr;
        FILE* fh = fopen("/tmp/transfertx.bin","rb");

        fread(&ptr.base_address,1,sizeof(char*),fh);
        printf("base_address: %p\n", ptr.base_address);

        fread(&ptr.keys,1,sizeof(unsigned int),fh);
        printf("keys: %d\n", ptr.keys);

        fread(&ptr.strs_size,1,sizeof(size_t),fh);
        printf("strs_size: %d\n", ptr.strs_size);

        void* hstrs = (void*) malloc(ptr.strs_size);
        fread(hstrs,1,ptr.strs_size,fh);
        RMM_ALLOC(&ptr.strs, ptr.strs_size, 0);
        cuda_error = cudaMemcpy(ptr.strs,hstrs,ptr.strs_size,cudaMemcpyHostToDevice);
        if(cuda_error != cudaSuccess) printf("Failed!\n");

        fread(&ptr.size,1,sizeof(size_t),fh);
        printf("size: %d\n", ptr.size);

        void* hmem = (void*) malloc(ptr.size);
        fread(hmem,1,ptr.size,fh);
        RMM_ALLOC(&ptr.mem, ptr.size, 0);
        cuda_error = cudaMemcpy(ptr.mem,hmem,ptr.size,cudaMemcpyHostToDevice);
        if(cuda_error != cudaSuccess) printf("Failed!\n");

        fread(&ptr.count,1,sizeof(unsigned int),fh);
        printf("count: %d\n", ptr.count);

        fread(&ptr.vals_size,1,sizeof(size_t),fh);
        printf("vals_size: %d\n", ptr.vals_size);

        void* hvals = (void*) malloc(ptr.vals_size);
        fread(hvals,1,ptr.vals_size,fh);
        RMM_ALLOC(&ptr.vals, ptr.vals_size, 0);
        cuda_error = cudaMemcpy(ptr.vals,hvals,ptr.vals_size,cudaMemcpyHostToDevice);
        if(cuda_error != cudaSuccess) printf("Failed!\n");

        fclose(fh);
        
        cat = NVCategory::create_from_transfer(ptr);
        printf("%p %p:%u %p:%u %p:%ld\n", ptr.base_address, ptr.strs, ptr.keys, ptr.vals, ptr.count, ptr.mem, ptr.size);
        NVStrings* strs = cat->get_keys();
        strs->print();
        NVStrings::destroy(strs);
    }
    else
    {
        const char* hstrings[] = { "John", "Jane", "John", "Jane", "Bob" };
        NVStrings* strs = NVStrings::create_from_array(hstrings,5);
        cat = NVCategory::create_from_strings(*strs);
        nvcategory_transfer ptr;
        cat->create_transfer(ptr);
        print_transfer(ptr);
        printf("%p %p:%u %p:%u %p:%ld\n", ptr.base_address, ptr.strs, ptr.keys, ptr.vals, ptr.count, ptr.mem, ptr.size);
        NVStrings::destroy(strs);
        strs = cat->get_keys();
        strs->print();
        NVStrings::destroy(strs);

        FILE* fh = fopen("/tmp/transfertx.bin","wb");

        printf("base_address: %p\n", ptr.base_address);
        fwrite((void*)&ptr.base_address,1,sizeof(char*),fh);
        fwrite((void*)&ptr.keys,1,sizeof(unsigned int),fh);

        fwrite((void*)&ptr.strs_size,1,sizeof(size_t),fh);

        void* hstrs = (void*) malloc(ptr.strs_size);
        cuda_error = cudaMemcpy(hstrs,ptr.strs,ptr.strs_size,cudaMemcpyDeviceToHost);
        if(cuda_error != cudaSuccess) printf("Failed!\n");
        fwrite(&hstrs,1,ptr.strs_size,fh);

        fwrite((void*)&ptr.size,1,sizeof(size_t),fh);

        void* hmem = (void*) malloc(ptr.size);
        cuda_error = cudaMemcpy(hmem,ptr.mem,ptr.size,cudaMemcpyDeviceToHost);
        if(cuda_error != cudaSuccess) printf("Failed!\n");
        fwrite(&hmem,1,ptr.size,fh);

        fwrite((void*)&ptr.count,1,sizeof(unsigned int),fh);
        fwrite((void*)&ptr.vals_size,1,sizeof(size_t),fh);

        void* hvals = (void*) malloc(ptr.vals_size);
        cuda_error = cudaMemcpy(hvals,ptr.vals,ptr.vals_size,cudaMemcpyDeviceToHost);
        if(cuda_error != cudaSuccess) printf("Failed!\n");
        fwrite(&hvals,1,ptr.vals_size,fh);

        fclose(fh);
        printf("Server ready. Press enter to terminate.\n");
        std::cin.ignore();
    }

    NVCategory::destroy(cat);
    return 0;
}

int main( int argc, const char** argv )
{
    if( argc < 2 )
    {
        printf("require parameter: 'server' or values for pointers\n");
        return 0;
    }
    std::string mode = argv[1];
    //strings_test(mode);
    category_test(mode);
 }