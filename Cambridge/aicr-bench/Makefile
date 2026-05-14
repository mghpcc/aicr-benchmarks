.PHONY: help require-settings doctor-python setup-python-local docs-link-check docs-test docs-test-plan install-containers install-containers-local verify-gds render-gds-ascii verify-nccl-suite render-nccl-suite benchmark-dataloader render-dataloader benchmark-ddp-resnet50 render-ddp-resnet50 render-ddp-resnet50-ascii benchmark-hpl-mxp benchmark-hpl-mxp-smoke render-hpl-mxp

CLUSTER ?= b200
PROFILE ?= small
DATE ?= today
APPLY ?= 0
REPEAT_COUNT ?= 1
REPEAT_AGGREGATION ?= standard
GDS_SUBMIT_STAGGER_SECONDS ?= 60
NCCL_SUBMIT_STAGGER_SECONDS ?= 5
NCCL_SURVEY_STAGGER_SECONDS ?= 0
NCCL_SCOPE ?= survey
NCCL_SUITE_OPS ?=
NCCL_SUITE_CLASS ?=
NCCL_NODES_PER_JOB ?=
NCCL_SURVEY_SIZES ?= 1
NCCL_ALLOW_NONSTANDARD_NODE_COUNT ?= 0
NCCL_DEBUG ?=
NCCL_DEBUG_SUBSYS ?=
NCCL_DEBUG_FILE ?=
ROUND_STAGGER_SECONDS ?= 60
NODELIST ?=
NODES ?= 1
GPU_COUNT ?= 1
MODE ?=
DATALOADER_NODES ?= $(NODES)
DATALOADER_BATCH_SIZES ?= 256
DATALOADER_NUM_WORKERS ?= 8
DATALOADER_PREFETCH_FACTORS ?= 4
DATALOADER_PIN_MEMORY ?= 1
DATALOADER_PERSISTENT_WORKERS ?= 1
DATALOADER_REPEAT_COUNT ?= 1
DATALOADER_REPEAT_AGGREGATION ?= $(REPEAT_AGGREGATION)
DATALOADER_CPUS_PER_TASK ?= 16
DATALOADER_RUN_ARGS ?=
DDP_NODES ?= $(NODES)
DDP_LAUNCHER ?= torchrun
DDP_CPUS_PER_TASK ?=
DDP_RUN_ARGS ?=
HPL_MXP_PRESET ?= smoke
HPL_MXP_MATRIX_SIZE ?= auto
HPL_MXP_NB ?= auto
HPL_MXP_NPROW ?= auto
HPL_MXP_NPCOL ?= auto
HPL_MXP_TIME ?= 00:30:00
HPL_MXP_IMAGE ?=
HPL_MXP_SLOPPY_TYPE ?= 2
HPL_MXP_TEST_LOOP ?=
HPL_MXP_CPUS_PER_TASK ?= 16
HPL_MXP_OMPI_COLL ?= ^ucc
HPL_MXP_PMIX_MCA_GDS ?= ^ds12
HPL_MXP_MPI_USE_MPI ?= 0
HPL_MXP_MPI_PANEL_BROADCAST ?= 1
HPL_MXP_PRIORITIZE_TRSM ?= 0
HPL_MXP_PRIORITIZE_FACTORIZATION ?= 0
HPL_MXP_ANQ_DEVICE ?=
HPL_MXP_FILL_DEVICE ?=
HPL_MXP_FILL_DEVICE_BUFFER_SIZE ?=
HPL_MXP_CALL_DGEMV_THREADS ?=
HPL_MXP_CPU_AFFINITY ?=
HPL_MXP_MEM_AFFINITY ?=
HPL_MXP_SCALING_STUDY ?= exploratory
HPL_MXP_TARGET_GPU_MEMORY_PCT ?=
HPL_MXP_BASELINE_MATRIX_SIZE ?=
DOCS_APPLY ?= 0
DOCS_SUITE ?= all
DOCS_TEST_ID ?=
CONTAINER_REFRESH ?= 0
CONTAINER_PARTITION ?= GPU1
CONTAINER_NODELIST ?=
CONTAINER_TIME ?= 04:00:00
CONTAINER_WAIT ?= 1
REPO_PY ?= bash scripts/lib/run-repo-python.sh
DOCS_PY ?= python3

