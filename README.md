# Intro

Dieses Projekt ist die Build-Pipeline für das VAU-Image mit dem erp-processing-context.  
Die Artefakte sind ein signierter "all-in-one" efi-Bootloader und eine squasfs-Datei. Diese werden in Nexus gespeichert.

## eRp Processing Context Version

Die eRp Processing Context Version kann in build.gradle geändert werden, indem der Variablenwert **eRpPCVersion** geändert wird.
Das Archiv mit dieser Version wird aus Nexus gezogen und in vau/erp entpackt, um innerhalb der Dockerdateien kopiert zu werden.   

## Dockerfiles

### Bootloader (docker/efi)
Das Image enthält die Werkzeuge zum Erstellen des efi-Bootloaders.
Der wichtigste Teil ist das Skript scripts/pxe, welches das squashfs-Image von Nexus herunterlädt und es mit Prüfsummen versieht.

Bitte [besuchen Sie für weitere Details](docker/efi/README.md)

### VAU image (docker/vau)
Das Hauptdateisystem für das bootfähige Image.
Die Struktur unter dem Ordner files soll das Stammverzeichnis "/" des Servers emulieren.
Der Hostname und die Nameserver werden über DHCP bereitgestellt.

Bitte [besuchen Sie für weitere Details](docker/vau/README.md)

### Build image (docker/build)
Das Image enthält Tools zur Erstellung der squasfs-Datei und wird als Jenkins-Agent verwendet.
Bitte [besuchen Sie für weitere Details](docker/build/README.md)


## Build
### CI Build

Die Artefakte in diesem Repository werden alle von Jenkins gebaut.
Die Schritte sind in der [Jenkinsfile](Jenkinsfile) zu finden.

https://jenkins.epa-dev.net/job/eRp/job/eRp/job/vau-image/

### Manual Build
Das VAU-Image und der EFI-Bootloader können mit Docker erstellt werden.

Bitte lesen Sie [die Dokumentation](docker/vau/README.md).

#### VAU image - production
1. Fügen Sie die "release"-Binärdatei des processing-context, Bibliotheken und Konfigurationsdateien in den Ordner docker/vau/erp hinzu
2. Erzeugen Sie die geheime Zeichenfolge des Tresors (openssl rand -base64 12)
3. Erstellen Sie das Image und extrahieren Sie das Dateisystem:   
```$bash
docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --target production -t production_filesystem docker/vau
docker export $(docker create production_filesystem) --output production_filesystem.tar
tar -xf production_filesystem.tar && rm production_filesystem.tar
```
4. Squashfs erstellen und sha512-Hash generieren, der im efi-Bootloader verwendet werden soll
```$bash
mksquashfs production_filesystem/ production_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery
sha512sum production_filesystem.squashfs
```

#### VAU image - debug
1. Fügen Sie die "Debug"-Binärdatei des processing-context, der Bibliotheken und der Konfigurationsdateien in den Ordner docker/vau/debug/erp hinzu
2. Erzeugen Sie die geheime Zeichenfolge des Tresors (openssl rand -base64 12)
3. Bereiten Sie ein Root-Passwort vor ( openssl passwd -6)
4. Erstellen Sie das Image und extrahieren Sie das Dateisystem:
```$bash
docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --build-arg "DEBUG_ROOT_HASH=$DEBUG_ROOT_HASH" --target debug -t debug_filesystem docker/vau
docker export $(docker create debug_filesystem) --output debug_filesystem.tar
tar -xf debug_filesystem.tar && rm debug_filesystem.tar
```
4. Squashfs erstellen und sha512-Hash generieren, der im efi-Bootloader verwendet werden soll
```$bash
mksquashfs debug_filesystem/ debug_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery
sha512sum debug_filesystem.squashfs
```

#### EFI bootloader

Bitte lesen Sie [die Dokumentation](docker/efi/README.md).

1. Erstellen Sie db.crt und db.key in docker/efi/certs
2. Erstellen Sie den Bootloader
```$bash
    docker build --no-cache\
    --build-arg SQUASHFS_IMAGE_HASH=${sha512sum of the squashfs} \
    --build-arg SQUASHFS_IMAGE_VERSION=${version of the squasfs in NExus} \
    --build-arg RELEASE_TYPE=production \
    -t production_efi \
    docker/efi
```
3. Die Binärdatei wird im Image signiert und in das lokale Dateisystem extrahiert.
```$bash
docker cp $(docker create --rm production_efi):pxe-boot.efi.signed pxe-boot.efi.production.signed
```


## Deployment
Ansile Tower wird für das Deployment des Images verwendet.

Aktualisieren Sie die **vau_image_version** mit der Version, die durch den Jenkins-Build erstellt wurde.
Der Job wird die Konfigurationsdateien in Ordnern vorbereiten, die mit der MAC-Adresse des VAU-Servers übereinstimmen,
lädt den efi-Bootloader in der angegebenen Version herunter und setzt den in /etc/dhcp/dhcpd.conf definierten Symlink auf die neue Datei.

Weitere Einzelheiten finden Sie in den Ordnern /data/local_repo/vau-config/ und /var/lib/tfpd/uefi auf den IMGREPO-Servern.
