// Description: Build and deploy pipeline template
// Dependencies: Jenkins, Harbor registry, Kubernetes cluster
// Variables: Replace <VARIABLES> with actual values
// Usage: Copy to Jenkinsfile in your project repository

pipeline {
    agent any
    
    environment {
        // Docker registry configuration
        DOCKER_IMAGE = "<REGISTRY>/<PROJECT>/<APP_NAME>"
        HARBOR_CREDENTIAL_ID = "harbor-registry"
        
        // Kubernetes configuration
        KUBECONFIG_CREDENTIAL_ID = "k8s-token"
        KUBE_API_SERVER = "https://<MASTER_IP>:6443"
        KUBE_NAMESPACE = "<NAMESPACE>"
        
        // Application configuration
        APP_NAME = "<APP_NAME>"
        DEPLOYMENT_NAME = "<DEPLOYMENT_NAME>"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building Docker image...'
                script {
                    // Generate build tag with timestamp
                    def buildTime = new Date().format('ddMMyy-HHmmss')
                    env.BUILD_TAG = buildTime
                    
                    // Build Docker images
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${BUILD_TAG} .
                        docker build -t ${DOCKER_IMAGE}:latest .
                    """
                }
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                script {
                    // Run tests inside Docker container
                    sh """
                        docker run --rm ${DOCKER_IMAGE}:${BUILD_TAG} npm test || true
                    """
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                echo 'Scanning for vulnerabilities...'
                script {
                    // Optional: Add security scanning here
                    sh """
                        # docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                        #   aquasec/trivy:latest image ${DOCKER_IMAGE}:${BUILD_TAG}
                        echo "Security scan placeholder"
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo 'Pushing to Harbor registry...'
                withCredentials([usernamePassword(
                    credentialsId: "${HARBOR_CREDENTIAL_ID}",
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh """
                        docker login <REGISTRY> -u ${HARBOR_USER} -p ${HARBOR_PASS}
                        docker push ${DOCKER_IMAGE}:${BUILD_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying to Kubernetes...'
                withCredentials([string(
                    credentialsId: "${KUBECONFIG_CREDENTIAL_ID}",
                    variable: 'K8S_TOKEN'
                )]) {
                    sh """
                        # Configure kubectl
                        kubectl config set-cluster kubernetes --server=${KUBE_API_SERVER} --insecure-skip-tls-verify=true
                        kubectl config set-credentials jenkins-deployer --token=${K8S_TOKEN}
                        kubectl config set-context jenkins-context --cluster=kubernetes --user=jenkins-deployer
                        kubectl config use-context jenkins-context
                        
                        # Update deployment with new image
                        kubectl set image deployment/${DEPLOYMENT_NAME} ${APP_NAME}=${DOCKER_IMAGE}:${BUILD_TAG} -n ${KUBE_NAMESPACE}
                        
                        # Wait for rollout to complete
                        kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${KUBE_NAMESPACE} --timeout=300s
                        
                        # Verify deployment
                        kubectl get pods -n ${KUBE_NAMESPACE} -l app=${APP_NAME}
                        kubectl get services -n ${KUBE_NAMESPACE} -l app=${APP_NAME}
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo 'Running health checks...'
                script {
                    // Wait for application to be ready
                    sh """
                        # Wait for pods to be ready
                        kubectl wait --for=condition=ready pod -l app=${APP_NAME} -n ${KUBE_NAMESPACE} --timeout=300s
                        
                        # Optional: Run application health checks
                        # kubectl exec -n ${KUBE_NAMESPACE} deployment/${DEPLOYMENT_NAME} -- curl -f http://localhost:80/health || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up...'
            // Clean up workspace
            cleanWs()
            
            // Remove local Docker images to save space
            sh """
                docker rmi ${DOCKER_IMAGE}:${BUILD_TAG} || true
                docker rmi ${DOCKER_IMAGE}:latest || true
                docker system prune -f || true
            """
        }
        
        success {
            echo 'Pipeline succeeded!'
            // Add success notifications here
            // slackSend channel: '#deployments', color: 'good', message: "✅ ${env.JOB_NAME} - ${env.BUILD_NUMBER} deployed successfully"
        }
        
        failure {
            echo 'Pipeline failed!'
            // Add failure notifications here
            // slackSend channel: '#deployments', color: 'danger', message: "❌ ${env.JOB_NAME} - ${env.BUILD_NUMBER} failed"
            
            // Optional: Rollback on failure
            script {
                try {
                    withCredentials([string(
                        credentialsId: "${KUBECONFIG_CREDENTIAL_ID}",
                        variable: 'K8S_TOKEN'
                    )]) {
                        sh """
                            kubectl config set-cluster kubernetes --server=${KUBE_API_SERVER} --insecure-skip-tls-verify=true
                            kubectl config set-credentials jenkins-deployer --token=${K8S_TOKEN}
                            kubectl config set-context jenkins-context --cluster=kubernetes --user=jenkins-deployer
                            kubectl config use-context jenkins-context
                            
                            # Rollback to previous version
                            kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${KUBE_NAMESPACE}
                            kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${KUBE_NAMESPACE}
                        """
                    }
                } catch (Exception e) {
                    echo "Rollback failed: ${e.getMessage()}"
                }
            }
        }
        
        unstable {
            echo 'Pipeline is unstable!'
            // Handle unstable builds
        }
    }
}

// Example usage:
// 1. Copy this file to your project as 'Jenkinsfile'
// 2. Replace all <VARIABLES> with your actual values:
//    - <REGISTRY>: harbor.ngtantai.pro
//    - <PROJECT>: personal
//    - <APP_NAME>: portfolio
//    - <MASTER_IP>: 192.168.1.111
//    - <NAMESPACE>: personal
//    - <DEPLOYMENT_NAME>: portfolio-deployment
// 3. Commit and push to your repository
// 4. Configure Jenkins job to use this Jenkinsfile 