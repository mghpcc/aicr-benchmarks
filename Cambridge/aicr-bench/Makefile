.PHONY: \
	help \
	help-benchmarks \
	require-settings \
	doctor \
	doctor-python \
	doctor-python-slurm \
	rebuild-runtime \
	install-containers \
	install-gpu-smoke-suite \
	refresh-python-locks \
	setup \
	setup-python-local \
	verify \
	verify-topology \
	verify-gds \
	render-gds-ascii \
	verify-nccl-suite \
	render-nccl-suite \
	archive-verify \
	archive-verification-campaign \
	archive-verification-campaign-all \
	render \
	render-report-index \
	render-benchmark-candidates \
	validate-reports \
	docs-link-check \
	docs-test \
	docs-test-plan \
	docs-test-gpu-topology \
	docs-test-plan-gpu-topology \
	docs-test-gds \
	docs-test-plan-gds \
	docs-test-nccl \
	docs-test-plan-nccl \
	docs-test-dataloader \
	docs-test-plan-dataloader \
	docs-test-ddp \
	docs-test-plan-ddp \
	docs-test-hpl-mxp \
	docs-test-plan-hpl-mxp \
	docs-test-elbencho \
	docs-test-plan-elbencho \
	check-artifact-policy \
	validate-benchmark-campaign-registry \
	system-verify \
	daily-verify \
	benchmark-readiness-nccl \
	benchmark-elbencho \
	benchmark-dataloader \
	benchmark-ddp-resnet50 \
	benchmark-ddp-launcher-comparison \
	benchmark-hpl-mxp \
	benchmark-hpl-mxp-smoke \
	install-elbencho \
	benchmark-dry-run-suite \
	render-dataloader \
	render-dataloader-b200 \
	render-ddp-resnet50 \
	render-ddp-resnet50-ascii \
	render-hpl-mxp \
	render-benchmark-campaign \
	render-ddp-b200 \
	archive-benchmark-study-b200

.NOTPARALLEL: verify system-verify daily-verify

CLUSTER ?= b200
DATE ?= today
APPLY ?= 0
PROFILE ?= small
REPEAT_COUNT ?= 1
REPEAT_AGGREGATION ?= standard
GPU_PREFLIGHT_FILTER ?= 0
INSTALL_SMOKE_RTX_NODES ?=
INSTALL_SMOKE_B200_NODES ?=
INSTALL_SMOKE_AUDIT_ROOT ?=
INSTALL_SMOKE_RESUME_FROM_AUDIT_ROOT ?=
INSTALL_SMOKE_SKIP_TOPOLOGY ?= 0
INSTALL_SMOKE_SKIP_GDS ?= 0
INSTALL_SMOKE_SKIP_NCCL ?= 0
INSTALL_SMOKE_SKIP_RDMA ?= 0
INSTALL_SMOKE_SKIP_HPL_MXP ?= 0
INSTALL_SMOKE_SKIP_DATALOADER ?= 0
INSTALL_SMOKE_SKIP_DDP ?= 0
INSTALL_SMOKE_HPL_MXP_B200_NODE ?=
INSTALL_SMOKE_HPL_MXP_RTX_NODE ?=
INSTALL_SMOKE_HPL_MXP_APPLY_RTX ?= 0
INSTALL_SMOKE_HPL_MXP_TIME ?= 00:10:00
INSTALL_SMOKE_HPL_MXP_PRESET ?= smoke
INSTALL_SMOKE_HPL_MXP_SLOPPY_TYPE ?= FP16
INSTALL_SMOKE_DATALOADER_TIME ?= 00:10:00
INSTALL_SMOKE_DDP_TIME ?= 00:10:00
INSTALL_SMOKE_INCLUDE_ELBENCHO ?= 0
INSTALL_SMOKE_ELBENCHO_B200_NODE ?=
INSTALL_SMOKE_ELBENCHO_RTX_NODE ?=
INSTALL_SMOKE_ELBENCHO_TARGET_ROOT ?=
INSTALL_SMOKE_ELBENCHO_TIME ?= 00:10:00
INSTALL_SMOKE_ONLY_ELBENCHO ?= 0
INSTALL_SMOKE_SKIP_RTX ?= 0
INSTALL_SMOKE_SKIP_B200 ?= 0
INSTALL_SMOKE_SKIP_LOCAL_CHECKS ?= 0
INSTALL_SMOKE_SKIP_DRY_RUNS ?= 0
INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH ?= 0
INSTALL_SMOKE_NO_RENDER ?= 0
INSTALL_SMOKE_RENDER_ONLY ?= 0
# SUBMIT_STAGGER_SECONDS remains a compatibility override for both GDS and NCCL suite.
SUBMIT_STAGGER_SECONDS ?=
GDS_SUBMIT_STAGGER_SECONDS ?= $(if $(strip $(SUBMIT_STAGGER_SECONDS)),$(SUBMIT_STAGGER_SECONDS),30)
NCCL_SUBMIT_STAGGER_SECONDS ?= $(if $(strip $(SUBMIT_STAGGER_SECONDS)),$(SUBMIT_STAGGER_SECONDS),5)
ROUND_STAGGER_SECONDS ?= 60
NCCL_SCALE_STAGGER_SECONDS ?= 0
NCCL_SCOPE ?= scale
NCCL_SUITE_CLASS ?=
NCCL_SUITE_OPS ?=
NCCL_NODES_PER_JOB ?=
NCCL_SCALES ?=
WORKLOAD ?= small-block
NODES ?= 1
GPU_COUNT ?= 1
MODE ?=
LAUNCHER ?= torchrun
NODE_REPORT_DATE ?= $(DATE)
FROM_NODE_REPORT ?= 0
NODELIST ?=
DATALOADER_NODES ?= $(NODES)
DATALOADER_BATCH_SIZES ?= 256
DATALOADER_INPUT_BACKENDS ?= pytorch-cpu-dataloader
DATALOADER_NUM_WORKERS ?= 4,8,16,24,32
DATALOADER_PREFETCH_FACTORS ?= 4
DATALOADER_DALI_NUM_THREADS ?= 0
DATALOADER_DALI_PREFETCH_QUEUE_DEPTHS ?= 2
DATALOADER_DALI_DECODE_MODES ?= random-crop
DATALOADER_DALI_HW_DECODER_LOADS ?= 0.65
DATALOADER_PIN_MEMORY ?= 1
DATALOADER_PERSISTENT_WORKERS ?= 1
DATALOADER_REPEAT_COUNT ?= 1
DATALOADER_REPEAT_AGGREGATION ?= $(REPEAT_AGGREGATION)
DATALOADER_CPUS_PER_TASK ?= 16
DATALOADER_DEPENDENCY ?=
DATALOADER_RUN_ARGS ?=
DDP_RUN_ARGS ?=
DDP_TIME ?= 02:00:00
DDP_MEM ?= 0
DDP_REPEAT_COUNT ?= 1
DDP_REPEAT_STAGGER_SECONDS ?= 30
DDP_SRUN_MPI ?= pmix
DDP_SRUN_CPU_BIND ?=
DDP_SRUN_MEM_BIND ?=
DDP_COMPARISON_SCALES ?= 1,2,4
DDP_COMPARISON_INCLUDE_DEFAULT_SRUN ?= 0
DDP_COMPARISON_STAGGER_SECONDS ?= 30
HPL_MXP_MATRIX_SIZE ?= auto
HPL_MXP_NB ?= auto
HPL_MXP_NPROW ?= auto
HPL_MXP_NPCOL ?= auto
HPL_MXP_PRESET ?= smoke
HPL_MXP_AFFINITY_PROFILE ?= derived-nps4
HPL_MXP_IMAGE ?=
HPL_MXP_TIME ?= 00:30:00
HPL_MXP_MEM ?= 0
HPL_MXP_SLOPPY_TYPE ?= FP16
HPL_MXP_TEST_LOOP ?=
HPL_MXP_CPUS_PER_TASK ?= 16
HPL_MXP_OMPI_COLL ?= ^ucc
HPL_MXP_OMPI_PML ?=
HPL_MXP_OMPI_BTL ?=
HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE ?=
HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE ?=
HPL_MXP_UCX_TLS ?=
HPL_MXP_UCX_NET_DEVICES ?=
HPL_MXP_PMIX_MCA_GDS ?= ^ds12
HPL_MXP_MPI_USE_MPI ?= 0
HPL_MXP_MPI_PANEL_BROADCAST ?= 1
HPL_MXP_PRIORITIZE_TRSM ?= 0
HPL_MXP_PRIORITIZE_FACTORIZATION ?= 0
HPL_MXP_ANQ_DEVICE ?=
HPL_MXP_FILL_DEVICE ?=
HPL_MXP_FILL_DEVICE_BUFFER_SIZE ?=
HPL_MXP_CALL_DGEMV_THREADS ?=
HPL_MXP_PRESET_GEMM_KERNEL ?=
HPL_MXP_CPU_AFFINITY ?=
HPL_MXP_MEM_AFFINITY ?=
HPL_MXP_UCX_AFFINITY ?=
HPL_MXP_U_PANEL_CHUNK_NBS ?=
HPL_MXP_SCALING_STUDY ?= exploratory
HPL_MXP_BASELINE_MATRIX_SIZE ?=
HPL_MXP_REPEAT_COUNT ?= 1
HPL_MXP_REPEAT_STAGGER_SECONDS ?= 30
HPL_MXP_RENDER_JOB_ID_MIN ?=
HPL_MXP_RENDER_JOB_ID_MAX ?=
HPL_MXP_RENDER_JOB_ID_LIST ?=
ELBENCHO_INSTALL_METHOD ?= container
ELBENCHO_TAG ?= master-ubuntu-cuda-multiarch
ELBENCHO_IMAGE ?=
ELBENCHO_CPUS_PER_TASK ?= 64
ELBENCHO_MEM ?= 0
ELBENCHO_GRES ?=
ELBENCHO_PROFILE ?= $(PROFILE)
ELBENCHO_TIME ?= 01:00:00
ELBENCHO_REPEAT_COUNT ?= 1
ELBENCHO_REPEAT_STAGGER_SECONDS ?= 30
ELBENCHO_TARGET_ROOT ?=
ELBENCHO_SIZE ?=
ELBENCHO_BLOCK ?=
ELBENCHO_THREADS ?=
ELBENCHO_IODEPTH ?=
ELBENCHO_DEPENDENCY ?=
ELBENCHO_FILE_PATTERN ?=
ELBENCHO_FILES ?=
ELBENCHO_DIRS ?=
BENCHMARK_DRY_RUN_INCLUDE_ELBENCHO ?= 0
SETUP_READY_TIMEOUT_SECONDS ?= 180
SETUP_READY_POLL_SECONDS ?= 5
SETUP_REPLACE_EXISTING ?= 1
SETUP_REBUILD_RUNTIME ?= 1
WAIT ?= 0
RUNTIME_REPLACE_CURRENT ?= 0
CONTAINER_REFRESH ?= 0
INSTALL_ELBENCHO_CONTAINER ?= 0
INSTALL_ONLY_ELBENCHO_CONTAINER ?= 0
CONTAINER_PARTITION ?= cpu
CONTAINER_NODELIST ?=
CONTAINER_TIME ?= 04:00:00
CONTAINER_MEM ?= 0
CONTAINER_WAIT ?= 1
RUNTIME_PARTITION ?=
RUNTIME_MEM ?= 0
PYTHON_DOCTOR_PARTITION ?=
PYTHON_DOCTOR_TIME ?= 00:05:00
PYTHON_DOCTOR_CPUS_PER_TASK ?= 2
PYTHON_DOCTOR_GRES ?=
PYTHON_DOCTOR_MEM ?= 0
PYTHON_RUNTIME_SETUP ?= 0
ARCHIVE_ROTATE ?= 0
VERIFICATION_CAMPAIGN_PUBLIC_ROOT ?= /work/aicr/commissioning/benchmarks/public-study-artifacts
VERIFICATION_CAMPAIGN_PRIVATE_ROOT ?= /work/aicr/commissioning/benchmarks/results-archive
VERIFICATION_CAMPAIGN_OSN_REMOTE ?= bmark:csim-bmark
VERIFICATION_CAMPAIGN_SKIP_OSN ?= 0
REPO_PY ?= bash scripts/lib/run-repo-python.sh
DOCS ?=
DOCS_TEST_SUITE ?= all
DOCS_APPLY ?= 0

