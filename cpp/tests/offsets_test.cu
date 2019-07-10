
#include <stdio.h>
#include <string>
#include <cuda_runtime.h>
#include <thrust/device_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/for_each.h>
#include <thrust/count.h>
#include "../include/NVStrings.h"
#include "../include/NVCategory.h"
#include "../include/ipc_transfer.h"


//
// cd ../build
// nvcc -g -G -w -std=c++11 --expt-extended-lambda -gencode arch=compute_70,code=sm_70 ../tests/offsets_test.cu -L. -lNVStrings -lNVCategory -o offsets_test --linker-options -rpath,.:
//

int category_test( std::string& mode )
{
    NVCategory* cat = 0;
    if( mode.compare("client")==0 )
    {
        FILE* fh = fopen("/tmp/cputx.bin","rb");

        size_t count;
        size_t offsets_size;
        size_t strs_size;
        
        fread(&count,1,sizeof(size_t),fh);

        fread(&offsets_size,1,sizeof(size_t),fh);

        int* offsets_ptr = (int*) malloc(offsets_size);
        fread(offsets_ptr,1,offsets_size,fh);

        fread(&strs_size,1,sizeof(size_t),fh);

        char* strs_ptr = (char*) malloc(strs_size);
        fread(strs_ptr,1,strs_size,fh);

        fclose(fh);

        cat = NVCategory::create_from_offsets(strs_ptr, count, offsets_ptr);

        NVStrings* strs = cat->get_keys();
        strs->print();
        NVStrings::destroy(strs);
    }
    else
    {
        const char* hstrs[] = { "John", "Jane", "John", "Jane", "Bob" };
        NVStrings* strs = NVStrings::create_from_array(hstrs,5);
        cat = NVCategory::create_from_strings(*strs);

        strs = cat->get_keys();
        strs->print();

        FILE* fh = fopen("/tmp/cputx.bin","wb");

        size_t count = strs->size();
        fwrite((void*)&count,1,sizeof(size_t),fh);

        size_t offsets_size = (strs->size()+1)*sizeof(int);
        int* offsets_ptr = (int*) malloc(offsets_size);

        size_t totalbytes = strs->total_bytes();
        char* strs_ptr = (char*) malloc(totalbytes);
        strs->create_offsets( strs_ptr, offsets_ptr, nullptr, false);

        size_t strs_size = offsets_ptr[strs->size()];

        fwrite((void*)&offsets_size,1,sizeof(size_t),fh);
        fwrite(offsets_ptr,1,offsets_size,fh);

        fwrite((void*)&strs_size,1,sizeof(size_t),fh);
        fwrite(strs_ptr,1,strs_size,fh);

        fclose(fh);
        NVStrings::destroy(strs);
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

    category_test(mode);
 }