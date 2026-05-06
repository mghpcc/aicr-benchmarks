# minmum cpus per task -c 2, best -c 8, for the timer/progress tokio tasks
sbatch -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU2 job.sh
sbatch -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU1 job.sh