APPLY_FLAG := $(if $(filter 1,$(APPLY)),--apply,)
DOCS_APPLY_FLAG := $(if $(filter 1,$(DOCS_APPLY)),--apply,)
DOCS_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodelist $(NODELIST),)
DOCS_TEST_ID_FLAG := $(if $(strip $(DOCS_TEST_ID)),--test-id $(DOCS_TEST_ID),)
REPEAT_AGGREGATION_FLAG := --repeat-aggregation $(REPEAT_AGGREGATION)
GDS_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodes $(NODELIST),)
NCCL_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodes $(NODELIST),)
NCCL_SUITE_CLASS_FLAG := $(if $(strip $(NCCL_SUITE_CLASS)),--suite-class $(NCCL_SUITE_CLASS),)
NCCL_NODES_PER_JOB_FLAG := $(if $(strip $(NCCL_NODES_PER_JOB)),--nodes-per-job $(NCCL_NODES_PER_JOB),)
NCCL_SURVEY_SIZES_FLAG := $(if $(filter survey,$(NCCL_SCOPE)),$(if $(strip $(NCCL_SURVEY_SIZES)),--survey-sizes $(NCCL_SURVEY_SIZES),),)
NCCL_SURVEY_STAGGER_SECONDS_FLAG := $(if $(filter survey,$(NCCL_SCOPE)),--survey-stagger-seconds $(NCCL_SURVEY_STAGGER_SECONDS),)
NCCL_ALLOW_NONSTANDARD_NODE_COUNT_FLAG := $(if $(filter 1,$(NCCL_ALLOW_NONSTANDARD_NODE_COUNT)),--allow-nonstandard-node-count,)
NCCL_SUITE_OPS_ENV := $(if $(strip $(NCCL_SUITE_OPS)),NCCL_SUITE_OPS=$(NCCL_SUITE_OPS),)
NCCL_DEBUG_ENV := $(if $(strip $(NCCL_DEBUG)),NCCL_DEBUG=$(NCCL_DEBUG),)
NCCL_DEBUG_SUBSYS_ENV := $(if $(strip $(NCCL_DEBUG_SUBSYS)),NCCL_DEBUG_SUBSYS=$(NCCL_DEBUG_SUBSYS),)
NCCL_DEBUG_FILE_ENV := $(if $(strip $(NCCL_DEBUG_FILE)),NCCL_DEBUG_FILE=$(NCCL_DEBUG_FILE),)
DATALOADER_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodelist $(NODELIST),)
DATALOADER_MODE_FLAG := $(if $(strip $(MODE)),--mode $(MODE),)
DDP_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodelist $(NODELIST),)
DDP_CPUS_PER_TASK_FLAG := $(if $(strip $(DDP_CPUS_PER_TASK)),--cpus-per-task $(DDP_CPUS_PER_TASK),)
HPL_MXP_NODELIST_FLAG := $(if $(strip $(NODELIST)),--nodelist $(NODELIST),)
HPL_MXP_IMAGE_FLAG := $(if $(strip $(HPL_MXP_IMAGE)),--image $(HPL_MXP_IMAGE),)
HPL_MXP_TEST_LOOP_FLAG := $(if $(strip $(HPL_MXP_TEST_LOOP)),--test-loop $(HPL_MXP_TEST_LOOP),)
HPL_MXP_CPUS_PER_TASK_FLAG := $(if $(strip $(HPL_MXP_CPUS_PER_TASK)),--cpus-per-task $(HPL_MXP_CPUS_PER_TASK),)
HPL_MXP_NPROW_FLAG := $(if $(strip $(HPL_MXP_NPROW)),--nprow $(HPL_MXP_NPROW),)
HPL_MXP_NPCOL_FLAG := $(if $(strip $(HPL_MXP_NPCOL)),--npcol $(HPL_MXP_NPCOL),)
HPL_MXP_ANQ_DEVICE_FLAG := $(if $(strip $(HPL_MXP_ANQ_DEVICE)),--anq-device $(HPL_MXP_ANQ_DEVICE),)
HPL_MXP_FILL_DEVICE_FLAG := $(if $(strip $(HPL_MXP_FILL_DEVICE)),--fill-device $(HPL_MXP_FILL_DEVICE),)
HPL_MXP_FILL_DEVICE_BUFFER_SIZE_FLAG := $(if $(strip $(HPL_MXP_FILL_DEVICE_BUFFER_SIZE)),--fill-device-buffer-size $(HPL_MXP_FILL_DEVICE_BUFFER_SIZE),)
HPL_MXP_CALL_DGEMV_THREADS_FLAG := $(if $(strip $(HPL_MXP_CALL_DGEMV_THREADS)),--call-dgemv-with-multiple-threads $(HPL_MXP_CALL_DGEMV_THREADS),)
HPL_MXP_CPU_AFFINITY_FLAG := $(if $(strip $(HPL_MXP_CPU_AFFINITY)),--cpu-affinity $(HPL_MXP_CPU_AFFINITY),)
HPL_MXP_MEM_AFFINITY_FLAG := $(if $(strip $(HPL_MXP_MEM_AFFINITY)),--mem-affinity $(HPL_MXP_MEM_AFFINITY),)
HPL_MXP_TARGET_GPU_MEMORY_PCT_FLAG := $(if $(strip $(HPL_MXP_TARGET_GPU_MEMORY_PCT)),--target-gpu-memory-pct $(HPL_MXP_TARGET_GPU_MEMORY_PCT),)
HPL_MXP_BASELINE_MATRIX_SIZE_FLAG := $(if $(strip $(HPL_MXP_BASELINE_MATRIX_SIZE)),--baseline-matrix-size $(HPL_MXP_BASELINE_MATRIX_SIZE),)
CONTAINER_REFRESH_FLAG := $(if $(filter 1,$(CONTAINER_REFRESH)),--refresh,)
CONTAINER_NODELIST_FLAG := $(if $(strip $(CONTAINER_NODELIST)),--nodelist $(CONTAINER_NODELIST),)
CONTAINER_WAIT_FLAG := $(if $(filter 0,$(CONTAINER_WAIT)),--no-wait,)
REPORT_DATE := $(shell if [ "$(DATE)" = "today" ]; then date -u +%F; else printf '%s' "$(DATE)"; fi)

