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
                }
            }
            steps {
                gradleCreateRelease()
            }
        }

        stage('Fetch binary') {
            steps {
                gradle('extractApp')
                gradle('extractDebugApp')
            }
        }

        stage('Extract filesystem from containers') {
            steps {
                script {
                    withDockerRegistry(registry: [url: 'https://de.icr.io/v2/', credentialsId: 'icr_image_pusher_erp_dev_api_key']) {
                        sh 'docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --target production -t production_filesystem docker/vau'
                        sh 'docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --build-arg "DEBUG_ROOT_HASH=$DEBUG_ROOT_HASH" --target debug -t debug_filesystem docker/vau'
                        sh 'mkdir production_filesystem debug_filesystem'
                        sh 'docker export $(docker create production_filesystem) --output production_filesystem/production_filesystem.tar'
                        sh 'docker export $(docker create debug_filesystem) --output debug_filesystem/debug_filesystem.tar'
                    }
                    createSummary('user.png').appendText("<h3>Vault Secret</h3><p>Value: <b>${env.VAULT_SECRET_ID}</b></p>", false, false, false, 'black')
                }
            }
        }

        stage('Create squashed filesystems') {
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
            steps {
                script {
                    def secrets = [
                            [$class      : 'VaultSecret', path: "secret/eRp/environments/rutu/efi/certs",
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
                        sh 'rm -rf docker/efi/certs/*'
                    }
                }
            }
        }

        stage('Load PU signing keys from Vault') {
            steps {
                script {
                    def secrets = [
                            [$class      : 'VaultSecret', path: "secret/eRp/environments/pu/efi/certs",
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
                        sh 'rm -rf docker/efi/certs/*'
                    }
                }
            }
        }

        stage('Publish Artifacts') {
             when {
                 anyOf {
                     branch 'master'
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
                }
            }
            steps {
                finishRelease()
            }
        }
    }

}