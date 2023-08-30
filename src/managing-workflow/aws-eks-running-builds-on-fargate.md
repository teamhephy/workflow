# AWS EKS: Running Builds on AWS Fargate

EKS is an AWS managed Kubernetes service that can be configured to run pods of a given namespace in [Fargate](https://aws.amazon.com/fargate/), a serverless container service.

This setup is particularly well-suited for running short-lived workloads such as Deis Workflow builds.

Advantages of using AWS Fargate for builds are:

- **No need for a dedicated node builder**: if you use the `BUILDER_POD_NODE_SELECTOR` environment variable in the `deis-builder` pod, there is no need to maintain a dedicated node builder that is only used during deployments.
- **Isolated builds**: When not using a dedicated node for builds, your builds will run in isolation without affecting other nodes. This ensures that your builds are performed independently and efficiently.
- **Cost-effective**: Since Fargate compute is used only for a short duration, it is very cost-effective to have a powerful instance running your builds.

## Prerequisites

Before proceeding with running builds on AWS Fargate, ensure that you have the following prerequisites in place:

1. **Running EKS cluster**: Set up and configure an EKS cluster. Make sure it is up and running.
2. **Deis installed**: Install Deis on your EKS cluster. Follow the appropriate documentation for Deis installation.
3. **Fargate ready to be used**: Ensure that Fargate is properly configured and ready to be used with your EKS cluster. Refer to the [official AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html) for instructions on setting up Fargate profiles.

For the purpose of this guide, we will assume that the Fargate profile selects pods in the `deis-builder` namespace. However, you can choose any desired namespace name according to your requirements.

## Create the Namespace

To begin, you need to create the namespace where the `slugbuild` pods will run. Run the following command to create the `deis-builder` namespace using `kubectl`:

```shell
kubectl create namespace deis-builder
```

This command will create the `deis-builder` namespace in your Kubernetes cluster.

## Configuring `slugbuild` Pods to Run in a different namespace

To make Deis run `slugbuild` pods in the `deis-builder` namespace, you need to modify the `POD_NAMESPACE` environment variable in the `deis-builder` deployment. By default, it inherits the namespace of the deployment, but we can set it to spawn pods inside the `deis-builder` namespace.

Here's an example of how to set the `POD_NAMESPACE` environment variable in the `deis-builder` deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deis-builder
  # ...
spec:
  template:
    spec:
      containers:
        - name: deis-builder
          # ...
          env:
            - name: POD_NAMESPACE
              value: deis-builder
```

Make sure to update the `deis-builder` deployment YAML file with the above configuration. This will ensure that the `slugbuild` pods are spawned inside the `deis-builder` namespace.

## Granting Authorization for `slugbuild` Pods in the New Namespace

To ensure that `slugbuild` pods can run in the new `deis-builder` namespace, you need to allow the `deis-builder` service account to create pods in that namespace. This can be achieved through RBAC (Role-Based Access Control) authorization.

Create a file named `rbac.yaml` and add the following content to it:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deis-builder-fargate
  namespace: deis-builder
rules:
 - apiGroups:
   - ""
   resources:
   - secrets
   verbs:
   - create
   - update
   - delete
 - apiGroups:
   - ""
   resources:
   - pods
   verbs:
   - create
   - get
   - watch
   - list
 - apiGroups:
   - ""
   resources:
   - pods/log
   verbs:
   - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deis-builder-fargate
  namespace: deis-builder
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deis-builder-fargate
subjects:
- kind: ServiceAccount
  name: deis-builder
  namespace: deis
```

Save the file and then apply the RBAC authorization rules using the following command:

```shell
kubectl apply -f rbac.yaml
```

This will grant the necessary permissions to the `deis-builder` service account in the `deis-builder` namespace.

## Duplicating Secrets in the New Namespace

To make the secrets available in the `deis-builder` namespace, you need to duplicate them from the default `deis` namespace. Follow these steps:

1. Create a file named `secrets.yaml` and add the following content to it:

```yaml
apiVersion: v1
data:
  builder-key: TO_REPLACE
kind: Secret
metadata:
  name: builder-key-auth
  namespace: deis-builder
type: Opaque
---
apiVersion: v1
data:
  ssh-host-ecdsa-key: TO_REPLACE
  ssh-host-rsa-key: TO_REPLACE
kind: Secret
metadata:
  name: builder-ssh-private-keys
  namespace: deis-builder
type: Opaque
---
apiVersion: v1
data:
 accesskey: TO_REPLACE
 builder-bucket: TO_REPLACE
 database-bucket: TO_REPLACE
 region: TO_REPLACE
 registry-bucket: TO_REPLACE
 secretkey: TO_REPLACE
kind: Secret
metadata:
 annotations:
   deis.io/objectstorage: s3
 name: objectstorage-keyfile
 namespace: deis-builder
type: Opaque
```

2. Replace the `TO_REPLACE` placeholders in the file with the actual values of the secrets. You can find the secrets in the default `deis` namespace using the following command:

```shell
kubectl get secret builder-key-auth -n deis -o jsonpath='{.data}'
```

3. Apply the secrets to the new namespace using the following command:

```shell
kubectl apply -f secrets.yaml
```

This will create the secrets in the `deis-builder` namespace, making them available for use by the `slugbuild` pods.

## Setting Up Capacity for the `slugbuild` Pod

By default, Fargate runs `slugbuild` pods with the lowest available capacities for CPU and memory. To change this behavior, you can set a default capacity for all pods spawned into the `deis-builder` namespace by creating a limit range.

Follow these steps to set up the capacity for the `slugbuild` pod:

1. Create a file named `limit-range.yaml` and add the following content to it:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: deis-builder-defaults
  namespace: deis-builder
spec:
  limits:
  - default:
      defaultRequest:
        memory: 32Gi
        cpu: 16
    type: Container
```

2. Adjust the `defaultRequest` values (`memory` and `cpu`) according to your requirements.

3. Apply the limit range to the `deis-builder` namespace using the following command:

```shell
kubectl apply -f limit-range.yaml
```

This will set the default capacity for all containers in the `deis-builder` namespace, including the `slugbuild` pods.


## Cleanup operator

Fargate computes will have the same lifecycle than the pods in the `deis-builder` namespace. Deis doesn't destroy `slugbuild` pods after a deployment, that means that fargate compute won't be automatically cleaned up.

To fix this, we can rely on the `[kube-cleanup-operator](https://github.com/lwolf/kube-cleanup-operator)`. You can install it with `helm` and run it with these argument:

```
args:
  - --namespace=deis-builder
  - --delete-successful-after=0
  - --delete-failed-after=120m
  - --delete-pending-pods-after=0
  - --delete-evicted-pods-after=0
  - --delete-orphaned-pods-after=2m
  - --legacy-mode=false
```

Pods in the `deis-builder` namespace will be cleaned up automatically 2 minutes after the build complete.

## Cleanup Operator for Fargate Compute

When using Fargate compute for the `slugbuild` pods in the `deis-builder` namespace, the Fargate compute instances will have the same lifecycle as the pods. However, Deis does not automatically destroy the `slugbuild` pods after a deployment, which means that the Fargate compute instances won't be cleaned up automatically.

To address this, you can rely on the [kube-cleanup-operator](https://github.com/lwolf/kube-cleanup-operator). You can install it using Helm and run it with the following arguments:

```yaml
args:
  - --namespace=deis-builder
  - --delete-successful-after=0
  - --delete-failed-after=120m
  - --delete-pending-pods-after=0
  - --delete-evicted-pods-after=0
  - --delete-orphaned-pods-after=2m
  - --legacy-mode=false
```

With these arguments, the kube-cleanup-operator will automatically clean up pods in the `deis-builder` namespace based on the specified time intervals. In this case, pods will be cleaned up 2 minutes after the build completes.

Please note that you need to install the kube-cleanup-operator using Helm and provide the appropriate values for the arguments mentioned above.