help:
	@printf '%s\n' \
		"AICR-Bench Cambridge interface" \
		"" \
		"GDS:" \
		"  make verify-gds CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large>" \
		"      Dry-run GDS Slurm submissions across currently idle nodes." \
		"  make verify-gds CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> NODELIST=<node>" \
		"      Limit GDS Slurm submissions to one node or a comma-separated node list." \
		"  make verify-gds CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> APPLY=1" \
		"      Submit GDS jobs and render a report after completion." \
		"  make verify-gds CLUSTER=<b200|rtxpro6000> PROFILE=custom NODELIST=<node> AICR_GDS_CUSTOM_GDSIO_ARGS='<args>' APPLY=1" \
		"      Submit one custom gdsio command. The script owns the target file by default." \
		"  make render-gds-ascii CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Print the GDS ASCII dashboard from existing results." \
		"NCCL:" \
		"  make verify-nccl-suite NCCL_SCOPE=local CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> NODELIST=<node>" \
		"      Dry-run one-node local NCCL checks with IB disabled." \
		"  make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=<node> NCCL_SUITE_CLASS=b200_1proc_8g APPLY=1" \
		"      Submit the B200 single-process, 8-GPU local check." \
		"  make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=<node> NCCL_SUITE_CLASS=b200_2rank_socket_4g APPLY=1" \
		"      Submit the B200 two-process, 4-GPU-per-process NUMA/socket-pinned local check." \
		"  make verify-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 PROFILE=small NODELIST=<node> NCCL_SUITE_CLASS=rtx_pair_policy APPLY=1" \
		"      Submit the RTX two-GPU P2P pair-policy check." \
		"  make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=<b200|rtxpro6000> PROFILE=small NODELIST=<nodes> NCCL_NODES_PER_JOB=<2|4|8|16> APPLY=1" \
		"      Submit explicit multi-node RDMA checks. RTX supports 2/4/8; B200 supports 2/4/8/16." \
		"  make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=<nodes> NCCL_NODES_PER_JOB=31 NCCL_SUITE_OPS=allreduce NCCL_ALLOW_NONSTANDARD_NODE_COUNT=1 APPLY=1" \
		"      Submit an expert AllReduce diagnostic node count outside the public ladder." \
		"  make verify-nccl-suite NCCL_SCOPE=survey CLUSTER=<b200|rtxpro6000> PROFILE=small NODELIST=<nodes> NCCL_SURVEY_SIZES=1,2 APPLY=1" \
		"      Submit rank-per-GPU NCCL survey groups for candidate-node discovery." \
		"  make render-nccl-suite CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Print the NCCL suite Markdown dashboard from existing results." \
		"" \
		"DataLoader:" \
		"  make benchmark-dataloader CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> GPU_COUNT=<1|8> MODE=<single|replicated|distributed-sharded> NODELIST=<node[,node...]>" \
		"      Dry-run PyTorch DataLoader submissions against AICR_IMAGENET_DIR." \
		"  make benchmark-dataloader CLUSTER=rtxpro6000 GPU_COUNT=1 MODE=single NODELIST=<node> APPLY=1 DATALOADER_RUN_ARGS='<args>'" \
		"      Submit one explicit RTX single-GPU DataLoader job." \
		"  make render-dataloader CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Print the DataLoader Markdown dashboard from existing results." \
		"" \
		"DDP:" \
		"  make benchmark-ddp-resnet50 CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> DDP_NODES=<1|2|4|8|16> NODELIST=<node[,node...]>" \
		"      Dry-run fixed-iteration PyTorch DDP ResNet-50 submissions." \
		"  make benchmark-ddp-resnet50 CLUSTER=rtxpro6000 DDP_NODES=1 NODELIST=<node> APPLY=1 DDP_RUN_ARGS='<args>'" \
		"      Submit one explicit RTX DDP ResNet-50 teaching job." \
		"  make render-ddp-resnet50 CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Print the DDP ResNet-50 Markdown summary from existing results." \
		"  make render-ddp-resnet50-ascii CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Print the DDP ResNet-50 ASCII dashboard from existing results." \
		"" \
		"HPL-MxP:" \
		"  make benchmark-hpl-mxp CLUSTER=<b200|rtxpro6000> NODES=<1|2|4|8|16> NODELIST=<node[,node...]>" \
		"      Dry-run an NVIDIA HPL-MxP submission through the HPC Benchmarks container." \
		"  make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=<node> HPL_MXP_PRESET=campaign-candidate HPL_MXP_TEST_LOOP=10 APPLY=1" \
		"      Submit the reviewed single-node B200 campaign-candidate shape." \
		"  make benchmark-hpl-mxp-smoke CLUSTER=<b200|rtxpro6000> NODES=1 NODELIST=<node> APPLY=1" \
		"      Submit a small HPL-MxP smoke row before larger shapes." \
		"  make render-hpl-mxp CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>" \
		"      Render the HPL-MxP Markdown campaign report from existing results." \
		"" \
		"Python helpers:" \
		"  make setup-python-local" \
		"  make doctor-python" \
		"" \
		"Executable documentation:" \
		"  make docs-link-check" \
		"      Check that prose script mentions link to man pages." \
		"  make docs-test" \
		"      Run local and dry-run executable documentation checks." \
		"  make docs-test DOCS_APPLY=1 NODELIST=<node>" \
		"      Also allow applied one-node Slurm documentation checks." \
		"  make docs-test-plan" \
		"      Print selected documentation checks without running them." \
		"" \
		"Runtime containers for later modules:" \
		"  make install-containers" \
		"      Submit the default container install as a Slurm job on CONTAINER_PARTITION=GPU1." \
		"  make install-containers CONTAINER_NODELIST=<node>" \
		"      Submit the container install to a specific RTX node." \
		"  make install-containers CONTAINER_REFRESH=1" \
		"      Rebuild/replace the default images through the same Slurm path." \
		"  make install-containers CONTAINER_WAIT=0" \
		"      Submit and return immediately; monitor with squeue and results/setup logs."

