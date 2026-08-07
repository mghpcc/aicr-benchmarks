// Does this GPU's PCIe link actually run full-duplex?
//
// The AICR inter-node defect is that GPU-memory RDMA reads alone hit 47.5 GB/s and writes
// alone hit 47.5 GB/s, but run together they total only 54.5 GB/s instead of ~95. That is
// exactly the "shared TX/RX budget" the paper postulated. This test asks whether the same
// thing happens with plain cudaMemcpyAsync over PCIe -- no InfiniBand, no RDMA, no NIC,
// no peer-to-peer, one GPU, no root needed.
//
//   H2D alone        -> host-to-device bandwidth
//   D2H alone        -> device-to-host bandwidth
//   H2D + D2H together, on separate streams/copy engines
//
// If concurrent ~= half of each alone, the GPU's PCIe endpoint is not doing full duplex on
// this platform, and the defect is NOT specific to GPUDirect/RDMA -- it is the GPU<->root
// complex path (relaxed ordering, platform/BIOS), which would also fully explain the NCCL
// numbers.
//
// If concurrent ~= full rate in both directions (~2x total), the endpoint is healthy and the
// defect lives specifically in the P2P/GDRDMA path (PCIe switch, ACS, peermem path).
//
// Build: nvcc -O2 -o pcie_duplex pcie_duplex.cu

#include <cstdio>
#include <cuda_runtime.h>

#define CK(x) do { cudaError_t e = (x); if (e != cudaSuccess) {                     \
    printf("CUDA ERROR %s line %d: %s\n", #x, __LINE__, cudaGetErrorString(e));     \
    return 1; } } while (0)

static double gbps(size_t bytes, float ms) { return (double)bytes / (ms * 1.0e6); }

int main(int argc, char **argv) {
    size_t chunk = 256ull << 20;   // 256 MiB per copy
    int iters = 16;
    if (argc > 1) chunk = (size_t)atoll(argv[1]) << 20;
    if (argc > 2) iters = atoi(argv[2]);

    int dev = 0;
    CK(cudaSetDevice(dev));
    cudaDeviceProp p;
    CK(cudaGetDeviceProperties(&p, dev));

    int genCur = 0, widCur = 0;
    cudaDeviceGetAttribute(&genCur, cudaDevAttrPciBusId, dev);   // placeholder, printed below
    printf("GPU: %s  (asyncEngineCount=%d)\n", p.name, p.asyncEngineCount);
    char busid[64];
    CK(cudaDeviceGetPCIBusId(busid, sizeof(busid), dev));
    printf("PCI bus id: %s\n", busid);
    printf("chunk = %zu MiB, iters = %d, total per direction = %zu MiB\n\n",
           chunk >> 20, iters, (chunk * iters) >> 20);
    (void)genCur; (void)widCur;

    void *hSrc = nullptr, *hDst = nullptr, *dDst = nullptr, *dSrc = nullptr;
    CK(cudaHostAlloc(&hSrc, chunk, cudaHostAllocDefault));   // pinned: required for real DMA
    CK(cudaHostAlloc(&hDst, chunk, cudaHostAllocDefault));
    CK(cudaMalloc(&dDst, chunk));
    CK(cudaMalloc(&dSrc, chunk));
    memset(hSrc, 1, chunk);

    cudaStream_t sUp, sDown;
    CK(cudaStreamCreate(&sUp));     // H2D
    CK(cudaStreamCreate(&sDown));   // D2H

    cudaEvent_t t0, t1;
    CK(cudaEventCreate(&t0));
    CK(cudaEventCreate(&t1));
    float ms = 0.f;
    size_t total = chunk * (size_t)iters;

    // ---- warmup (first touch of pinned mappings is slow) ----
    for (int i = 0; i < 3; i++) {
        CK(cudaMemcpyAsync(dDst, hSrc, chunk, cudaMemcpyHostToDevice, sUp));
        CK(cudaMemcpyAsync(hDst, dSrc, chunk, cudaMemcpyDeviceToHost, sDown));
    }
    CK(cudaDeviceSynchronize());

    // ---- 1. H2D alone ----
    CK(cudaEventRecord(t0, sUp));
    for (int i = 0; i < iters; i++)
        CK(cudaMemcpyAsync(dDst, hSrc, chunk, cudaMemcpyHostToDevice, sUp));
    CK(cudaEventRecord(t1, sUp));
    CK(cudaEventSynchronize(t1));
    CK(cudaEventElapsedTime(&ms, t0, t1));
    double h2d = gbps(total, ms);
    printf("1. H2D alone            : %7.2f GB/s\n", h2d);

    // ---- 2. D2H alone ----
    CK(cudaEventRecord(t0, sDown));
    for (int i = 0; i < iters; i++)
        CK(cudaMemcpyAsync(hDst, dSrc, chunk, cudaMemcpyDeviceToHost, sDown));
    CK(cudaEventRecord(t1, sDown));
    CK(cudaEventSynchronize(t1));
    CK(cudaEventElapsedTime(&ms, t0, t1));
    double d2h = gbps(total, ms);
    printf("2. D2H alone            : %7.2f GB/s\n", d2h);

    // ---- 3. both at once, one per stream ----
    // Wall-clock across both streams: queue everything, then sync the device.
    cudaEvent_t w0, w1;
    CK(cudaEventCreate(&w0));
    CK(cudaEventCreate(&w1));
    CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(w0, 0));                 // null stream: orders against both
    for (int i = 0; i < iters; i++) {
        CK(cudaMemcpyAsync(dDst, hSrc, chunk, cudaMemcpyHostToDevice, sUp));
        CK(cudaMemcpyAsync(hDst, dSrc, chunk, cudaMemcpyDeviceToHost, sDown));
    }
    CK(cudaStreamSynchronize(sUp));
    CK(cudaStreamSynchronize(sDown));
    CK(cudaEventRecord(w1, 0));
    CK(cudaEventSynchronize(w1));
    CK(cudaEventElapsedTime(&ms, w0, w1));
    double each = gbps(total, ms);
    printf("3. H2D + D2H concurrent : %7.2f GB/s each way, %7.2f GB/s total\n",
           each, 2.0 * each);

    printf("\n--- verdict ---\n");
    double best_alone = (h2d > d2h ? h2d : d2h);
    double ratio = each / best_alone;
    printf("concurrent per-direction / best single-direction = %.2f\n", ratio);
    if (ratio < 0.70)
        printf("NOT FULL DUPLEX: each direction loses %.0f%% when both run at once.\n"
               "   -> matches the RDMA signature; the GPU PCIe path, not GDRDMA, is the problem.\n",
               100.0 * (1.0 - ratio));
    else
        printf("FULL DUPLEX: both directions hold up concurrently.\n"
               "   -> the GPU PCIe endpoint is healthy; the defect is specific to the\n"
               "      P2P/GDRDMA path (switch, ACS, peermem), not the GPU link itself.\n");

    cudaFreeHost(hSrc); cudaFreeHost(hDst); cudaFree(dDst); cudaFree(dSrc);
    return 0;
}
