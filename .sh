apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-deploy-cluster-role
rules:
# Quyền xem namespaces
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]

# Quyền deploy applications
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Quyền xem và tạo basic resources
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Quyền quản lý ingress
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Quyền xem events (để troubleshoot)
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-deployer-cluster-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-deploy-cluster-role
subjects:
- kind: ServiceAccount
  name: jenkins-deployer
  namespace: personal

  apiVersion: v1
kind: Secret
metadata:
  name: jenkins-deployer-token
  namespace: personal
  annotations:
    kubernetes.io/service-account.name: jenkins-deployer
type: kubernetes.io/service-account-token

apiVersion: v1
kind: Secret
metadata:
  name: jenkins-deployer-token
  namespace: personal
  annotations:
    kubernetes.io/service-account.name: jenkins-deployer
type: kubernetes.io/service-account-token