require-settings:
	@settings_file="$${AICR_SETTINGS_FILE:-benchmark-settings.env}"; \
	if [ ! -f "$$settings_file" ]; then \
		printf '%s\n' "ERROR: $$settings_file not found in $$(pwd)." >&2; \
		printf '%s\n' "Create it first: cp benchmark-settings.env.example benchmark-settings.env" >&2; \
		exit 2; \
	fi

doctor-python:
	bash scripts/setup/doctor-python.sh

setup-python-local:
	bash scripts/setup/setup-python-local.sh

docs-link-check:
	$(DOCS_PY) scripts/docs/check-public-docs.py
	$(DOCS_PY) scripts/docs/check-man-links.py

docs-test: docs-link-check
	$(DOCS_PY) scripts/docs/aicr-doctest.py --suite $(DOCS_SUITE) --cluster $(CLUSTER) $(DOCS_NODELIST_FLAG) $(DOCS_TEST_ID_FLAG) $(DOCS_APPLY_FLAG) run

docs-test-plan:
	$(DOCS_PY) scripts/docs/aicr-doctest.py --suite $(DOCS_SUITE) --cluster $(CLUSTER) $(DOCS_NODELIST_FLAG) $(DOCS_TEST_ID_FLAG) $(DOCS_APPLY_FLAG) plan