APPLY_FLAG := $(if $(filter 1,$(APPLY)),--apply,)
DOCS_ARGS := $(if $(strip $(DOCS)),--docs $(DOCS),)
DOCS_APPLY_FLAG := $(if $(filter 1,$(DOCS_APPLY)),--apply,)
VERIFICATION_CAMPAIGN_SKIP_OSN_FLAG := $(if $(filter 1,$(VERIFICATION_CAMPAIGN_SKIP_OSN)),--skip-osn,)
WAIT_FLAG := $(if $(filter 1,$(WAIT)),--wait,)
RUNTIME_REPLACE_FLAG := $(if $(filter 1,$(RUNTIME_REPLACE_CURRENT)),--replace-current,)
CONTAINER_REFRESH_FLAG := $(if $(filter 1,$(CONTAINER_REFRESH)),--refresh,)
INSTALL_ELBENCHO_CONTAINER_FLAG := $(if $(filter 1,$(INSTALL_ELBENCHO_CONTAINER)),--include-elbencho,)
INSTALL_ONLY_ELBENCHO_CONTAINER_FLAG := $(if $(filter 1,$(INSTALL_ONLY_ELBENCHO_CONTAINER)),--only-elbencho,)
CONTAINER_NODELIST_FLAG := $(if $(strip $(CONTAINER_NODELIST)),--nodelist $(CONTAINER_NODELIST),)
CONTAINER_WAIT_FLAG := $(if $(filter 0,$(CONTAINER_WAIT)),--no-wait,)
RUNTIME_PARTITION_FLAG := $(if $(strip $(RUNTIME_PARTITION)),--partition $(RUNTIME_PARTITION),)
PYTHON_DOCTOR_PARTITION_FLAG := $(if $(strip $(PYTHON_DOCTOR_PARTITION)),--partition $(PYTHON_DOCTOR_PARTITION),)
PYTHON_DOCTOR_GRES_FLAG := $(if $(strip $(PYTHON_DOCTOR_GRES)),--gres $(PYTHON_DOCTOR_GRES),)
PYTHON_RUNTIME_SETUP_FLAG := $(if $(filter 1,$(PYTHON_RUNTIME_SETUP)),--setup,)
SETUP_SMOKE_FLAG := $(if $(filter 1,$(APPLY)),--submit-smoke-tests,)
SETUP_REPLACE_FLAG := $(if $(filter 1,$(SETUP_REPLACE_EXISTING)),--replace-existing,)
ARCHIVE_ROTATE_FLAG := $(if $(filter 1,$(ARCHIVE_ROTATE)),--rotate,)
FROM_NODE_REPORT_FLAG := $(if $(filter 1,$(FROM_NODE_REPORT)),--from-node-report,)
NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodelist $(NODELIST),)
GPU_TOPOLOGY_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodes $(NODELIST),)
NCCL_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodes $(NODELIST),)
NCCL_SUITE_CLASS_FLAG := $(if $(strip $(NCCL_SUITE_CLASS)),--suite-class $(NCCL_SUITE_CLASS),)
NCCL_SUITE_OPS_FLAG := $(if $(strip $(NCCL_SUITE_OPS)),--ops $(NCCL_SUITE_OPS),)
NCCL_NODES_PER_JOB_FLAG := $(if $(strip $(NCCL_NODES_PER_JOB)),--nodes-per-job $(NCCL_NODES_PER_JOB),)
NCCL_SCALES_FLAG := $(if $(strip $(NCCL_SCALES)),--scales $(NCCL_SCALES),)
MODE_FLAG := $(if $(strip $(MODE)),--mode $(MODE),)
DDP_REPEAT_COUNT_FLAG := $(if $(strip $(DDP_REPEAT_COUNT)),--repeat-count $(DDP_REPEAT_COUNT),)
DDP_REPEAT_STAGGER_SECONDS_FLAG := $(if $(strip $(DDP_REPEAT_STAGGER_SECONDS)),--repeat-stagger-seconds $(DDP_REPEAT_STAGGER_SECONDS),)
DATALOADER_DEPENDENCY_FLAG := $(if $(strip $(DATALOADER_DEPENDENCY)),--dependency $(DATALOADER_DEPENDENCY),)
HPL_MXP_IMAGE_FLAG := $(if $(strip $(HPL_MXP_IMAGE)),--image $(HPL_MXP_IMAGE),)
HPL_MXP_MEM_FLAG := $(if $(strip $(HPL_MXP_MEM)),--mem $(HPL_MXP_MEM),)
HPL_MXP_CPUS_PER_TASK_FLAG := $(if $(strip $(HPL_MXP_CPUS_PER_TASK)),--cpus-per-task $(HPL_MXP_CPUS_PER_TASK),)
HPL_MXP_OMPI_COLL_FLAG := $(if $(strip $(HPL_MXP_OMPI_COLL)),--ompi-coll $(HPL_MXP_OMPI_COLL),)
HPL_MXP_OMPI_PML_FLAG := $(if $(strip $(HPL_MXP_OMPI_PML)),--ompi-pml $(HPL_MXP_OMPI_PML),)
HPL_MXP_OMPI_BTL_FLAG := $(if $(strip $(HPL_MXP_OMPI_BTL)),--ompi-btl $(HPL_MXP_OMPI_BTL),)
HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE_FLAG := $(if $(strip $(HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE)),--ompi-btl-tcp-if-include $(HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE),)
HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE_FLAG := $(if $(strip $(HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE)),--ompi-oob-tcp-if-include $(HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE),)
HPL_MXP_UCX_TLS_FLAG := $(if $(strip $(HPL_MXP_UCX_TLS)),--ucx-tls $(HPL_MXP_UCX_TLS),)
HPL_MXP_UCX_NET_DEVICES_FLAG := $(if $(strip $(HPL_MXP_UCX_NET_DEVICES)),--ucx-net-devices $(HPL_MXP_UCX_NET_DEVICES),)
HPL_MXP_PMIX_MCA_GDS_FLAG := $(if $(strip $(HPL_MXP_PMIX_MCA_GDS)),--pmix-mca-gds $(HPL_MXP_PMIX_MCA_GDS),)
HPL_MXP_NPROW_FLAG := $(if $(filter-out auto,$(strip $(HPL_MXP_NPROW))),--nprow $(HPL_MXP_NPROW),)
HPL_MXP_NPCOL_FLAG := $(if $(filter-out auto,$(strip $(HPL_MXP_NPCOL))),--npcol $(HPL_MXP_NPCOL),)
HPL_MXP_AFFINITY_PROFILE_FLAG := $(if $(strip $(HPL_MXP_AFFINITY_PROFILE)),--affinity-profile $(HPL_MXP_AFFINITY_PROFILE),)
HPL_MXP_MPI_USE_MPI_FLAG := $(if $(strip $(HPL_MXP_MPI_USE_MPI)),--mpi-use-mpi $(HPL_MXP_MPI_USE_MPI),)
HPL_MXP_MPI_PANEL_BROADCAST_FLAG := $(if $(strip $(HPL_MXP_MPI_PANEL_BROADCAST)),--use-mpi-panel-broadcast $(HPL_MXP_MPI_PANEL_BROADCAST),)
HPL_MXP_PRIORITIZE_TRSM_FLAG := $(if $(strip $(HPL_MXP_PRIORITIZE_TRSM)),--prioritize-trsm $(HPL_MXP_PRIORITIZE_TRSM),)
HPL_MXP_PRIORITIZE_FACTORIZATION_FLAG := $(if $(strip $(HPL_MXP_PRIORITIZE_FACTORIZATION)),--prioritize-factorization $(HPL_MXP_PRIORITIZE_FACTORIZATION),)
HPL_MXP_ANQ_DEVICE_FLAG := $(if $(strip $(HPL_MXP_ANQ_DEVICE)),--anq-device $(HPL_MXP_ANQ_DEVICE),)
HPL_MXP_FILL_DEVICE_FLAG := $(if $(strip $(HPL_MXP_FILL_DEVICE)),--fill-device $(HPL_MXP_FILL_DEVICE),)
HPL_MXP_FILL_DEVICE_BUFFER_SIZE_FLAG := $(if $(strip $(HPL_MXP_FILL_DEVICE_BUFFER_SIZE)),--fill-device-buffer-size $(HPL_MXP_FILL_DEVICE_BUFFER_SIZE),)
HPL_MXP_CALL_DGEMV_THREADS_FLAG := $(if $(strip $(HPL_MXP_CALL_DGEMV_THREADS)),--call-dgemv-with-multiple-threads $(HPL_MXP_CALL_DGEMV_THREADS),)
HPL_MXP_PRESET_GEMM_KERNEL_FLAG := $(if $(strip $(HPL_MXP_PRESET_GEMM_KERNEL)),--preset-gemm-kernel $(HPL_MXP_PRESET_GEMM_KERNEL),)
HPL_MXP_CPU_AFFINITY_FLAG := $(if $(strip $(HPL_MXP_CPU_AFFINITY)),--cpu-affinity $(HPL_MXP_CPU_AFFINITY),)
HPL_MXP_MEM_AFFINITY_FLAG := $(if $(strip $(HPL_MXP_MEM_AFFINITY)),--mem-affinity $(HPL_MXP_MEM_AFFINITY),)
HPL_MXP_UCX_AFFINITY_FLAG := $(if $(strip $(HPL_MXP_UCX_AFFINITY)),--ucx-affinity $(HPL_MXP_UCX_AFFINITY),)
HPL_MXP_U_PANEL_CHUNK_NBS_FLAG := $(if $(strip $(HPL_MXP_U_PANEL_CHUNK_NBS)),--u-panel-chunk-nbs $(HPL_MXP_U_PANEL_CHUNK_NBS),)
HPL_MXP_SCALING_STUDY_FLAG := $(if $(strip $(HPL_MXP_SCALING_STUDY)),--scaling-study $(HPL_MXP_SCALING_STUDY),)
HPL_MXP_BASELINE_MATRIX_SIZE_FLAG := $(if $(strip $(HPL_MXP_BASELINE_MATRIX_SIZE)),--baseline-matrix-size $(HPL_MXP_BASELINE_MATRIX_SIZE),)
HPL_MXP_TEST_LOOP_FLAG := $(if $(strip $(HPL_MXP_TEST_LOOP)),--test-loop $(HPL_MXP_TEST_LOOP),)
HPL_MXP_REPEAT_COUNT_FLAG := $(if $(strip $(HPL_MXP_REPEAT_COUNT)),--repeat-count $(HPL_MXP_REPEAT_COUNT),)
HPL_MXP_REPEAT_STAGGER_SECONDS_FLAG := $(if $(strip $(HPL_MXP_REPEAT_STAGGER_SECONDS)),--repeat-stagger-seconds $(HPL_MXP_REPEAT_STAGGER_SECONDS),)
ELBENCHO_IMAGE_FLAG := $(if $(strip $(ELBENCHO_IMAGE)),--image $(ELBENCHO_IMAGE),)
ELBENCHO_REPEAT_COUNT_FLAG := $(if $(strip $(ELBENCHO_REPEAT_COUNT)),--repeat-count $(ELBENCHO_REPEAT_COUNT),)
ELBENCHO_REPEAT_STAGGER_SECONDS_FLAG := $(if $(strip $(ELBENCHO_REPEAT_STAGGER_SECONDS)),--repeat-stagger-seconds $(ELBENCHO_REPEAT_STAGGER_SECONDS),)
ELBENCHO_DEPENDENCY_FLAG := $(if $(strip $(ELBENCHO_DEPENDENCY)),--dependency $(ELBENCHO_DEPENDENCY),)
ELBENCHO_GRES_FLAG := $(if $(strip $(ELBENCHO_GRES)),--gres $(ELBENCHO_GRES),)
BENCHMARK_DRY_RUN_ELBENCHO_FLAG := $(if $(filter 1,$(BENCHMARK_DRY_RUN_INCLUDE_ELBENCHO)),--include-elbencho,)
INSTALL_SMOKE_RTX_NODES_FLAG := $(if $(strip $(INSTALL_SMOKE_RTX_NODES)),--rtx-nodes $(INSTALL_SMOKE_RTX_NODES),)
INSTALL_SMOKE_B200_NODES_FLAG := $(if $(strip $(INSTALL_SMOKE_B200_NODES)),--b200-nodes $(INSTALL_SMOKE_B200_NODES),)
INSTALL_SMOKE_AUDIT_ROOT_FLAG := $(if $(strip $(INSTALL_SMOKE_AUDIT_ROOT)),--audit-root $(INSTALL_SMOKE_AUDIT_ROOT),)
INSTALL_SMOKE_RESUME_FROM_AUDIT_ROOT_FLAG := $(if $(strip $(INSTALL_SMOKE_RESUME_FROM_AUDIT_ROOT)),--resume-from-audit-root $(INSTALL_SMOKE_RESUME_FROM_AUDIT_ROOT),)
INSTALL_SMOKE_SKIP_TOPOLOGY_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_TOPOLOGY)),--skip-topology,)
INSTALL_SMOKE_SKIP_GDS_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_GDS)),--skip-gds,)
INSTALL_SMOKE_SKIP_NCCL_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_NCCL)),--skip-nccl,)
INSTALL_SMOKE_SKIP_RDMA_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_RDMA)),--skip-rdma,)
INSTALL_SMOKE_SKIP_HPL_MXP_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_HPL_MXP)),--skip-hpl-mxp,)
INSTALL_SMOKE_SKIP_DATALOADER_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_DATALOADER)),--skip-dataloader,)
INSTALL_SMOKE_SKIP_DDP_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_DDP)),--skip-ddp,)
INSTALL_SMOKE_HPL_MXP_B200_NODE_FLAG := $(if $(strip $(INSTALL_SMOKE_HPL_MXP_B200_NODE)),--hpl-mxp-b200-node $(INSTALL_SMOKE_HPL_MXP_B200_NODE),)
INSTALL_SMOKE_HPL_MXP_RTX_NODE_FLAG := $(if $(strip $(INSTALL_SMOKE_HPL_MXP_RTX_NODE)),--hpl-mxp-rtx-node $(INSTALL_SMOKE_HPL_MXP_RTX_NODE),)
INSTALL_SMOKE_HPL_MXP_APPLY_RTX_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_HPL_MXP_APPLY_RTX)),--hpl-mxp-apply-rtx,)
INSTALL_SMOKE_HPL_MXP_TIME_FLAG := $(if $(strip $(INSTALL_SMOKE_HPL_MXP_TIME)),--hpl-mxp-time $(INSTALL_SMOKE_HPL_MXP_TIME),)
INSTALL_SMOKE_HPL_MXP_PRESET_FLAG := $(if $(strip $(INSTALL_SMOKE_HPL_MXP_PRESET)),--hpl-mxp-preset $(INSTALL_SMOKE_HPL_MXP_PRESET),)
INSTALL_SMOKE_HPL_MXP_SLOPPY_TYPE_FLAG := $(if $(strip $(INSTALL_SMOKE_HPL_MXP_SLOPPY_TYPE)),--hpl-mxp-sloppy-type $(INSTALL_SMOKE_HPL_MXP_SLOPPY_TYPE),)
INSTALL_SMOKE_DATALOADER_TIME_FLAG := $(if $(strip $(INSTALL_SMOKE_DATALOADER_TIME)),--dataloader-time $(INSTALL_SMOKE_DATALOADER_TIME),)
INSTALL_SMOKE_DDP_TIME_FLAG := $(if $(strip $(INSTALL_SMOKE_DDP_TIME)),--ddp-time $(INSTALL_SMOKE_DDP_TIME),)
INSTALL_SMOKE_INCLUDE_ELBENCHO_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_INCLUDE_ELBENCHO)),--include-elbencho,)
INSTALL_SMOKE_ELBENCHO_B200_NODE_FLAG := $(if $(strip $(INSTALL_SMOKE_ELBENCHO_B200_NODE)),--elbencho-b200-node $(INSTALL_SMOKE_ELBENCHO_B200_NODE),)
INSTALL_SMOKE_ELBENCHO_RTX_NODE_FLAG := $(if $(strip $(INSTALL_SMOKE_ELBENCHO_RTX_NODE)),--elbencho-rtx-node $(INSTALL_SMOKE_ELBENCHO_RTX_NODE),)
INSTALL_SMOKE_ELBENCHO_TARGET_ROOT_FLAG := $(if $(strip $(INSTALL_SMOKE_ELBENCHO_TARGET_ROOT)),--elbencho-target-root $(INSTALL_SMOKE_ELBENCHO_TARGET_ROOT),)
INSTALL_SMOKE_ELBENCHO_TIME_FLAG := $(if $(strip $(INSTALL_SMOKE_ELBENCHO_TIME)),--elbencho-time $(INSTALL_SMOKE_ELBENCHO_TIME),)
INSTALL_SMOKE_ONLY_ELBENCHO_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_ONLY_ELBENCHO)),--only-elbencho,)
INSTALL_SMOKE_SKIP_RTX_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_RTX)),--skip-rtx,)
INSTALL_SMOKE_SKIP_B200_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_B200)),--skip-b200,)
INSTALL_SMOKE_SKIP_LOCAL_CHECKS_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_LOCAL_CHECKS)),--skip-local-checks,)
INSTALL_SMOKE_SKIP_DRY_RUNS_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_DRY_RUNS)),--skip-dry-runs,)
INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH)),--skip-explicit-sbatch,)
INSTALL_SMOKE_NO_RENDER_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_NO_RENDER)),--no-render,)
INSTALL_SMOKE_RENDER_ONLY_FLAG := $(if $(filter 1,$(INSTALL_SMOKE_RENDER_ONLY)),--render-only,)
DDP_COMPARISON_DEFAULT_SRUN_FLAG := $(if $(filter 1,$(DDP_COMPARISON_INCLUDE_DEFAULT_SRUN)),--include-default-srun,)
REPEAT_AGGREGATION_FLAG := --repeat-aggregation $(REPEAT_AGGREGATION)
HPL_MXP_RENDER_JOB_ID_MIN_FLAG := $(if $(strip $(HPL_MXP_RENDER_JOB_ID_MIN)),--job-id-min $(HPL_MXP_RENDER_JOB_ID_MIN),)
HPL_MXP_RENDER_JOB_ID_MAX_FLAG := $(if $(strip $(HPL_MXP_RENDER_JOB_ID_MAX)),--job-id-max $(HPL_MXP_RENDER_JOB_ID_MAX),)
HPL_MXP_RENDER_JOB_ID_LIST_FLAG := $(if $(strip $(HPL_MXP_RENDER_JOB_ID_LIST)),--job-id-list $(HPL_MXP_RENDER_JOB_ID_LIST),)
GPU_PREFLIGHT_FILTER_FLAG := $(if $(filter 1,$(GPU_PREFLIGHT_FILTER)),--gpu-preflight-filter,)
GDS_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodes $(NODELIST),)
REPORT_DATE := $(shell if [ "$(DATE)" = "today" ]; then date -u +%F; else printf '%s' "$(DATE)"; fi)

