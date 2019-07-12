
#include <stdio.h>
#include <string>
#include <cuda_runtime.h>
#include <thrust/device_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/for_each.h>
#include <thrust/count.h>
#include <numeric>
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

        size_t count_keys;
        size_t offsets_size;
        size_t strs_size;
        size_t count_strings;
        size_t values_size;
        
        fread(&count_keys,1,sizeof(size_t),fh);

        fread(&count_strings,1,sizeof(size_t),fh);

        fread(&values_size,1,sizeof(size_t),fh);

        int* values_ptr = (int*) malloc(values_size);
        fread(values_ptr,1,values_size,fh);

        fread(&offsets_size,1,sizeof(size_t),fh);

        int* offsets_ptr = (int*) malloc(offsets_size);
        fread(offsets_ptr,1,offsets_size,fh);

        fread(&strs_size,1,sizeof(size_t),fh);

        char* strs_ptr = (char*) malloc(strs_size);
        fread(strs_ptr,1,strs_size,fh);

        fclose(fh);

        cat = NVCategory::create_from_offsets(strs_ptr, count_keys, offsets_ptr);

        NVStrings* strs = cat->to_strings();

        printf("Received:\n");
        strs->print();

        printf("\nOriginal:\n");
        cat = cat->gather(values_ptr, count_strings, false);
        strs = cat->to_strings();
        strs->print();
        NVStrings::destroy(strs);
    }
    else
    {
        const char* hstrs[] = { "John", "Jane", "John", "Jane", "Bob" };
        NVStrings* strs = NVStrings::create_from_array(hstrs,5);
        cat = NVCategory::create_from_strings(*strs);
        printf("Original:\n");
        strs->print();

        strs = cat->get_keys();
        printf("\nSending keys:\n");
        strs->print();

        FILE* fh = fopen("/tmp/cputx.bin","wb");

        size_t count_keys = strs->size();
        fwrite((void*)&count_keys,1,sizeof(size_t),fh);

        size_t count_strings = cat->size();
        fwrite((void*)&count_strings,1,sizeof(size_t),fh);

        size_t offsets_size = (count_keys+1)*sizeof(int);
        int* offsets_ptr = (int*) malloc(offsets_size);

        int* lengths = (int*) malloc(count_keys*sizeof(int));
        strs->byte_count(lengths, false);

        size_t strs_size = std::accumulate(lengths, lengths+count_keys, 0);
        char* strs_ptr = (char*) malloc(strs_size);
        strs->create_offsets( strs_ptr, offsets_ptr, nullptr, false);

        size_t values_size = count_strings*sizeof(int);
        int* values_ptr = (int*) malloc(values_size);
        cat->get_values(values_ptr, false);

        fwrite((void*)&values_size,1,sizeof(size_t),fh);
        fwrite(values_ptr,1,values_size,fh);

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