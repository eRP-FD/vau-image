pipeline {
    agent {
        node {
            label 'dockerstage'
        }
    }

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout()
    }

    environment {
         DEBUG_ROOT_HASH = credentials('erp_vau_debug_root_hash')
         VAULT_SECRET_ID = sh (script: 'openssl rand -base64 12', returnStdout: true).trim()
         VAULT_SIGN_KEYS_PATH = "certs_20240422"
     }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                commonCheckout()
            }
        }

        stage('Create Release') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                gradleCreateVersionRelease()
            }
        }

        stage('Fetch binary') {
            steps {
                gradle('extractApp')
                gradle('extractDebugApp')
            }
        }

        stage('Load PU signing keys from Vault (sysdig)') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    def secrets = [
                            [$class      : 'VaultSecret', path: "secret/eRp/environments/pu/efi/${env.VAULT_SIGN_KEYS_PATH}",
                             secretValues: [
                                     [$class: 'VaultSecretValue', envVar: 'DB_CRT', vaultKey: 'db.crt'],
                                     [$class: 'VaultSecretValue', envVar: 'DB_KEY', vaultKey: 'db.key']]
                            ]
                    ]
                    wrap([$class: 'VaultBuildWrapper', vaultSecrets: secrets]) {
                        sh "set +x && echo '${env.DB_CRT}' > docker/vau/files/certs/db.crt && set -x"
                        sh "set +x && echo '${env.DB_KEY}' > docker/vau/files/certs/db.key && set -x"
                    }
                }
            }
        }

        stage('Extract filesystem from containers') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    withDockerRegistry(registry: [url: 'https://de.icr.io/v2/', credentialsId: 'icr_image_pusher_erp_dev_api_key']) {
                        sh 'docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --target production -t production_filesystem docker/vau'
                        sh 'docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --build-arg "DEBUG_ROOT_HASH=$DEBUG_ROOT_HASH" --target debug -t debug_filesystem docker/vau'
                        sh 'mkdir production_filesystem debug_filesystem'
                        sh 'docker export $(docker create --rm production_filesystem) --output production_filesystem/production_filesystem.tar'
                        sh 'docker export $(docker create --rm debug_filesystem) --output debug_filesystem/debug_filesystem.tar'
                        sh 'docker rmi -f production_filesystem debug_filesystem'
                        sh 'rm -rf docker/vau/files/certs/*'
                    }
                    createSummary('user.png').appendText("<h3>Vault Secret</h3><p>Value: <b>${env.VAULT_SECRET_ID}</b></p>", false, false, false, 'black')
                }
            }
        }

        stage('Create squashed filesystems') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            agent {
                docker {
                    label 'dockerstage'
                    image 'de.icr.io/erp_dev/vau-image-build:0.0.1'
                    registryUrl 'https://de.icr.io/v2'
                    registryCredentialsId 'icr_image_puller_erp_dev_api_key'
                    reuseNode true
                    args '-u root:root' // needs root for correct filesystem permissions
                }
            }
            steps {
                // Production
                sh """
                    cd production_filesystem
                    tar -xf production_filesystem.tar
                    rm production_filesystem.tar
                """
                sh "mksquashfs production_filesystem/ production_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery"
                sh "sha512sum production_filesystem.squashfs > production_filesystem.squashfs.sha512sum"

                // Debug
                sh """
                    cd debug_filesystem
                    tar -xf debug_filesystem.tar
                    rm debug_filesystem.tar
                """
                sh "mksquashfs debug_filesystem/ debug_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery"
                sh "sha512sum debug_filesystem.squashfs > debug_filesystem.squashfs.sha512sum"


                sh "rm -rf production_filesystem/ debug_filesystem/"
            }
         }

        stage('Load RUTU signing keys from Vault') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    def secrets = [
                            [$class      : 'VaultSecret', path: "secret/eRp/environments/rutu/efi/${env.VAULT_SIGN_KEYS_PATH}",
                             secretValues: [
                                     [$class: 'VaultSecretValue', envVar: 'DB_CRT', vaultKey: 'db.crt'],
                                     [$class: 'VaultSecretValue', envVar: 'DB_KEY', vaultKey: 'db.key']]
                            ]
                    ]
                    wrap([$class: 'VaultBuildWrapper', vaultSecrets: secrets]) {
                        sh "set +x && echo '${env.DB_CRT}' > docker/efi/certs/db.crt && set -x"
                        sh "set +x && echo '${env.DB_KEY}' > docker/efi/certs/db.key && set -x"
                    }
                }
            }
        }

        stage('Build and sign RUTU EFI PXE bootloader') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    withDockerRegistry(registry: [url: 'https://de.icr.io/v2/', credentialsId: 'icr_image_pusher_erp_dev_api_key']) {
                        sh """
                        docker build --no-cache\
                        --build-arg SQUASHFS_IMAGE_HASH=${readFile('debug_filesystem.squashfs.sha512sum').split(' ').first().trim()} \
                        --build-arg SQUASHFS_IMAGE_VERSION=${currentBuild.displayName.minus('v-')} \
                        --build-arg RELEASE_TYPE=debug \
                        -t debug_efi \
                        docker/efi
                        """
                        sh "docker cp \$(docker create --rm debug_efi):pxe-boot.efi.signed pxe-boot.efi.debug.signed"
                        sh 'docker rmi -f debug_efi'
                        sh 'rm -rf docker/efi/certs/*'
                    }
                }
            }
        }

        stage('Load PU signing keys from Vault') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    def secrets = [
                            [$class      : 'VaultSecret', path: "secret/eRp/environments/pu/efi/${env.VAULT_SIGN_KEYS_PATH}",
                             secretValues: [
                                     [$class: 'VaultSecretValue', envVar: 'DB_CRT', vaultKey: 'db.crt'],
                                     [$class: 'VaultSecretValue', envVar: 'DB_KEY', vaultKey: 'db.key']]
                            ]
                    ]
                    wrap([$class: 'VaultBuildWrapper', vaultSecrets: secrets]) {
                        sh "set +x && echo '${env.DB_CRT}' > docker/efi/certs/db.crt && set -x"
                        sh "set +x && echo '${env.DB_KEY}' > docker/efi/certs/db.key && set -x"
                    }
                }
            }
        }

        stage('Build and sign PU EFI PXE bootloader') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    withDockerRegistry(registry: [url: 'https://de.icr.io/v2/', credentialsId: 'icr_image_pusher_erp_dev_api_key']) {
                        sh """
                        docker build --no-cache\
                        --build-arg SQUASHFS_IMAGE_HASH=${readFile('production_filesystem.squashfs.sha512sum').split(' ').first().trim()} \
                        --build-arg SQUASHFS_IMAGE_VERSION=${currentBuild.displayName.minus('v-')} \
                        --build-arg RELEASE_TYPE=production \
                        -t production_efi \
                        docker/efi
                        """
                        sh "docker cp \$(docker create --rm production_efi):pxe-boot.efi.signed pxe-boot.efi.production.signed"
                        sh 'docker rmi -f production_efi'
                        sh 'rm -rf docker/efi/certs/*'
                    }
                }
            }
        }

        stage('Publish Artifacts') {
             when {
                 anyOf {
                     branch 'master'
                     branch 'release/*'
                 }
             }
             steps {
                 publishArtifacts()
             }
         }

        stage('Publish Release') {
            when {
                anyOf {
                    branch 'master'
                    branch 'release/*'
                }
            }
            steps {
                finishRelease()
            }
        }
    }
    
    post {
        failure {
            script {
                if (env.BRANCH_NAME == 'master' || env.BRANCH_NAME.startsWith("release/")) {
                    slackSendClient(message: "Build ${env.BUILD_DISPLAY_NAME} failed for branch `${env.BRANCH_NAME}`:rotating_light: \nFor more details visit <${env.BUILD_URL}|the build page>",
                                    channel: '#erp-cpp')
                }
            }
        }
        fixed {
            script {
                if (env.BRANCH_NAME == 'master' || env.BRANCH_NAME.startsWith("release/")) {
                    slackSendClient(message: "Build is now successful again on branch `${env.BRANCH_NAME}`:green_heart:",
                                    channel: '#erp-cpp')
                }
            }
        }
    }

}
