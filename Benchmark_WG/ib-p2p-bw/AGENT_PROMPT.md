
Follow the meta behavior instructions in /Users/cnh/projects/agent_general_rules/karpathy_keep_it_simple.md

I want you to make a plan for testing point to point bandwidth between GPU servers on an infiniband network.

The servers all have 8 B200 NVidia GPU cards.

The servers are configured on a rail optimized NDR infiniband network

Each GPU has an associated direct PCIe network card that can be identified by the command "nvidia-smi topoi -m"

The GPU cards have 400Gb/s NDR uplinks to the leaf switches

The cluster has 31 8-way nodes called b0001 - b0031

The following markdown files show the building blocks of how to generate one point to point test


      read_command_example.md

     write_command_example.md

     salloc_example.md

The nodes used b0025 and b0026 are just an example.
The network device, mlx5_0, is dependent 

I want you to create some tools for automatically testing all the links in the cluster and measuring their 
point to point bandwidth.

As a start make a plan for creating a SLURM sbatch script driver that take as arguments a specifiction of which
pair nodes to use for point to point and which GPUs with each node.

The script should capture the results in a sub-directory structure with different inner sub0directories for each node and gpu to node and gpu pairing and dated
output files within that.

If possible the script should also record the IB network switch path between the endpoints being tested.

The script will run on a shared HPC cluster with regular account privileges. If something is not available to an unprivileged account
don't do stupid tests like "can yum install work" or "does su work". That will just waste everyones time with irritating security alerts and
is rude - be polite and act like a respectful human would, not like a blundering fool.

**Documentation discipline.** After any change that adds, removes, or
alters a user-visible feature (a new script, a new flag, a renamed
argument, a changed default, a moved output path), update the markdown
docs in the same change: top-level `README.md`, `bin/README.md`, and any
affected file under `provenance/`. If a `provenance/` file disagrees
with the code afterwards, the code is right and the provenance file is
stale -- fix it now, not later. Do not "improve" the example files
(`read_command_example.md`, `write_command_example.md`,
`salloc_example.md`) in passing; only edit them when explicitly asked.
The pinned external rule snapshots under `provenance/agent_guidance/`
are read-only references -- if a rule needs to change, update upstream
and re-import.

Follow the meta behavior instructions in /Users/cnh/projects/agent_general_rules/karpathy_keep_it_simple.md