help:
	@printf '%s\n' \
		"AICR-Bench Make interface" \
		"" \
		"Primary verification targets:" \
		"  make system-verify CLUSTER=<b200|rtxpro6000> PROFILE=<small|...> APPLY=1" \
		"      Submit setup and verification jobs, then archive/render/validate reports." \
		"      Benchmark-day repeated sampling: REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic." \
		"      For RTX workload filtering, add GPU_PREFLIGHT_FILTER=1." \
		"  make verify-nccl-suite NCCL_SCOPE=<local|rdma|scale> CLUSTER=<b200|rtxpro6000> PROFILE=<smoke|small|...> [NODELIST=<nodes>] APPLY=1" \
		"      Submit NCCL local, RDMA, or scale-suite jobs." \
		"  make install-gpu-smoke-suite INSTALL_SMOKE_RTX_NODES=<n1,n2> INSTALL_SMOKE_B200_NODES=<n1,n2>" \
		"      Validate install-tree GPU Topology, GDS, NCCL, HPL-MxP, DataLoader, DDP, and optional Elbencho surfaces; dry-run by default." \
		"  make render CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"      Render system verification campaign and by-node reports." \
		"  make render-nccl-suite NCCL_SCOPE=<local|rdma|scale> CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"      Print an NCCL suite report from existing result trees." \
		"  make validate-reports CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"      Validate rendered system verification report JSON and links." \
		"  make docs-link-check" \
		"      Check public documentation hygiene and man-page links." \
		"  make check-artifact-policy" \
		"      Fail if raw or unpromoted generated artifacts are present in Git." \
		"  make validate-benchmark-campaign-registry" \
		"      Validate the benchmark campaign requirements registry and policy gates." \
		"" \
		"Primary benchmark targets:" \
		"  make benchmark-dry-run-suite CLUSTER=<b200|rtxpro6000> NODE_REPORT_DATE=<date>" \
		"      Run the benchmark submission preflight; prints sbatch shapes and submits no Slurm jobs." \
		"  make benchmark-dataloader CLUSTER=<b200|rtxpro6000> ..." \
		"      Preview or submit DataLoader benchmark sweeps." \
		"  make benchmark-ddp-resnet50 CLUSTER=<b200|rtxpro6000> NODES=<n> ..." \
		"      Preview or submit ResNet-50 DDP runs." \
		"  make benchmark-hpl-mxp CLUSTER=<b200|rtxpro6000> NODES=<n> ..." \
		"      Guarded HPL entrypoint; HPL_MXP_PRESET selects smoke, staged, campaign-candidate, or weak-study rows." \
		"  make render-benchmark-campaign DATE=<date>" \
		"      Render the benchmark campaign requirements dashboard." \
		"Common variables:" \
		"  CLUSTER=b200|rtxpro6000   DATE=<YYYY-MM-DD|today>   APPLY=0|1" \
		"  NODELIST=<node[,node...]> limits supported submitters to explicit nodes." \
		"  For verify-nccl-suite, NODELIST is a candidate pool; NCCL_SCALES controls groups." \
		"  NCCL_SCALES=1,2,4 on RTX and 1,2,4,8,16 on B200." \
		"  NODE_REPORT_DATE=<date> selects the node report used for benchmark node selection." \
		"  REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic is the benchmark-day GDS/NCCL policy." \
		"  make install-containers CONTAINER_NODELIST=<node> submits container pulls through Slurm." \
		"" \
		"Run 'make help-benchmarks' for benchmark-specific variables." \
		"Deprecated compatibility aliases:" \
		"  daily-verify -> system-verify" \
		"  benchmark-readiness-nccl -> verify-nccl-suite" \
		"  benchmark-hpl-mxp-smoke -> benchmark-hpl-mxp HPL_MXP_PRESET=smoke"

