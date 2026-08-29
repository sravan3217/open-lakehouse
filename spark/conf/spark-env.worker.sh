#!/usr/bin/env bash
# =============================================================================
# spark-env.sh  --  spark-worker1 and spark-worker2 (identical on both)
# Path: /opt/spark/conf/spark-env.sh
# =============================================================================

# Master to register with.
export SPARK_MASTER_HOST='spark-manager'

# Resources this worker offers to the cluster. These are advertised
# capacities, not enforced limits -- keep them under what the VM actually
# has, or the OOM killer decides your job scheduling for you.
export SPARK_WORKER_CORES=3
export SPARK_WORKER_MEMORY=2G
