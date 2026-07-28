#!/bin/bash
kubectl rollout status deployment/vprofile-app -n vprofile
kubectl get endpoints -n vprofile