help-benchmarks:
	@printf '%s\n' \
		"AICR-Bench benchmark Make targets" \
		"" \
		"Interface model:" \
		"  Make is the supported front door for benchmark execution." \
		"  Direct scripts under scripts/benchmark/ are low-level implementation surfaces." \
		"  scripts/operator/aicr is for reporting, archive, and doctor workflows." \
		"" \
		"Dry-run/apply contract:" \
		"  Benchmark submission targets are dry-run first by default." \
		"  Add APPLY=1 to submit jobs." \
		"  benchmark-dry-run-suite is a benchmark submission preflight and submits no Slurm jobs." \
		"  Render targets write generated review artifacts under results/reports/<date>/." \
		"  Generated runtime trees remain uncommitted unless explicitly promoted." \
		"" \
		"Benchmark-day verification variables:" \
		"  REPEAT_COUNT=5 repeats GDS and NCCL suite readiness samples for final review." \
		"  REPEAT_AGGREGATION=olympic drops high/low passed numeric samples and averages the middle 3." \
		"  GPU_PREFLIGHT_FILTER=1 filters RTX GDS/NCCL submissions from same-day topology evidence." \
		"  Failed, skipped, and missing samples remain visible; they are not hidden by aggregation." \
		"" \
		"Date variables:" \
		"  DATE is the report, archive, and render date; accepts today, yesterday, or YYYY-MM-DD." \
		"  NODE_REPORT_DATE selects the strict-passed node report for benchmark submissions." \
		"  NODE_REPORT_DATE defaults to DATE." \
		"" \
		"DataLoader:" \
		"  make benchmark-dataloader CLUSTER=<b200|rtxpro6000> FROM_NODE_REPORT=1 NODE_REPORT_DATE=<date> ..." \
		"  Key vars: DATALOADER_NODES, GPU_COUNT, MODE, DATALOADER_BATCH_SIZES," \
		"            DATALOADER_INPUT_BACKENDS, DATALOADER_NUM_WORKERS, DATALOADER_PREFETCH_FACTORS," \
		"            DATALOADER_REPEAT_COUNT, DATALOADER_RUN_ARGS." \
		"  DataLoader node sweeps support DATALOADER_NODES=1,2,4,8,16 for B200 and RTX." \
		"" \
		"DDP ResNet-50:" \
		"  make benchmark-ddp-resnet50 CLUSTER=<b200|rtxpro6000> NODES=<n> LAUNCHER=torchrun ..." \
		"  Key vars: NODES, LAUNCHER, DDP_RUN_ARGS, DDP_TIME, DDP_REPEAT_COUNT," \
		"            DDP_REPEAT_STAGGER_SECONDS, DDP_SRUN_MPI, DDP_SRUN_CPU_BIND," \
		"            DDP_SRUN_MEM_BIND." \
		"  DDP_RUN_ARGS may select --input-backend pytorch-cpu-dataloader, dali-gpu-decode, or synthetic-gpu." \
		"  Campaign-required rows use LAUNCHER=torchrun; srun is optional comparison evidence." \
		"" \
		"HPL-MxP:" \
		"  make benchmark-hpl-mxp CLUSTER=<b200|rtxpro6000> NODES=<n> HPL_MXP_PRESET=<smoke|staged|campaign-candidate|weak-study>" \
		"  make benchmark-hpl-mxp CLUSTER=<b200|rtxpro6000> NODES=<n> HPL_MXP_PRESET=weak-study HPL_MXP_AFFINITY_PROFILE=derived-nps4 HPL_MXP_SCALING_STUDY=weak" \
		"  Key vars: HPL_MXP_PRESET, HPL_MXP_MATRIX_SIZE, HPL_MXP_NB, HPL_MXP_TIME, HPL_MXP_MEM, HPL_MXP_TEST_LOOP." \
		"            HPL_MXP_REPEAT_COUNT controls independent repeated samples." \
		"            HPL_MXP_CPUS_PER_TASK for host-heavy FP64/GMRES rows." \
		"            HPL_MXP_NPROW, HPL_MXP_NPCOL, HPL_MXP_AFFINITY_PROFILE," \
		"            HPL_MXP_OMPI_COLL/PML/BTL, HPL_MXP_UCX_TLS/NET_DEVICES," \
		"            HPL_MXP_PMIX_MCA_GDS, HPL_MXP_MPI_USE_MPI," \
		"            HPL_MXP_MPI_PANEL_BROADCAST, HPL_MXP_PRIORITIZE_FACTORIZATION," \
		"            HPL_MXP_ANQ_DEVICE, HPL_MXP_FILL_DEVICE, HPL_MXP_CALL_DGEMV_THREADS," \
		"            HPL_MXP_PRESET_GEMM_KERNEL," \
		"            HPL_MXP_CPU_AFFINITY, HPL_MXP_MEM_AFFINITY, HPL_MXP_UCX_AFFINITY," \
		"            HPL_MXP_U_PANEL_CHUNK_NBS for sizing and control rows." \
		"            HPL_MXP_SCALING_STUDY and HPL_MXP_BASELINE_MATRIX_SIZE for scaling." \
		"  HPL_MXP_PRESET=weak-study uses the reviewed weak-scaling ladder and derived NPS4 affinity profile." \
		"  weak-study rows use reviewed N targets, weak scaling metadata, and derived NPS4 affinity." \
		"  weak-study supports the node counts accepted by submit-hpl-mxp." \
		"  campaign-candidate rows remain available for older reviewed target-size studies." \
		"  Compatibility alias: benchmark-hpl-mxp-smoke forwards to benchmark-hpl-mxp with HPL_MXP_PRESET=smoke." \
		"" \
		"Elbencho:" \
		"  make benchmark-elbencho CLUSTER=<b200|rtxpro6000> WORKLOAD=<peak-cluster|small-block|small-file|metadata> PROFILE=<smoke|small>" \
		"  PROFILE selects reviewed file-backed templates; ELBENCHO_PROFILE is an Elbencho-specific override." \
		"  ELBENCHO_REPEAT_COUNT submits serialized Slurm repeats with afterok dependencies." \
		"  ELBENCHO_SIZE, ELBENCHO_BLOCK, ELBENCHO_THREADS, ELBENCHO_IODEPTH, ELBENCHO_FILE_PATTERN, ELBENCHO_FILES, and ELBENCHO_DIRS tune profile templates for calibration." \
		"  ELBENCHO_CMD remains an expert override." \
		"" \
		"Rendering:" \
		"  make render-dataloader CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"  make render-ddp-resnet50 CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"  make render-hpl-mxp CLUSTER=<b200|rtxpro6000> DATE=<date>" \
		"  make render-benchmark-campaign DATE=<date>" \
		"" \
		"Closeout archive:" \
		"  make archive-benchmark-study-b200 CLUSTER=b200 DATE=<date>"

