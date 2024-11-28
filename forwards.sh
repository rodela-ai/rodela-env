#!/bin/bash

# kafka broker
export POD_NAME=$(kubectl get pods --namespace rodela -l "app.kubernetes.io/instance=kafka" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace rodela port-forward $POD_NAME 9092:9092 &