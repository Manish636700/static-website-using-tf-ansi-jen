pipeline {
    agent any

   // environment {
   //     AWS_ACCESS_KEY_ID     = 'YOUR_AWS_ACCESS_KEY'
   //     AWS_SECRET_ACCESS_KEY = 'YOUR_AWS_SECRET_ACCESS_KEY'
     //  AWS_DEFAULT_REGION    = 'us-east-1'
      // S3_BUCKET             = 'BUCKET_NAME'
   // }

    stages {
	stage('Load ENV variables'){
	    steps {
		script {
		  def envMap = readFile('jenkins_env_vars.env')
		      .split('\n')
		      .findAll { it.trim() && it.contains('=') }	
                      .collectEntries { line ->
                          def (key, value) = line.split('=',2)
			  [(key.trim()):value.trim()]
                   
			}
		 env.AWS_ACCESS_KEY_ID = envMap.AWS_ACCESS_KEY_ID
		 env.AWS_SECRET_ACCESS_KEY = envMap.AWS_SECRET_ACCESS_KEY
	         env.S3_BUCKET = envMap.S3_BUCKET
		 env.AWS_DEFAULT_REGION=envMap.AWS_DEFAULT_REGION
		  }
		}
	}
        stage('Clone Code') {
            steps {
                git url: 'https://github.com/Manish636700/static-website.git', branch: 'main'
            }
        }

        stage('Deploy to S3') {
            steps {
                sh '''
                echo "Deploying site to S3..."
                aws s3 sync . s3://$S3_BUCKET --region $AWS_DEFAULT_REGION --delete
                '''
            }
        }
    }
}