doctor:
	scripts/operator/aicr doctor repo-root

require-settings:
	@settings_file="$${AICR_SETTINGS_FILE:-benchmark-settings.env}"; \
	if [ ! -f "$$settings_file" ]; then \
		printf '%s\n' "ERROR: $$settings_file not found in $$(pwd)." >&2; \
		printf '%s\n' "Create it first: cp benchmark-settings.env.example benchmark-settings.env" >&2; \
		exit 2; \
	fi

doctor-python:
	bash scripts/setup/doctor-python.sh

doctor-python-slurm: require-settings
	bash scripts/setup/submit-python-runtime-slurm.sh \
		--time $(PYTHON_DOCTOR_TIME) \
		--cpus-per-task $(PYTHON_DOCTOR_CPUS_PER_TASK) \
		--mem $(PYTHON_DOCTOR_MEM) \
		$(PYTHON_DOCTOR_PARTITION_FLAG) \
		$(PYTHON_DOCTOR_GRES_FLAG) \
		$(PYTHON_RUNTIME_SETUP_FLAG) \
		$(NODELIST_FLAG) \
		$(APPLY_FLAG) \
		$(WAIT_FLAG)

setup-python-slurm: require-settings
	bash scripts/setup/submit-python-runtime-slurm.sh \
		--setup \
		--time $(PYTHON_DOCTOR_TIME) \
		--cpus-per-task $(PYTHON_DOCTOR_CPUS_PER_TASK) \
		--mem $(PYTHON_DOCTOR_MEM) \
		$(PYTHON_DOCTOR_PARTITION_FLAG) \
		$(PYTHON_DOCTOR_GRES_FLAG) \
		$(NODELIST_FLAG) \
		$(APPLY_FLAG) \
		$(WAIT_FLAG)