install-containers: require-settings
	bash scripts/setup/submit-container-install.sh \
		--partition $(CONTAINER_PARTITION) \
		--time $(CONTAINER_TIME) \
		$(CONTAINER_NODELIST_FLAG) \
		$(CONTAINER_REFRESH_FLAG) \
		$(CONTAINER_WAIT_FLAG)

install-containers-local:
	bash apptainer/pull/pull-verified-containers.sh $(CONTAINER_REFRESH_FLAG)

verify-gds: require-settings
	bash scripts/verify/submit-gds-fleet.sh \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		$(GDS_NODELIST_FLAG) \
		--repeat-count $(REPEAT_COUNT) \
		$(REPEAT_AGGREGATION_FLAG) \
		--submit-stagger-seconds $(GDS_SUBMIT_STAGGER_SECONDS) \
		--round-stagger-seconds $(ROUND_STAGGER_SECONDS) \
		$(APPLY_FLAG)

render-gds-ascii:
	$(REPO_PY) scripts/report/render-verify-dashboard.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --check gds --ascii

verify-nccl-suite: require-settings
	env $(NCCL_SUITE_OPS_ENV) $(NCCL_DEBUG_ENV) $(NCCL_DEBUG_SUBSYS_ENV) $(NCCL_DEBUG_FILE_ENV) \
		bash scripts/verify/submit-nccl-fleet.sh \
		--scope $(NCCL_SCOPE) \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		$(NCCL_NODELIST_FLAG) \
		$(NCCL_SUITE_CLASS_FLAG) \
		$(NCCL_NODES_PER_JOB_FLAG) \
		$(NCCL_SURVEY_SIZES_FLAG) \
		$(NCCL_ALLOW_NONSTANDARD_NODE_COUNT_FLAG) \
		--repeat-count $(REPEAT_COUNT) \
		$(REPEAT_AGGREGATION_FLAG) \
		--submit-stagger-seconds $(NCCL_SUBMIT_STAGGER_SECONDS) \
		$(NCCL_SURVEY_STAGGER_SECONDS_FLAG) \
		--round-stagger-seconds $(ROUND_STAGGER_SECONDS) \
		$(APPLY_FLAG)

render-nccl-suite:
	$(REPO_PY) scripts/report/render-nccl-suite-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --scope $(NCCL_SCOPE) $(NCCL_NODES_PER_JOB_FLAG) $(REPEAT_AGGREGATION_FLAG)

benchmark-dataloader: require-settings
	bash scripts/benchmark/sweep-dataloader.sh \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		--nodes-list $(DATALOADER_NODES) \
		--gpu-count $(GPU_COUNT) \
		$(DATALOADER_MODE_FLAG) \
		$(DATALOADER_NODELIST_FLAG) \
		--batch-size-list $(DATALOADER_BATCH_SIZES) \
		--num-workers-list $(DATALOADER_NUM_WORKERS) \
		--prefetch-factor-list $(DATALOADER_PREFETCH_FACTORS) \
		--pin-memory-list $(DATALOADER_PIN_MEMORY) \
		--persistent-workers-list $(DATALOADER_PERSISTENT_WORKERS) \
		--cpus-per-task $(DATALOADER_CPUS_PER_TASK) \
		--repeat-count $(DATALOADER_REPEAT_COUNT) \
		$(APPLY_FLAG) \
		-- $(DATALOADER_RUN_ARGS)

