# Jenkins Setup with Kubernetes

## Mục lục
1. [Tạo Service Account cho Jenkins](#1-tạo-service-account-cho-jenkins)
2. [Thêm Credentials vào Jenkins](#2-thêm-credentials-vào-jenkins)
3. [Cập nhật API Server IP](#3-cập-nhật-api-server-ip)
4. [Test API Access](#4-test-api-access)
5. [Jenkins Pipeline](#5-jenkins-pipeline)

## 1. Tạo Service Account cho Jenkins

### Bước 1.1: SSH vào K8s master node
```bash
ssh root@192.168.1.111
```

### Bước 1.2: Tạo service account
```bash
kubectl create serviceaccount jenkins-deployer -n personal
```

### Bước 1.3: Cấp quyền edit cho namespace personal
```bash
kubectl create rolebinding jenkins-deployer-binding \
  --clusterrole=edit \
  --serviceaccount=personal:jenkins-deployer \
  --namespace=personal
```

### Bước 1.4: Tạo token (lưu lại token này)
```bash
kubectl create token jenkins-deployer -n personal --duration=8760h
```

**Token được tạo:**
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IlhYcy1xWW9nNEN3SFJMTUxMcWN0eEw4NnFxdk93MGE4V2hsc3lKT3h2Tm8ifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzgzOTI1Mjg4LCJpYXQiOjE3NTIzODkyODgsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiYzc0NGMxMzEtNzljNi00YzVkLWE5ZDQtNWIwODkxMWNhNGM2Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJwZXJzb25hbCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJqZW5raW5zLWRlcGxveWVyIiwidWlkIjoiZThhYmI1NTAtMWQ5Zi00OGJkLTgyZGQtODNjYzQzYjk1NjcxIn19LCJuYmYiOjE3NTIzODkyODgsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpwZXJzb25hbDpqZW5raW5zLWRlcGxveWVyIn0.ey777n2iE-m-gSBJJkFU18M-mUElhgX1RBCNweDUkMaGxhN88mb6hjD6Hjw7FkNqplILJPkl9YixDJ2qIOYGGG6iQlohsiwGThcINHLqfrQocKGXg7-E7V-8YzFJ4VAV59FhVflZwA4ErjK_gpQY9P70FkOHyAx5mLHHHWcMYz8c8WawXgnIXxpR7IU2trPXaG0OxELAv_GBYXiWsqAqkix7codMjXJMG7ueLiii27gfF_Jo0CmgI97gqO-M0DbYH-EEV5FhKMsqYzzQ3QsVFKbLqBGw_pm67AqfqvCTTjx7LgyFvcWaiwrFRh3eo0X0NKYbiDeYbTq1jbjS66QKfw
```

## 2. Thêm Credentials vào Jenkins

### Bước 2.1: Truy cập Jenkins Dashboard
Vào Jenkins Dashboard → Manage Jenkins → Credentials

### Bước 2.2: Add Credentials
Thêm credential với thông tin sau:
- **Kind**: Secret text
- **ID**: k8s-token
- **Secret**: Paste token từ bước 1.4
- **Description**: Kubernetes Token for Jenkins

## 3. Cập nhật API Server IP

### Bước 3.1: Kiểm tra IP của master node
```bash
kubectl cluster-info
```

Hoặc:
```bash
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

### Bước 3.2: Cập nhật trong Jenkinsfile
```groovy
K8S_API_SERVER = 'https://192.168.1.111:6443'  // Your actual master IP
```

## 4. Test API Access

### Test từ Jenkins server (hoặc máy có thể access K8s)
```bash
TOKEN="your-token-here"
curl -H "Authorization: Bearer $TOKEN" \
  https://192.168.1.111:6443/api/v1/namespaces/personal/pods \
  --insecure
```

## 5. Jenkins Pipeline

### 5.1: Discord Notification Function
```groovy
def notifyDiscord(channel, chatId, message) {
    sh """
        curl --location --request POST "https://discord.com/api/webhooks/${channel}/${chatId}" \
        --header 'Content-Type: application/json' \
        --data-raw '{"content": "${message}"}'
    """
}
```

### 5.2: Complete Jenkins Pipeline
```groovy
pipeline {
    agent any

    environment {
        ENVIRONMENT = 'personal'
        SERVICE = 'portfolio'

        REGISTRY_DOMAIN_NAME = 'harbor.ngtantai.pro'
        REGISTRY_USERNAME = 'admin'
        REGISTRY_PASSWORD = credentials('registryPassword')

        // K8s Configuration
        K8S_NAMESPACE = 'personal'
        K8S_DEPLOYMENT_NAME = 'portfolio-deployment'
        K8S_CONTAINER_NAME = 'portfolio'
        K8S_API_SERVER = 'https://192.168.1.111:6443'
        K8S_TOKEN = credentials('k8s-token')
        
        DOCKER_EXPOSE_PORT = '80'
        APP_TEMP_PORT = '8080'
        APP_FINAL_PORT = '80'
        
        TEXT_START = "⚪ Service ${SERVICE} ${ENVIRONMENT} Build Started"
        TEXT_BUILD_AND_PUSH_APP_FAIL = "🔴 Service ${SERVICE} ${ENVIRONMENT} Build and Push Failed"
        TEXT_DEPLOY_APP_FAIL = "🔴 Service ${SERVICE} ${ENVIRONMENT} Deploy Failed"
        TEXT_CLEANUP_OLD_IMAGES_FAIL = "🔴 Cleanup Old Images Failed"
        TEXT_END = "🟢 Service ${SERVICE} ${ENVIRONMENT} Build and Deploy Finished"

        DISCORD_CHANNEL = '1382725588321828934'
        DISCORD_CHAT_ID = 'Q1edE75TA7jJlloegQ2MxDpBxAGoVFz0buoSwW-wg6mTLozxP20oagKFlRiN5l1fyCOQ'
    }

    stages {
        stage('Notify Build Started') {
            steps {
                script {
                    def causes = currentBuild.getBuildCauses()
                    def triggerInfo = causes ? causes[0].shortDescription : "Unknown"
                    def cleanTrigger = triggerInfo.replaceFirst("Started by ", "")
                    notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, "${env.TEXT_START} by ${cleanTrigger}.")
                }
            }
        }

        stage('Pull Code') {
            steps {
                script {
                    echo "Now Jenkins is pulling code..." 
                    checkout scm
                    echo "Now Jenkins is listing code..."
                    sh "ls -la ${WORKSPACE}"
                    sh "find ${WORKSPACE} -name 'Dockerfile' -type f || echo 'Dockerfile not found'"
                }
            }
        }

        stage('Build App Image') {
            steps {
                script {
                    try {
                        def timestamp = new Date().format('yyMMdd-HHmmss')
                        env.DOCKER_APP_IMAGE_NAME = "${env.REGISTRY_DOMAIN_NAME}/${env.ENVIRONMENT}/${env.SERVICE}:${timestamp}"

                        sh "docker build -t ${env.DOCKER_APP_IMAGE_NAME} -f ${WORKSPACE}/Dockerfile ${WORKSPACE}"

                        echo "✅ Successfully built APP: ${env.DOCKER_APP_IMAGE_NAME}"                    
                    } catch (Exception e) {
                        notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, env.TEXT_BUILD_AND_PUSH_APP_FAIL)
                        error("APP build failed: ${e.getMessage()}")
                    }
                }
            }
        }

        stage('Push App Image') {
            steps {
                script {
                    try {
                        sh "echo ${env.REGISTRY_PASSWORD} | docker login ${env.REGISTRY_DOMAIN_NAME} -u ${env.REGISTRY_USERNAME} --password-stdin"
                        sh "docker push ${env.DOCKER_APP_IMAGE_NAME}"
                        sh "docker rmi ${env.DOCKER_APP_IMAGE_NAME} || true"
                        echo "✅ Successfully pushed APP: ${env.DOCKER_APP_IMAGE_NAME}"                    
                    } catch (Exception e) {
                        notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, env.TEXT_BUILD_AND_PUSH_APP_FAIL)
                        error("APP push failed: ${e.getMessage()}")
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    try {
                        echo "🚀 Deploying new image to K8s: ${env.DOCKER_APP_IMAGE_NAME}"
                        
                        // Simple one-line JSON patch
                        def patchData = '{"spec":{"template":{"spec":{"containers":[{"name":"' + env.K8S_CONTAINER_NAME + '","image":"' + env.DOCKER_APP_IMAGE_NAME + '"}]}}}}'
                        
                        // Deploy with proper error handling
                        def deployResult = sh(
                            script: """
                                curl -X PATCH \\
                                    -H "Authorization: Bearer ${env.K8S_TOKEN}" \\
                                    -H "Content-Type: application/strategic-merge-patch+json" \\
                                    -d '${patchData}' \\
                                    "${env.K8S_API_SERVER}/apis/apps/v1/namespaces/${env.K8S_NAMESPACE}/deployments/${env.K8S_DEPLOYMENT_NAME}" \\
                                    --insecure \\
                                    --silent \\
                                    --show-error \\
                                    --fail
                            """,
                            returnStatus: true
                        )
                        
                        if (deployResult != 0) {
                            error("Failed to update deployment. HTTP status: ${deployResult}")
                        }
                        
                        echo "✅ Successfully triggered K8s deployment update"
                        
                    } catch (Exception e) {
                        notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, env.TEXT_DEPLOY_APP_FAIL)
                        error("Kubernetes deployment failed: ${e.getMessage()}")
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    try {
                        echo "🔍 Verifying deployment health..."
                        
                        // Wait for rollout with timeout
                        timeout(time: 5, unit: 'MINUTES') {
                            script {
                                def ready = false
                                def attempts = 0
                                def maxAttempts = 30
                                
                                while (!ready && attempts < maxAttempts) {
                                    attempts++
                                    
                                    // Simple check without jq dependency
                                    def result = sh(
                                        script: """
                                            curl -s -H "Authorization: Bearer ${env.K8S_TOKEN}" \\
                                                "${env.K8S_API_SERVER}/apis/apps/v1/namespaces/${env.K8S_NAMESPACE}/deployments/${env.K8S_DEPLOYMENT_NAME}" \\
                                                --insecure | grep -o '"readyReplicas":[0-9]*' | cut -d':' -f2 || echo '0'
                                        """,
                                        returnStdout: true
                                    ).trim()
                                    
                                    // Handle empty result
                                    if (result == "" || result == null) {
                                        result = "0"
                                    }
                                    
                                    def readyReplicas = result as Integer
                                    echo "Attempt ${attempts}/${maxAttempts}: Ready replicas: ${readyReplicas}"
                                    
                                    if (readyReplicas >= 1) {
                                        ready = true
                                        echo "✅ Deployment is ready with ${readyReplicas} replica(s)"
                                        
                                        // Quick endpoint test
                                        sh """
                                            curl -f -m 10 http://192.168.1.111:30080 -H "Host: portfolio.ngtantai.pro" >/dev/null 2>&1 || \\
                                            curl -f -m 10 http://192.168.1.112:30080 -H "Host: portfolio.ngtantai.pro" >/dev/null 2>&1 || \\
                                            curl -f -m 10 http://192.168.1.113:30080 -H "Host: portfolio.ngtantai.pro" >/dev/null 2>&1
                                        """
                                        echo "✅ Endpoint health check passed"
                                        
                                    } else {
                                        echo "⏳ Waiting for deployment to be ready..."
                                        sleep(10)
                                    }
                                }
                                
                                if (!ready) {
                                    error("Deployment failed to become ready after ${maxAttempts} attempts")
                                }
                            }
                        }
                        
                    } catch (Exception e) {
                        notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, "🟡 Deployment completed but verification failed: ${e.getMessage()}")
                        echo "⚠️ Verification failed but deployment may still be successful: ${e.getMessage()}"
                        // Don't fail the build on verification issues
                    }
                }
            }
        }

        stage('Cleanup Old Images') {
            steps {
                script {
                    try {
                        sh "docker image prune -a -f --filter \"until=24h\" || true"

                        sh """
                            docker images ${env.REGISTRY_DOMAIN_NAME}/${env.ENVIRONMENT}/${env.SERVICE} \\
                            --format "{{.Repository}}:{{.Tag}}\\t{{.CreatedAt}}" \\
                            | tail -n +2 | sort -k2 -r | tail -n +3 | awk '{print \$1}' \\
                            | xargs -r docker rmi || true
                        """

                        echo "✅ Successfully cleaned up old images"
                        
                    } catch (Exception e) {
                        notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, env.TEXT_CLEANUP_OLD_IMAGES_FAIL)
                        echo "⚠️ Cleanup failed but deployment was successful: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Notify Build Finished') {
            steps {
                script {
                    notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, "${env.TEXT_END}\\n🖼️ Image: \`${env.DOCKER_APP_IMAGE_NAME}\`\\n🔗 https://portfolio.ngtantai.pro")
                }
            }
        }
    }

    post {
        failure {
            script {
                notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, "🔴 Pipeline failed for ${env.SERVICE} ${env.ENVIRONMENT}\\nBuild: #${currentBuild.number}")
            }
        }
        success {
            script {
                notifyDiscord(env.DISCORD_CHANNEL, env.DISCORD_CHAT_ID, "🎉 Successfully deployed ${env.SERVICE} to production!\\n🔗 https://portfolio.ngtantai.pro\\n🖼️ \`${env.DOCKER_APP_IMAGE_NAME}\`")
            }
        }
    }
}
```

## Tóm tắt Pipeline Stages

1. **Notify Build Started**: Thông báo bắt đầu build qua Discord
2. **Pull Code**: Kéo code từ repository
3. **Build App Image**: Build Docker image với timestamp
4. **Push App Image**: Push image lên Harbor registry
5. **Deploy to Kubernetes**: Deploy image mới lên K8s cluster
6. **Verify Deployment**: Kiểm tra deployment có thành công không
7. **Cleanup Old Images**: Dọn dẹp các images cũ
8. **Notify Build Finished**: Thông báo hoàn thành qua Discord

## Lưu ý quan trọng

- Token K8s có thời hạn 8760 giờ (1 năm)
- Pipeline sử dụng Harbor registry tại `harbor.ngtantai.pro`
- Deployment target là namespace `personal`
- Có Discord notification cho từng stage
- Tự động cleanup old images sau 24h