setup-python-local:
	bash scripts/setup/setup-python-local.sh

refresh-python-locks:
	bash scripts/setup/refresh-python-locks.sh

rebuild-runtime: require-settings
	bash scripts/setup/submit-runtime-rebuild.sh --mem $(RUNTIME_MEM) $(APPLY_FLAG) $(WAIT_FLAG) $(RUNTIME_PARTITION_FLAG) $(RUNTIME_REPLACE_FLAG)

install-containers: require-settings
	bash scripts/setup/submit-container-install.sh \
		--partition $(CONTAINER_PARTITION) \
		--time $(CONTAINER_TIME) \
		--mem $(CONTAINER_MEM) \
		$(APPLY_FLAG) \
		$(CONTAINER_NODELIST_FLAG) \
		$(CONTAINER_REFRESH_FLAG) \
		$(INSTALL_ELBENCHO_CONTAINER_FLAG) \
		$(INSTALL_ONLY_ELBENCHO_CONTAINER_FLAG) \
		$(CONTAINER_WAIT_FLAG)

setup:
	bash scripts/setup/init-repo-layout.sh
	@if ! bash scripts/setup/check-runtime-assets.sh; then \
		if [ "$(SETUP_REBUILD_RUNTIME)" = "1" ]; then \
			echo "Runtime assets are missing or incomplete; rebuilding before setup."; \
			bash scripts/setup/submit-runtime-rebuild.sh --mem $(RUNTIME_MEM) $(APPLY_FLAG) $(WAIT_FLAG) $(RUNTIME_PARTITION_FLAG) $(RUNTIME_REPLACE_FLAG) --wait-complete || exit 1; \
			if [ "$(APPLY)" != "1" ]; then \
				echo "Dry run only. Re-run with APPLY=1 to rebuild runtime before setup."; \
				exit 0; \
			fi; \
			bash scripts/setup/check-runtime-assets.sh || exit 1; \
		else \
			echo "ERROR: runtime assets are missing or incomplete." >&2; \
			echo "Run make rebuild-runtime APPLY=1, or rerun setup with SETUP_REBUILD_RUNTIME=1." >&2; \
			exit 1; \
		fi; \
	fi; \
	bash scripts/setup/run-setup-gate-and-promote.sh \
		--cluster $(CLUSTER) \
		--ready-timeout-seconds $(SETUP_READY_TIMEOUT_SECONDS) \
		--ready-poll-seconds $(SETUP_READY_POLL_SECONDS) \
		$(SETUP_SMOKE_FLAG) \
		$(SETUP_REPLACE_FLAG)

verify: verify-topology verify-gds verify-nccl-suite

install-gpu-smoke-suite: require-settings
	bash scripts/verify/run-install-gpu-smoke-suite.sh \
		$(INSTALL_SMOKE_RTX_NODES_FLAG) \
		$(INSTALL_SMOKE_B200_NODES_FLAG) \
		$(INSTALL_SMOKE_AUDIT_ROOT_FLAG) \
		$(INSTALL_SMOKE_RESUME_FROM_AUDIT_ROOT_FLAG) \
		--date $(REPORT_DATE) \
		$(INSTALL_SMOKE_SKIP_TOPOLOGY_FLAG) \
		$(INSTALL_SMOKE_SKIP_GDS_FLAG) \
		$(INSTALL_SMOKE_SKIP_NCCL_FLAG) \
		$(INSTALL_SMOKE_SKIP_RDMA_FLAG) \
		$(INSTALL_SMOKE_SKIP_HPL_MXP_FLAG) \
		$(INSTALL_SMOKE_SKIP_DATALOADER_FLAG) \
		$(INSTALL_SMOKE_SKIP_DDP_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_B200_NODE_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_RTX_NODE_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_APPLY_RTX_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_TIME_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_PRESET_FLAG) \
		$(INSTALL_SMOKE_HPL_MXP_SLOPPY_TYPE_FLAG) \
		$(INSTALL_SMOKE_DATALOADER_TIME_FLAG) \
		$(INSTALL_SMOKE_DDP_TIME_FLAG) \
		$(INSTALL_SMOKE_INCLUDE_ELBENCHO_FLAG) \
		$(INSTALL_SMOKE_ELBENCHO_B200_NODE_FLAG) \
		$(INSTALL_SMOKE_ELBENCHO_RTX_NODE_FLAG) \
		$(INSTALL_SMOKE_ELBENCHO_TARGET_ROOT_FLAG) \
		$(INSTALL_SMOKE_ELBENCHO_TIME_FLAG) \
		$(INSTALL_SMOKE_ONLY_ELBENCHO_FLAG) \
		$(INSTALL_SMOKE_SKIP_RTX_FLAG) \
		$(INSTALL_SMOKE_SKIP_B200_FLAG) \
		$(INSTALL_SMOKE_SKIP_LOCAL_CHECKS_FLAG) \
		$(INSTALL_SMOKE_SKIP_DRY_RUNS_FLAG) \
		$(INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH_FLAG) \
		$(INSTALL_SMOKE_NO_RENDER_FLAG) \
		$(INSTALL_SMOKE_RENDER_ONLY_FLAG) \
		$(APPLY_FLAG)

verify-topology: require-settings
	bash scripts/verify/run-gpu-topology-fleet.sh --cluster $(CLUSTER) $(GPU_TOPOLOGY_NODELIST_FLAG) $(APPLY_FLAG)

verify-gds: require-settings
	bash scripts/verify/run-gds-fleet.sh \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		$(GDS_NODELIST_FLAG) \
		--repeat-count $(REPEAT_COUNT) \
		$(REPEAT_AGGREGATION_FLAG) \
		$(GPU_PREFLIGHT_FILTER_FLAG) \
		--submit-stagger-seconds $(GDS_SUBMIT_STAGGER_SECONDS) \
		--round-stagger-seconds $(ROUND_STAGGER_SECONDS) \
		$(APPLY_FLAG)

verify-nccl-suite: require-settings
	bash scripts/verify/submit-nccl-suite.sh \
		--scope $(NCCL_SCOPE) \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		$(NCCL_NODELIST_FLAG) \
		$(NCCL_SUITE_CLASS_FLAG) \
		$(NCCL_SUITE_OPS_FLAG) \
		$(NCCL_NODES_PER_JOB_FLAG) \
		$(NCCL_SCALES_FLAG) \
		--repeat-count $(REPEAT_COUNT) \
		$(REPEAT_AGGREGATION_FLAG) \
		$(GPU_PREFLIGHT_FILTER_FLAG) \
		--submit-stagger-seconds $(NCCL_SUBMIT_STAGGER_SECONDS) \
		--scale-stagger-seconds $(NCCL_SCALE_STAGGER_SECONDS) \
		--round-stagger-seconds $(ROUND_STAGGER_SECONDS) \
		$(APPLY_FLAG)

archive-verify:
	bash scripts/report/archive-results.sh --date $(DATE) --cluster $(CLUSTER) $(ARCHIVE_ROTATE_FLAG)

archive-verification-campaign:
	bash scripts/report/archive-verification-campaign-results.sh --date $(DATE) --cluster $(CLUSTER) --public-root $(VERIFICATION_CAMPAIGN_PUBLIC_ROOT) --private-root $(VERIFICATION_CAMPAIGN_PRIVATE_ROOT) --osn-remote $(VERIFICATION_CAMPAIGN_OSN_REMOTE) $(VERIFICATION_CAMPAIGN_SKIP_OSN_FLAG) $(ARCHIVE_ROTATE_FLAG)