render-dataloader:
	$(REPO_PY) scripts/report/render-dataloader-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --repeat-aggregation $(DATALOADER_REPEAT_AGGREGATION)

benchmark-ddp-resnet50: require-settings
	bash scripts/benchmark/submit-ddp-resnet50.sh \
		--cluster $(CLUSTER) \
		--profile $(PROFILE) \
		--nodes $(DDP_NODES) \
		--launcher $(DDP_LAUNCHER) \
		$(DDP_NODELIST_FLAG) \
		$(DDP_CPUS_PER_TASK_FLAG) \
		$(APPLY_FLAG) \
		-- $(DDP_RUN_ARGS)

render-ddp-resnet50:
	$(REPO_PY) scripts/report/render-ddp-resnet50-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER)

render-ddp-resnet50-ascii:
	$(REPO_PY) scripts/report/render-ddp-resnet50-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER) --ascii

benchmark-hpl-mxp: require-settings
	bash scripts/benchmark/submit-hpl-mxp.sh \
		--cluster $(CLUSTER) \
		--nodes $(NODES) \
		--preset $(HPL_MXP_PRESET) \
		--matrix-size $(HPL_MXP_MATRIX_SIZE) \
		--nb $(HPL_MXP_NB) \
		$(HPL_MXP_NPROW_FLAG) \
		$(HPL_MXP_NPCOL_FLAG) \
		--time $(HPL_MXP_TIME) \
		$(HPL_MXP_IMAGE_FLAG) \
		--sloppy-type $(HPL_MXP_SLOPPY_TYPE) \
		$(HPL_MXP_TEST_LOOP_FLAG) \
		$(HPL_MXP_CPUS_PER_TASK_FLAG) \
		--ompi-coll $(HPL_MXP_OMPI_COLL) \
		--pmix-mca-gds $(HPL_MXP_PMIX_MCA_GDS) \
		--mpi-use-mpi $(HPL_MXP_MPI_USE_MPI) \
		--use-mpi-panel-broadcast $(HPL_MXP_MPI_PANEL_BROADCAST) \
		--prioritize-trsm $(HPL_MXP_PRIORITIZE_TRSM) \
		--prioritize-factorization $(HPL_MXP_PRIORITIZE_FACTORIZATION) \
		--scaling-study $(HPL_MXP_SCALING_STUDY) \
		$(HPL_MXP_ANQ_DEVICE_FLAG) \
		$(HPL_MXP_FILL_DEVICE_FLAG) \
		$(HPL_MXP_FILL_DEVICE_BUFFER_SIZE_FLAG) \
		$(HPL_MXP_CALL_DGEMV_THREADS_FLAG) \
		$(HPL_MXP_CPU_AFFINITY_FLAG) \
		$(HPL_MXP_MEM_AFFINITY_FLAG) \
		$(HPL_MXP_TARGET_GPU_MEMORY_PCT_FLAG) \
		$(HPL_MXP_BASELINE_MATRIX_SIZE_FLAG) \
		$(HPL_MXP_NODELIST_FLAG) \
		$(APPLY_FLAG)

benchmark-hpl-mxp-smoke: require-settings
	bash scripts/benchmark/submit-hpl-mxp.sh \
		--cluster $(CLUSTER) \
		--nodes $(NODES) \
		--preset smoke \
		--time $(HPL_MXP_TIME) \
		$(HPL_MXP_IMAGE_FLAG) \
		$(HPL_MXP_TEST_LOOP_FLAG) \
		$(HPL_MXP_CPUS_PER_TASK_FLAG) \
		$(HPL_MXP_NODELIST_FLAG) \
		$(APPLY_FLAG)

render-hpl-mxp:
	$(REPO_PY) scripts/report/render-hpl-mxp-report.py --results-root results --date $(REPORT_DATE) --cluster $(CLUSTER)
