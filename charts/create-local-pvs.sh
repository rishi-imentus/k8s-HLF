#!/bin/bash

# Create directory for persistent volumes data
mkdir -p /mnt/data/hyperledger

# Get a worker node name to place the volumes
WORKER_NODE=$(kubectl get nodes | grep worker | head -n 1 | awk '{print $1}')

# Get all pending PVCs in the namespace
kubectl get pvc -n supplychain-net -o jsonpath='{range .items[?(@.status.phase=="Pending")]}{.metadata.name}{" "}{.spec.storageClassName}{" "}{.spec.resources.requests.storage}{"\n"}{end}' | while read -r PVC_NAME STORAGE_CLASS_NAME STORAGE_SIZE; do
  # Create a matching PV for each PVC
  cat <<PV_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-${PVC_NAME}
spec:
  capacity:
    storage: ${STORAGE_SIZE}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${STORAGE_CLASS_NAME}
  local:
    path: /mnt/data/hyperledger/${PVC_NAME}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${WORKER_NODE}
PV_EOF

  echo "Created PV for ${PVC_NAME} with storage class ${STORAGE_CLASS_NAME}"
  
  # Create the directory on the worker node
  mkdir -p /mnt/data/hyperledger/${PVC_NAME}
done