archive-verification-campaign-all:
	bash scripts/report/archive-verification-campaign-results.sh --date $(DATE) --public-root $(VERIFICATION_CAMPAIGN_PUBLIC_ROOT) --private-root $(VERIFICATION_CAMPAIGN_PRIVATE_ROOT) --osn-remote $(VERIFICATION_CAMPAIGN_OSN_REMOTE) $(VERIFICATION_CAMPAIGN_SKIP_OSN_FLAG) $(ARCHIVE_ROTATE_FLAG)

render:
	scripts/operator/aicr render nodes --date $(DATE) --cluster $(CLUSTER) --both --write
	scripts/operator/aicr render campaign --date $(DATE) --cluster $(CLUSTER) --both --write

render-gds-ascii:
	$(REPO_PY) scripts/report/render-verify-dashboard.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --check gds --ascii

render-nccl-suite:
	$(REPO_PY) scripts/report/render-nccl-suite-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --scope $(NCCL_SCOPE) $(NCCL_NODES_PER_JOB_FLAG)

render-report-index:
	$(REPO_PY) scripts/report/report_index.py --results-root results --write

render-benchmark-candidates:
	scripts/operator/aicr render nodes --date $(DATE) --cluster $(CLUSTER) --both --write
	$(MAKE) render-report-index

validate-reports:
	scripts/operator/aicr render nodes --date $(DATE) --cluster $(CLUSTER) --ascii
	scripts/operator/aicr render campaign --date $(DATE) --cluster $(CLUSTER) --ascii
	$(REPO_PY) -m json.tool results/reports/$(REPORT_DATE)/nodes-$(CLUSTER)-$(REPORT_DATE).json >/dev/null
	$(REPO_PY) -m json.tool results/reports/$(REPORT_DATE)/campaign-$(CLUSTER)-$(REPORT_DATE).json >/dev/null
	grep -n "campaign-$(CLUSTER)-$(REPORT_DATE).md" results/reports/README.md
	grep -n "nodes-$(CLUSTER)-$(REPORT_DATE).md" results/reports/README.md
	grep -n "nccl-suite-$(CLUSTER).md" results/reports/README.md
	grep -n '\](' results/reports/$(REPORT_DATE)/nodes-$(CLUSTER)-$(REPORT_DATE).md
	grep -n '\](' results/reports/$(REPORT_DATE)/campaign-$(CLUSTER)-$(REPORT_DATE).md
	git diff --check

docs-link-check:
	$(REPO_PY) scripts/docs/check-public-docs.py
	$(REPO_PY) scripts/docs/check-man-links.py

docs-test-plan:
	$(REPO_PY) scripts/docs/aicr-doctest.py --suite $(DOCS_TEST_SUITE) $(DOCS_ARGS) $(DOCS_APPLY_FLAG) --cluster $(CLUSTER) --nodelist "$(NODELIST)" --date $(DATE) plan

docs-test:
	$(REPO_PY) scripts/docs/aicr-doctest.py --suite $(DOCS_TEST_SUITE) $(DOCS_ARGS) $(DOCS_APPLY_FLAG) --cluster $(CLUSTER) --nodelist "$(NODELIST)" --date $(DATE) run

docs-test-plan-gpu-topology:
	$(MAKE) docs-test-plan DOCS=docs/modules/gpu-topology DOCS_TEST_SUITE=gpu-topology

docs-test-gpu-topology:
	$(MAKE) docs-test DOCS=docs/modules/gpu-topology DOCS_TEST_SUITE=gpu-topology

docs-test-plan-gds:
	$(MAKE) docs-test-plan DOCS=docs/modules/gds DOCS_TEST_SUITE=gds

docs-test-gds:
	$(MAKE) docs-test DOCS=docs/modules/gds DOCS_TEST_SUITE=gds

docs-test-plan-nccl:
	$(MAKE) docs-test-plan DOCS=docs/modules/nccl DOCS_TEST_SUITE=nccl

docs-test-nccl:
	$(MAKE) docs-test DOCS=docs/modules/nccl DOCS_TEST_SUITE=nccl

docs-test-plan-dataloader:
	$(MAKE) docs-test-plan DOCS=docs/modules/dataloader DOCS_TEST_SUITE=dataloader

docs-test-dataloader:
	$(MAKE) docs-test DOCS=docs/modules/dataloader DOCS_TEST_SUITE=dataloader

docs-test-plan-ddp:
	$(MAKE) docs-test-plan DOCS=docs/modules/ddp DOCS_TEST_SUITE=ddp

docs-test-ddp:
	$(MAKE) docs-test DOCS=docs/modules/ddp DOCS_TEST_SUITE=ddp
	$(REPO_PY) tests/scripts/check-ddp-report-shape-fixture.py

docs-test-plan-hpl-mxp:
	$(MAKE) docs-test-plan DOCS=docs/modules/hpl-mxp DOCS_TEST_SUITE=hpl-mxp

docs-test-hpl-mxp:
	$(MAKE) docs-test DOCS=docs/modules/hpl-mxp DOCS_TEST_SUITE=hpl-mxp

docs-test-plan-elbencho:
	$(MAKE) docs-test-plan DOCS=docs/modules/elbencho DOCS_TEST_SUITE=elbencho

docs-test-elbencho:
	$(MAKE) docs-test DOCS=docs/modules/elbencho DOCS_TEST_SUITE=elbencho
	$(REPO_PY) tests/scripts/check-elbencho-report-shape-fixture.py

check-artifact-policy:
	bash scripts/report/check-artifact-policy.sh

validate-benchmark-campaign-registry:
	$(REPO_PY) scripts/report/validate-benchmark-campaign-registry.py

system-verify: setup verify
ifeq ($(APPLY),1)
	$(MAKE) archive-verify CLUSTER=$(CLUSTER) DATE=$(DATE) ARCHIVE_ROTATE=$(ARCHIVE_ROTATE)
	$(MAKE) render CLUSTER=$(CLUSTER) DATE=$(DATE)
	$(MAKE) validate-reports CLUSTER=$(CLUSTER) DATE=$(DATE)
else
	@echo "System verification dry run complete. Re-run with APPLY=1 to archive, render, and validate."
endif

daily-verify:
	@echo "daily-verify is deprecated; use system-verify for benchmark-day system state capture."
	$(MAKE) system-verify CLUSTER=$(CLUSTER) DATE=$(DATE) APPLY=$(APPLY) PROFILE=$(PROFILE) REPEAT_COUNT=$(REPEAT_COUNT) REPEAT_AGGREGATION=$(REPEAT_AGGREGATION) GPU_PREFLIGHT_FILTER=$(GPU_PREFLIGHT_FILTER) ARCHIVE_ROTATE=$(ARCHIVE_ROTATE)

benchmark-readiness-nccl:
	@echo "benchmark-readiness-nccl is deprecated; use verify-nccl-suite or system-verify."
	$(MAKE) verify-nccl-suite CLUSTER=$(CLUSTER) DATE=$(DATE) APPLY=$(APPLY) PROFILE=$(PROFILE) REPEAT_COUNT=$(REPEAT_COUNT) REPEAT_AGGREGATION=$(REPEAT_AGGREGATION) GPU_PREFLIGHT_FILTER=$(GPU_PREFLIGHT_FILTER) ARCHIVE_ROTATE=$(ARCHIVE_ROTATE)

benchmark-elbencho: require-settings
	ELBENCHO_TARGET_ROOT="$(ELBENCHO_TARGET_ROOT)" ELBENCHO_SIZE="$(ELBENCHO_SIZE)" ELBENCHO_BLOCK="$(ELBENCHO_BLOCK)" ELBENCHO_THREADS="$(ELBENCHO_THREADS)" ELBENCHO_IODEPTH="$(ELBENCHO_IODEPTH)" ELBENCHO_FILE_PATTERN="$(ELBENCHO_FILE_PATTERN)" ELBENCHO_FILES="$(ELBENCHO_FILES)" ELBENCHO_DIRS="$(ELBENCHO_DIRS)" bash scripts/benchmark/submit-elbencho.sh --cluster $(CLUSTER) --workload $(WORKLOAD) --profile $(ELBENCHO_PROFILE) --nodes $(NODES) --date $(NODE_REPORT_DATE) --cpus-per-task $(ELBENCHO_CPUS_PER_TASK) --mem $(ELBENCHO_MEM) $(ELBENCHO_GRES_FLAG) --time $(ELBENCHO_TIME) $(ELBENCHO_REPEAT_COUNT_FLAG) $(ELBENCHO_REPEAT_STAGGER_SECONDS_FLAG) $(ELBENCHO_DEPENDENCY_FLAG) $(FROM_NODE_REPORT_FLAG) $(NODELIST_FLAG) $(APPLY_FLAG)

