outdir="all-out"
for node in `cat nodes.b200`
do
   sbatch -w $node -o "$outdir/%N-%J.out" -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU2 job.sh
done

for node in `cat nodes.rtx6000`
do
   sbatch -w $node -o "$outdir/%N-%J.out" -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU1 job.sh
done


# minmum cpus per task -c 2, best -c 8, for the timer/progress tokio tasks
