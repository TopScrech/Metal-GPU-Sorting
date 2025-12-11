#include <metal_stdlib>
using namespace metal;

kernel void bitonicSort(device uint *data [[buffer(0)]],
                        constant uint &stage [[buffer(1)]],
                        constant uint &pass [[buffer(2)]],
                        uint gid [[thread_position_in_grid]]) {
    uint ixj = gid ^ pass;
    if (ixj > gid) {
        bool ascending = ((gid & stage) == 0);
        uint a = data[gid];
        uint b = data[ixj];
        bool shouldSwap = ascending ? (a > b) : (a < b);
        if (shouldSwap) {
            data[gid] = b;
            data[ixj] = a;
        }
    }
}