benchmark-dataloader: require-settings
	bash scripts/benchmark/sweep-dataloader.sh \
		--cluster $(CLUSTER) \
		--nodes-list $(DATALOADER_NODES) \
		--gpu-count $(GPU_COUNT) \
		$(MODE_FLAG) \
		--date $(NODE_REPORT_DATE) \
		$(FROM_NODE_REPORT_FLAG) \
		$(NODELIST_FLAG) \
		--input-backend-list $(DATALOADER_INPUT_BACKENDS) \
		--batch-size-list $(DATALOADER_BATCH_SIZES) \
		--num-workers-list $(DATALOADER_NUM_WORKERS) \
		--prefetch-factor-list $(DATALOADER_PREFETCH_FACTORS) \
		--dali-num-threads-list $(DATALOADER_DALI_NUM_THREADS) \
		--dali-prefetch-queue-depth-list $(DATALOADER_DALI_PREFETCH_QUEUE_DEPTHS) \
		--dali-decode-mode-list $(DATALOADER_DALI_DECODE_MODES) \
		--dali-hw-decoder-load-list $(DATALOADER_DALI_HW_DECODER_LOADS) \
		--pin-memory-list $(DATALOADER_PIN_MEMORY) \
		--persistent-workers-list $(DATALOADER_PERSISTENT_WORKERS) \
		--cpus-per-task $(DATALOADER_CPUS_PER_TASK) \
		--repeat-count $(DATALOADER_REPEAT_COUNT) \
		$(DATALOADER_DEPENDENCY_FLAG) \
		$(APPLY_FLAG) \
		-- $(DATALOADER_RUN_ARGS)

benchmark-ddp-resnet50: require-settings
	DDP_SRUN_MPI="$(DDP_SRUN_MPI)" DDP_SRUN_CPU_BIND="$(DDP_SRUN_CPU_BIND)" DDP_SRUN_MEM_BIND="$(DDP_SRUN_MEM_BIND)" bash scripts/benchmark/submit-ddp-resnet50.sh --cluster $(CLUSTER) --nodes $(NODES) --launcher $(LAUNCHER) --date $(NODE_REPORT_DATE) --time $(DDP_TIME) --mem $(DDP_MEM) $(DDP_REPEAT_COUNT_FLAG) $(DDP_REPEAT_STAGGER_SECONDS_FLAG) $(FROM_NODE_REPORT_FLAG) $(NODELIST_FLAG) $(APPLY_FLAG) -- $(DDP_RUN_ARGS)

benchmark-ddp-launcher-comparison: require-settings
	bash scripts/benchmark/submit-ddp-launcher-comparison.sh --cluster $(CLUSTER) --date $(NODE_REPORT_DATE) --scales $(DDP_COMPARISON_SCALES) --time $(DDP_TIME) --mem $(DDP_MEM) --srun-mpi $(DDP_SRUN_MPI) --srun-cpu-bind $(if $(strip $(DDP_SRUN_CPU_BIND)),$(DDP_SRUN_CPU_BIND),none) --srun-mem-bind $(if $(strip $(DDP_SRUN_MEM_BIND)),$(DDP_SRUN_MEM_BIND),none) --submit-stagger-seconds $(DDP_COMPARISON_STAGGER_SECONDS) $(FROM_NODE_REPORT_FLAG) $(NODELIST_FLAG) $(DDP_COMPARISON_DEFAULT_SRUN_FLAG) $(APPLY_FLAG) -- $(DDP_RUN_ARGS)

benchmark-hpl-mxp: require-settings
	bash scripts/benchmark/submit-hpl-mxp.sh --cluster $(CLUSTER) --nodes $(NODES) --preset $(HPL_MXP_PRESET) --matrix-size $(HPL_MXP_MATRIX_SIZE) --nb $(HPL_MXP_NB) $(HPL_MXP_NPROW_FLAG) $(HPL_MXP_NPCOL_FLAG) $(HPL_MXP_AFFINITY_PROFILE_FLAG) --time $(HPL_MXP_TIME) $(HPL_MXP_MEM_FLAG) --sloppy-type $(HPL_MXP_SLOPPY_TYPE) $(HPL_MXP_TEST_LOOP_FLAG) $(HPL_MXP_REPEAT_COUNT_FLAG) $(HPL_MXP_REPEAT_STAGGER_SECONDS_FLAG) --date $(NODE_REPORT_DATE) $(FROM_NODE_REPORT_FLAG) $(NODELIST_FLAG) $(HPL_MXP_IMAGE_FLAG) $(HPL_MXP_CPUS_PER_TASK_FLAG) $(HPL_MXP_OMPI_COLL_FLAG) $(HPL_MXP_OMPI_PML_FLAG) $(HPL_MXP_OMPI_BTL_FLAG) $(HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE_FLAG) $(HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE_FLAG) $(HPL_MXP_UCX_TLS_FLAG) $(HPL_MXP_UCX_NET_DEVICES_FLAG) $(HPL_MXP_PMIX_MCA_GDS_FLAG) $(HPL_MXP_MPI_USE_MPI_FLAG) $(HPL_MXP_MPI_PANEL_BROADCAST_FLAG) $(HPL_MXP_PRIORITIZE_TRSM_FLAG) $(HPL_MXP_PRIORITIZE_FACTORIZATION_FLAG) $(HPL_MXP_ANQ_DEVICE_FLAG) $(HPL_MXP_FILL_DEVICE_FLAG) $(HPL_MXP_FILL_DEVICE_BUFFER_SIZE_FLAG) $(HPL_MXP_CALL_DGEMV_THREADS_FLAG) $(HPL_MXP_PRESET_GEMM_KERNEL_FLAG) $(HPL_MXP_CPU_AFFINITY_FLAG) $(HPL_MXP_MEM_AFFINITY_FLAG) $(HPL_MXP_UCX_AFFINITY_FLAG) $(HPL_MXP_U_PANEL_CHUNK_NBS_FLAG) $(HPL_MXP_SCALING_STUDY_FLAG) $(HPL_MXP_BASELINE_MATRIX_SIZE_FLAG) $(APPLY_FLAG)

benchmark-hpl-mxp-smoke:
	@echo "benchmark-hpl-mxp-smoke is a compatibility alias; use benchmark-hpl-mxp HPL_MXP_PRESET=smoke."
	$(MAKE) benchmark-hpl-mxp HPL_MXP_PRESET=smoke

install-elbencho: require-settings
	bash scripts/benchmark/install-elbencho-runtime.sh --method $(ELBENCHO_INSTALL_METHOD) --tag $(ELBENCHO_TAG) $(ELBENCHO_IMAGE_FLAG) $(APPLY_FLAG)

benchmark-dry-run-suite: require-settings
	bash scripts/benchmark/dry-run-suite.sh --cluster $(CLUSTER) --date $(NODE_REPORT_DATE) $(BENCHMARK_DRY_RUN_ELBENCHO_FLAG)

render-dataloader:
	$(REPO_PY) scripts/report/render-dataloader-report.py --date $(DATE) --cluster $(CLUSTER) --repeat-aggregation $(DATALOADER_REPEAT_AGGREGATION)

render-dataloader-b200: render-dataloader

render-ddp-resnet50:
	$(REPO_PY) scripts/report/render-ddp-resnet50-report.py --date $(DATE) --cluster $(CLUSTER)

render-ddp-resnet50-ascii:
	$(REPO_PY) scripts/report/render-ddp-resnet50-report.py --date $(DATE) --cluster $(CLUSTER) --ascii

render-hpl-mxp:
	$(REPO_PY) scripts/report/render-hpl-mxp-report.py --date $(DATE) --cluster $(CLUSTER) --repeat-aggregation $(REPEAT_AGGREGATION) $(HPL_MXP_RENDER_JOB_ID_MIN_FLAG) $(HPL_MXP_RENDER_JOB_ID_MAX_FLAG) $(HPL_MXP_RENDER_JOB_ID_LIST_FLAG)

render-benchmark-campaign:
	$(REPO_PY) scripts/report/render-benchmark-campaign.py --date $(DATE)

render-ddp-b200: render-ddp-resnet50

archive-benchmark-study-b200:
	bash scripts/report/archive-benchmark-study-results.sh --date $(DATE) --cluster $(CLUSTER)
