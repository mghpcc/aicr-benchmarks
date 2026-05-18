FLAGS="--mem-per-cpu=4G --exclusive"

for mode in read write; do
   for Nnodes in 2 4 8 12; do
      for ncpus in 32 64 96; do
         for part in GPU1 GPU2; do
            TAG="${Nnodes}node_${ncpus}cpu_${part}"
            mkdir -p "output/$TAG"
            sbatch $FLAGS -J "$Nnodes-nodes-$mode" -o "output/$TAG/%x_%N_%j.out" -N $Nnodes --ntasks-per-node=$ncpus -p $part job.sh $mode $TAG
         done
      done
   done
done

