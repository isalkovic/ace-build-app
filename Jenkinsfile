node {
    checkout scm

    docker.withRegistry('https://158.176.129.209:8500/', 'docker') {

    stage "Build"
        def aceImage = docker.build("158.176.129.209:8500/default/my-ace-image:${env.BUILD_ID}, "-f Dockerfile")

        /* Push the container to the custom Registry */
        aceImage.push()
    
    input 'Do you want to proceed with Deployment to ICP?'
    stage "Deploy"

        sh "kubectl set image deployment/ivo-ace-demo-app demochart=158.176.129.209:8500/default/my-ace-image:${env.BUILD_ID}"
        sh "kubectl rollout status deployment/ivo-ace-demo-app"
    }
}

