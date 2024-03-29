import com.cloudbees.groovy.cps.NonCPS
import java.io.File
import java.util.UUID
import groovy.json.JsonOutput;
import groovy.json.JsonSlurperClassic;

def build = (env.BUILD ?: "true").toBoolean()
def deploy = (env.DEPLOY ?: "true").toBoolean()
def test = (env.TEST ?: "true").toBoolean()

def image = (env.IMAGE ?: "ace-cont-adopt").trim()
def dockerimage = (env.DOCKER_TRIGGER_REPO_NAME ?: "ibmcom/ace:latest").trim()
printTime("***** ${dockerimage} *****")
def baseimage = (env.DOCKER_TRIGGER_REPO_NAME ?: "ibmcom/ace:latest").trim()
def basetag = (env.DOCKER_TRIGGER_TAG ?: "latest").trim()

def alwaysPullImage = (env.ALWAYS_PULL_IMAGE == null) ? true : env.ALWAYS_PULL_IMAGE.toBoolean()
def libertyLicenseJarBaseUrl = (env.LIBERTY_LICENSE_JAR_BASE_URL ?: "").trim()
def registry = (env.REGISTRY ?: "icptest.icp:8500").trim()
if (registry && !registry.endsWith('/')) registry = "${registry}/"
def registrySecret = (env.REGISTRY_SECRET ?: "registrysecret").trim()
def dockerUser = (env.DOCKER_USER ?: "").trim()
def dockerPassword = (env.DOCKER_PASSWORD ?: "").trim()
def namespace = (env.NAMESPACE ?: "default").trim()
def serviceAccountName = (env.SERVICE_ACCOUNT_NAME ?: "default").trim()
def chartFolder = (env.CHART_FOLDER ?: "chart").trim()
def helmSecret = (env.HELM_SECRET ?: "helm-secret").trim()
def helmTlsOptions = " --tls --tls-ca-cert=/msb_helm_sec/ca.pem --tls-cert=/msb_helm_sec/cert.pem --tls-key=/msb_helm_sec/key.pem " 

