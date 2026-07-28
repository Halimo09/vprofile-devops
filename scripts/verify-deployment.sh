#!/bin/bash
set -e
kubectl get nodes
kubectl get pods -A
kubectl get svc -n vprofile
kubectl get ingress -n vprofile
helm list -n vprofile
echo "Verification complete."
