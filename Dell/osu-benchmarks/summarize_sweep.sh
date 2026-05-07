#!/bin/bash
# Parse all-pairs sweep results and print a pass/fail table.
# Called automatically by run_sweep.sh, or run manually on a results directory.
#
# Usage: bash summarize_sweep.sh <results_dir> [threshold_hh_mbs]

RESULTS_DIR="${1:-.}"
THRESHOLD_HH="${2:-80000}"

if [[ ! -d "${RESULTS_DIR}" ]]; then
    echo "ERROR: Results directory not found: ${RESULTS_DIR}"
    exit 1
fi

mapfile -t OUT_FILES < <(find "${RESULTS_DIR}" -maxdepth 1 -name "*.out" ! -name "summary.out" | sort)

if [[ ${#OUT_FILES[@]} -eq 0 ]]; then
    echo "No result files found in ${RESULTS_DIR}"
    exit 1
fi

PASS=0
FAIL=0

echo "========================================================"
echo " OSU BIBW Sweep Summary"
echo " Results dir : ${RESULTS_DIR}"
echo " H H thresh  : >= ${THRESHOLD_HH} MB/s"
echo " Generated   : $(date)"
echo "========================================================"
echo

printf "%-36s  %18s  %s\n" "Node Pair" "H H Peak (MB/s)" "Status"
printf "%-36s  %18s  %s\n" "------------------------------------" "------------------" "-------"

FAIL_DETAILS=()

for out_file in "${OUT_FILES[@]}"; do
    PAIR_LABEL=$(grep -m1 "^=== PAIR:" "${out_file}" 2>/dev/null | sed 's/=== PAIR: //;s/ ===//' || true)
    [[ -z "${PAIR_LABEL}" ]] && PAIR_LABEL=$(basename "${out_file}" .out)

    HH_BW=$(awk '
        /--- H H ---/ { in_hh=1; next }
        in_hh && /^[[:space:]]*[0-9]/ { if ($2+0 > max) max=$2+0 }
        END { printf "%.2f", max+0 }
    ' "${out_file}")

    STATUS="PASS"
    REASON=""

    if [[ "${HH_BW}" == "0.00" ]]; then
        STATUS="FAIL"
        REASON="H H: no data (job may have crashed)"
        HH_BW="MISSING"
        (( FAIL++ )) || true
    else
        HH_OK=$(awk -v bw="${HH_BW}" -v t="${THRESHOLD_HH}" 'BEGIN{print (bw >= t) ? "yes" : "no"}')
        if [[ "${HH_OK}" == "no" ]]; then
            STATUS="FAIL"
            REASON="H H ${HH_BW} < ${THRESHOLD_HH}"
            (( FAIL++ )) || true
        else
            (( PASS++ )) || true
        fi
    fi

    if [[ "${STATUS}" == "PASS" ]]; then
        printf "%-36s  %18s  %s\n" "${PAIR_LABEL}" "${HH_BW}" "PASS"
    else
        printf "%-36s  %18s  %s  (%s)\n" "${PAIR_LABEL}" "${HH_BW}" "FAIL" "${REASON}"
        FAIL_DETAILS+=("${PAIR_LABEL}: ${REASON}")
    fi
done

TOTAL=$(( PASS + FAIL ))

echo
echo "========================================================"
echo " RESULT: ${PASS} / ${TOTAL} PASS   |   ${FAIL} FAIL"
echo "========================================================"

if [[ ${FAIL} -gt 0 ]]; then
    echo
    echo "── Failed pairs ──────────────────────────────────────"
    for detail in "${FAIL_DETAILS[@]}"; do
        echo "  FAIL: ${detail}"
    done

    echo
    echo "── Node failure frequency ────────────────────────────"
    printf '%s\n' "${FAIL_DETAILS[@]}" | \
        grep -oP '[\w-]+(?= <->| \(|:)' | \
        sort | uniq -c | sort -rn | \
        awk '$1>0{printf "  %3d failed pairs: %s\n", $1, $2}'
fi

echo
