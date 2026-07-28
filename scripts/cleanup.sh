#!/bin/bash
helm uninstall vprofile -n vprofile || true
kubectl delete namespace vprofile --ignore-not-found