def volumes = [ hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock') ]
if (registrySecret) {
  volumes += secretVolume(secretName: registrySecret, mountPath: '/msb_reg_sec')
}
if (helmSecret) {
    volumes += secretVolume(secretName: helmSecret, mountPath: '/msb_helm_sec')
}

podTemplate(
    label: 'test',
    containers: [
        containerTemplate(name: 'maven', image: 'maven:3.6.0-jdk-8-alpine', ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'docker', image: 'docker:18.06.1-ce', command: 'cat', ttyEnabled: true,
            envVars: [
                containerEnvVar(key: 'DOCKER_API_VERSION', value: '1.23.0')
            ]),
        containerTemplate(name: 'kubectl', image: 'ibmcom/microclimate-utils:1901', ttyEnabled: true, command: 'cat'),
        // containerTemplate(name: 'helm', image: 'ibmcom/microclimate-k8s-helm:v2.12.3', ttyEnabled: true, command: 'cat')
	containerTemplate(name: 'helm', image: 'icptest.icp:8500/ibmcom/helm:1.0.0', ttyEnabled: true, command: 'cat')
    ],
    volumes: volumes
    ) 

    {
      node('test'){
	    def gitCommit
            def previousCommit
            def gitCommitMessage
            def fullCommitID
	    
	    def imageTag = null

	    def slackResponse = slackSend(channel: "k8s_cont-adoption", message: "*$JOB_NAME*: <$BUILD_URL|Build #$BUILD_NUMBER> Has been started.")
            
// ==============================================================================================================
	 stage ('Get code and config from Git') {
	             try {
                  checkout scm
                  fullCommitID = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                  gitCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                  previousCommitStatus = sh(script: 'git rev-parse -q --short HEAD~1', returnStatus: true)      
                  // If no previous commit is found, below commands need not run but build should continue
                  // Only run when a previous commit exists to avoid pipeline fail on exit code
                  if (previousCommitStatus == 0){ 
                     previousCommit = sh(script: 'git rev-parse -q --short HEAD~1', returnStdout: true).trim()
                     echo "Previous commit exists: ${previousCommit}"
                  }
                  gitCommitMessage = sh(script: 'git log --format=%B -n 1 ${gitCommit}', returnStdout: true)
	                gitCommitMessage = gitCommitMessage.replace("'", "\'");
                  echo "Git commit message is: ${gitCommitMessage}"
                  echo "Checked out git commit ${gitCommit}"
               } catch(Exception ex) {
                  print "Error in Extract: " + ex.toString()
               }
	          }

// ==============================================================================================================
	stage('SCAN base ACE image') {
          container ('docker') {
		def imageLine = "${baseimage}:${basetag}"
  		writeFile file: 'anchore_images', text: imageLine
 		anchore name: 'anchore_images'
		}
  	        slackSend (channel: slackResponse.threadId, color: '#199515', message: "*$JOB_NAME*: <$BUILD_URL|Build #$BUILD_NUMBER> scanned successfully.")
 	}
	      
// ==============================================================================================================
	      
        stage('Build ACE docker image'){
	             try {
                  // checkout scm
                  container('docker') {
		     echo "Setting Base Image info in Dockerfile to :: ${baseimage}:${basetag}"
		     sh "sed -i '1s_^FROM.*_FROM ${baseimage}:${basetag}_' Dockerfile"
		     sh "cat Dockerfile"
		
                  echo 'Start Building Image'
		     
		  imageTag = "${basetag}"
                  def buildCommand = "docker build -t ${image}:${imageTag} "
                  buildCommand += "--label org.label-schema.schema-version=\"1.0\" "
                  // def scmUrl = scm.getUserRemoteConfigs()[0].getUrl()
                  // buildCommand += "--label org.label-schema.vcs-url=\"${scmUrl}\" "
                  buildCommand += "--label org.label-schema.vcs-ref=\"${imageTag}\" "  
                  buildCommand += "--label org.label-schema.name=\"${image}\" "
                  def buildDate = sh(returnStdout: true, script: "date -Iseconds").trim()
                  buildCommand += "--label org.label-schema.build-date=\"${buildDate}\" "
                  if (alwaysPullImage) {
                        buildCommand += " --pull=true"
                  }
                  if (previousCommit) {
                        buildCommand += " --cache-from ${registry}${image}:${previousCommit}"
                  }
                    
                  buildCommand += " ."

                  if (registrySecret) {
                        sh "ln -s -f /msb_reg_sec/.dockercfg /home/jenkins/.dockercfg"
                        sh "mkdir -p /home/jenkins/.docker"
                        sh "ln -s -f /msb_reg_sec/.dockerconfigjson /home/jenkins/.docker/config.json"
                  }
                  sh buildCommand

                  if (registry) {
		                  // sh "docker login -u=${dockerUser} -p=${dockerPassword} ${registry}"
			                echo "Tagging image ${image}:${imageTag} ${registry}${namespace}/${image}:${imageTag}"
                      sh "docker tag ${image}:${imageTag} ${registry}${namespace}/${image}:${imageTag}"
		                  echo 'Pushing to Docker registry'
                      sh "docker push ${registry}${namespace}/${image}:${imageTag}"
		                  echo 'Done pushing to Docker registry'
                  }
		           }
              } catch(Exception ex) {
                   print "Error in Docker build: " + ex.toString()
	              }
            }
	    
	          def realChartFolder = null
            def testsAttempted = false
	    
            if (fileExists(chartFolder)) {
               // find the likely chartFolder location
               realChartFolder = getChartFolder('ibm-ace', chartFolder)
               def yamlContent = "image:"
               yamlContent += "\n  repository: ${registry}${namespace}/${image}"
               if (imageTag) yamlContent += "\n  tag: \\\"${imageTag}\\\""
               sh "echo \"${yamlContent}\" > pipeline.yaml"
            }
	      
// ==============================================================================================================
	stage ('Deploy ACE to k8s') {
	       echo'Deploy helm chart'
         echo "testing against namespace " + namespace
         String tempHelmRelease = (image + "-" + namespace)

               container ('kubectl') {
	                echo 'In kubectl container'
               }
               
               container ('helm') {
                 // Check if the release exists at all.
                 isReleaseExists = sh(script: "helm list -q --namespace ${namespace} ${helmTlsOptions} | tr '\\n' ','", returnStdout: true)
		             echo "::::Checking if release " + tempHelmRelease + " exists... found " + isReleaseExists
                 if (isReleaseExists.contains("${tempHelmRelease}")) {
                   // The release exists, check it's status.
                   releaseStatus = sh(script: "helm status ${tempHelmRelease} -o json ${helmTlsOptions} | jq '.info.status.code'", returnStdout: true).trim()
			             echo "::::Helm release status is " + releaseStatus
                   if (releaseStatus != "1") {
                      // The release is in FAILED state. Attempt to rollback.
                      releaseRevision = sh (script: "helm history ${tempHelmRelease} ${helmTlsOptions} | tail -1 | awk '{ print \$1}'", returnStdout: true).trim()
                      echo "::::Helm release revision is " + releaseRevision
		        if (releaseRevision == "1") {
                        // This is the only revision available - purge and proceed to reinstall.
                        sh "helm del --purge ${tempHelmRelease} ${helmTlsOptions}"
                      } else {
                        // There is a previous revision, rollback to it.
                        releaseRevision = sh (script: "helm history ${tempHelmRelease} ${helmTlsOptions} | tail -2 | head -1 | awk '{ print \$1}'", returnStdout: true).trim()
                        sh "helm rollback ${tempHelmRelease} ${releaseRevision} ${helmTlsOptions}"
                      }
                  }
		  else {
		      echo "RELEASE IS RUNNING"
                      // The release is in RUNNING state. Attempt to upgrade
		      getValues = sh (script: "helm get values ${tempHelmRelease} --output yaml ${helmTlsOptions} > values.yaml", returnStatus: true)
                      def upgradeCommand = "helm upgrade ${tempHelmRelease} ${realChartFolder} --wait --values values.yaml --namespace ${namespace} --set=image.tag=${imageTag}"
                      if (fileExists("chart/overrides.yaml")) {
                        upgradeCommand += " --values chart/overrides.yaml"
                      }
                      if (helmSecret) {
                        echo "Adding --tls to your deploy command"
                        upgradeCommand += helmTlsOptions
                      }
		      echo "UPGRADING COMMAND: ${upgradeCommand}"
                      testUpgradeAttempt = sh(script: "${upgradeCommand} > upgrade_attempt.txt", returnStatus: true)
                      if (testUpgradeAttempt != 0) {
                        echo "Warning, did not upgrade the test release into the test namespace successfully, error code is: ${testUpgradeAttempt}" 
                        echo "This build will be marked as a failure: halting after the deletion of the test namespace."
                      } else {
		        slackSend (channel: slackResponse.threadId, color: '#199515', message: "*$JOB_NAME*: <$BUILD_URL|Build #$BUILD_NUMBER> upgraded successfully.")
                      }
                      printFromFile("upgrade_attempt.txt") 
		    }
		 } 
		 else {
                    echo "Attempting to deploy the test release"
                    def deployCommand = "helm install ${realChartFolder} --wait --set test=true --set license=accept --set image.repository.aceonly=${registry}${namespace}/${image} --set image.tag=${imageTag} --namespace ${namespace} --name ${tempHelmRelease}"
			if (fileExists("chart/overrides.yaml")) {
                         deployCommand += " --values chart/overrides.yaml"
                       }
                       if (helmSecret) {
                         echo "Adding --tls to your deploy command"
                         deployCommand += helmTlsOptions
                       }
			echo "::::Deploying helm with command : " + deployCommand
                       testDeployAttempt = sh(script: "${deployCommand} > deploy_attempt.txt", returnStatus: true)
                       if (testDeployAttempt != 0) {
                         echo "Warning, did not deploy the test release into the test namespace successfully, error code is: ${testDeployAttempt}" 
                         echo "This build will be marked as a failure: halting after the deletion of the test namespace."
			 slackSend (channel: slackResponse.threadId, iconEmoji: ':see_no_evil:', color: '#b31433', message: "*$JOB_NAME*: <$BUILD_URL|Build #$BUILD_NUMBER> failed.")

                       }
		       else {
			      slackSend (channel: slackResponse.threadId, iconEmoji: ':v:', color: '#199515', message: "*$JOB_NAME*: <$BUILD_URL|Build #$BUILD_NUMBER> upgraded successfully.")

		       }
                       printFromFile("deploy_attempt.txt")
		 }
               }
	    
         }
      }
    }
      
def printTime(String message) {
   time = new Date().format("ddMMyy.HH:mm.ss", TimeZone.getTimeZone('Europe/Amsterdam'))
   println "Timing, $message: $time"
}

def printFromFile(String fileName) {
   def output = readFile(fileName).trim()
   echo output
}

def getChartFolder(String userSpecified, String currentChartFolder) {

  def newChartLocation = ""
  if (userSpecified) {
    print "User defined chart location specified: ${userSpecified}"
    return userSpecified
  } else {
    print "Finding actual chart folder below ${env.WORKSPACE}/${currentChartFolder}..."
    def fp = new hudson.FilePath(Jenkins.getInstance().getComputer(env['NODE_NAME']).getChannel(), env.WORKSPACE + "/" + currentChartFolder)
    def dirList = fp.listDirectories()
    if (dirList.size() > 1) {
      print "More than one directory in ${env.WORKSPACE}/${currentChartFolder}..."
      print "Directories found are:"
      def yamlList = []
      for (d in dirList) {
        print "${d}"
        def fileToTest = new hudson.FilePath(d, "Chart.yaml")
        if (fileToTest.exists()) {
          yamlList.add(d)
        }
      }
      if (yamlList.size() > 1) {
        print "-----------------------------------------------------------"
        print "*** More than one directory with Chart.yaml in ${env.WORKSPACE}/${currentChartFolder}."
        print "*** Please specify chart folder to use in your Jenkinsfile."
        print "*** Returning null."
        print "-----------------------------------------------------------"
        return null
      } else {
        if (yamlList.size() == 1) {
          newChartLocation = currentChartFolder + "/" + yamlList.get(0).getName()
          print "Chart.yaml found in ${newChartLocation}, setting as realChartFolder"
          return newChartLocation
        } else {
          print "-----------------------------------------------------------"
          print "*** No sub directory in ${env.WORKSPACE}/${currentChartFolder} contains a Chart.yaml, returning null"
          print "-----------------------------------------------------------"
          return null
        }
      }
    } else {
      if (dirList.size() == 1) {
        def chartFile = new hudson.FilePath(dirList.get(0), "Chart.yaml")
        newChartLocation = currentChartFolder + "/" + dirList.get(0).getName()
        if (chartFile.exists()) {
          print "Only one child directory found, setting realChartFolder to: ${newChartLocation}"
          return newChartLocation
        } else {
          print "-----------------------------------------------------------"
          print "*** Chart.yaml file does not exist in ${newChartLocation}, returning null"
          print "-----------------------------------------------------------"
          return null
        }
      } else {
        print "-----------------------------------------------------------"
        print "*** Chart directory ${env.WORKSPACE}/${currentChartFolder} has no subdirectories, returning null"
        print "-----------------------------------------------------------"
        return null
      }
    }
  }
}


