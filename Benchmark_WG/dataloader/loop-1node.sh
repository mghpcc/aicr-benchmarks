FLAGS="-N 1 --mem-per-cpu=4G --exclusive"

for mode in read write; do
   #for ncpus in 1 8 32 64 96; do
   for ncpus in 128; do
       for part in rtx-batch b200-batch; do
          TAG="1node_${ncpus}cpu_${part}"
          mkdir -p "output/$TAG"
          sbatch $FLAGS -J $mode -o "output/$TAG/%x_%N_%j.out" --ntasks-per-node=$ncpus -p $part job.sh $mode $TAG
       done
   done
done

      #for host in `cat ~/benchmarks/nodes.b200`; do
      #   sbatch $FLAGS -J $mode --ntasks-per-node=$ncpus -p b200-batch -w $host job.sh $mode
      #done
      #for host in `cat ~/benchmarks/nodes.rtx6000`; do
      #   sbatch $FLAGS -J $mode --ntasks-per-node=$ncpus -p rtx-batch -w $host job.sh $mode
      #done
