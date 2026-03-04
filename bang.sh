#!/bin/bash

# Määra oma perekonnanimi
PERENIMI="ivanov"

# 1. Uue kasutaja loomine
echo "1. Loon kasutaja archive_$PERENIMI..."
sudo useradd -m -d /home/archive -G sudo -s /bin/bash archive_$PERENIMI
echo "archive_$PERENIMI:4321" | sudo chpasswd

# Kontrolli, kas kasutaja loodi
if id "archive_$PERENIMI" &>/dev/null; then
    echo "Kasutaja archive_$PERENIMI loodud edukalt"
else
    echo "Viga: Kasutaja loomine ebaõnnestus"
    exit 1
fi

# 2. Juhis sisselogimiseks
echo ""
echo "2. Palun logi nüüd sisse archive_$PERENIMI kasutajaga:"
echo "   sudo su - archive_$PERENIMI"
echo "   (parool: 4321)"
echo ""
echo "Vajuta Enter kui oled sisse loginud..."
read

# 3. Loo kataloogid kodukataloogis
echo "3. Loon kataloogid /home/archive..."
cd /home/archive || exit
mkdir -p Daily Weekly Monthly Yearly Temp Logs
chown archive_$PERENIMI:archive_$PERENIMI Daily Weekly Monthly Yearly Temp Logs

# 4. Loo failid igas kataloogis
echo "4. Loon failid..."
echo "Daily backup - $(date)" > Daily/daily.txt
echo "Weekly backup - $(date)" > Weekly/weekly.txt
echo "Monthly backup - $(date)" > Monthly/monthly.txt
echo "Yearly backup - $(date)" > Yearly/yearly.txt
echo "Temp backup - $(date)" > Temp/temp.txt
echo "Logs backup - $(date)" > Logs/logs.txt

# 5-6. Uue ketta lisamine ja partitsioonid
echo ""
echo "5-6. JÄRGMISED SAMMUD KÄSITSI:"
echo "   -----------------------------------------"
echo "   1. Lisa virtuaalmasinale uus 6GB ketta:"
echo "      - Kui kasutad VirtualBox:"
echo "        Seaded -> Storage -> Controller -> Lisa uus ketas (6GB)"
echo "      - Kui kasutad VMware:"
echo "        VM Settings -> Add Hard Disk -> 6GB"
echo ""
echo "   2. Leia uus ketas:"
echo "      sudo fdisk -l  (otsi ketast suurusega 6GB, nt /dev/sdb)"
echo ""
echo "   3. Loo partitsioonid:"
echo "      sudo fdisk /dev/sdb"
echo "      Seejärel järjest:"
echo "      - n (uus partitsioon)"
echo "      - p (primary)"
echo "      - 1 (partitsiooni number)"
echo "      - Enter (vaikimisi algus)"
echo "      - +4G (4GB partitsioon)"
echo "      - n (uus partitsioon)"
echo "      - p (primary)"
echo "      - 2 (partitsiooni number)"
echo "      - Enter (vaikimisi algus)"
echo "      - Enter (ülejäänud ruum - 2GB)"
echo "      - w (kirjuta ja välju)"
echo "   -----------------------------------------"
echo ""
echo "Vajuta Enter kui partitsioonid on loodud..."
read

# 7. Loo kataloogid /archive_data
echo "7. Loon kataloogid /archive_data..."
sudo mkdir -p /archive_data/store1 /archive_data/store2

# 8. Formeedi ja monteeri partitsioonid
echo "8. Formeedin ja monteerin partitsioonid..."
sudo mkfs.ext4 -F /dev/sdb1
sudo mkfs.ext4 -F /dev/sdb2
sudo mount /dev/sdb1 /archive_data/store1
sudo mount /dev/sdb2 /archive_data/store2

# 9. Lisa fstab-i
echo "9. Lisan partitsioonid fstab-i..."
echo "/dev/sdb1 /archive_data/store1 ext4 defaults 0 2" | sudo tee -a /etc/fstab
echo "/dev/sdb2 /archive_data/store2 ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Kontrolli fstab-i
echo "Kontrollin fstab-i..."
sudo mount -a
if [ $? -eq 0 ]; then
    echo "fstab korras"
else
    echo "Viga fstab-is!"
fi

# 10. Loo kataloogid
echo "10. Loo kataloogid store kataloogides..."
sudo mkdir -p /archive_data/store1/archives_$PERENIMI
sudo mkdir -p /archive_data/store2/archives_${PERENIMI}_long

# 11. Anna õigused archive kasutajale
echo "11. Annan õigused archive_$PERENIMI kasutajale..."
sudo chown -R archive_$PERENIMI:archive_$PERENIMI /archive_data/store1/archives_$PERENIMI
sudo chown -R archive_$PERENIMI:archive_$PERENIMI /archive_data/store2/archives_${PERENIMI}_long
sudo chmod 755 /archive_data/store1/archives_$PERENIMI
sudo chmod 755 /archive_data/store2/archives_${PERENIMI}_long

# 12. Loo alamkataloogid store1 kaustas (archive kasutajana)
echo "12. Loon alamkataloogid..."
sudo -u archive_$PERENIMI mkdir -p /archive_data/store1/archives_$PERENIMI/{Daily,Weekly,Monthly,Yearly,Temp,Logs}

# 13. Loo kopeerimisskriptid
echo "13. Loon kopeerimisskriptid..."

# Funktsioon skripti loomiseks
create_backup_script() {
    local script_name=$1
    local source_dir=$2
    
    sudo -u archive_$PERENIMI cat > /archive_data/store1/archives_$PERENIMI/${script_name}.sh << EOF
#!/bin/bash
# Backup skript - \$script_name

SOURCE="/home/archive/\$source_dir"
DEST="/archive_data/store1/archives_$PERENIMI/\$source_dir"
DATETIME=\$(date +%Y%m%d_%H%M%S)

# Loo sihtkataloog kuupäevaga
mkdir -p "\$DEST/\$DATETIME"

# Kopeeri sisu
cp -r "\$SOURCE"/* "\$DEST/\$DATETIME/" 2>/dev/null

echo "Backup tehtud: \$DEST/\$DATETIME"
EOF
    
    sudo chmod +x /archive_data/store1/archives_$PERENIMI/${script_name}.sh
    sudo chown archive_$PERENIMI:archive_$PERENIMI /archive_data/store1/archives_$PERENIMI/${script_name}.sh
}

# Loo kõik skriptid
create_backup_script "backup_daily" "Daily"
create_backup_script "backup_weekly" "Weekly"
create_backup_script "backup_monthly" "Monthly"
create_backup_script "backup_yearly" "Yearly"
create_backup_script "backup_temp" "Temp"
create_backup_script "backup_logs" "Logs"

# Loo üldine kopeerimisskript store2 jaoks
sudo -u archive_$PERENIMI cat > /archive_data/store1/archives_$PERENIMI/backup_all_to_store2.sh << EOF
#!/bin/bash
# Kopeeri kõik andmed store2

SOURCE="/archive_data/store1/archives_$PERENIMI"
DEST="/archive_data/store2/archives_${PERENIMI}_long"
DATETIME=\$(date +%Y%m%d_%H%M%S)

# Loo sihtkataloog kuupäevaga
mkdir -p "\$DEST/\$DATETIME"

# Kopeeri kogu sisu
cp -r "\$SOURCE"/* "\$DEST/\$DATETIME/"

echo "Kõik andmed kopeeritud: \$DEST/\$DATETIME"
EOF

sudo chmod +x /archive_data/store1/archives_$PERENIMI/backup_all_to_store2.sh
sudo chown archive_$PERENIMI:archive_$PERENIMI /archive_data/store1/archives_$PERENIMI/backup_all_to_store2.sh

# 14. Crontab seaded
echo "14. Seadistan crontabi..."

# Loo ajutine fail crontabi jaoks
TEMP_CRON=$(mktemp)

sudo -u archive_$PERENIMI crontab -l 2>/dev/null > "$TEMP_CRON"

# Lisa uued ridad
cat >> "$TEMP_CRON" << EOF
# Weekly - igal esmaspäeval kell 18:30
30 18 * * 1 /archive_data/store1/archives_$PERENIMI/backup_weekly.sh

# Daily - iga päev kell 01:30
30 1 * * * /archive_data/store1/archives_$PERENIMI/backup_daily.sh

# Monthly - 15. kuupäeval kell 00:00
0 0 15 * * /archive_data/store1/archives_$PERENIMI/backup_monthly.sh

# Yearly - 1. juulil kell 00:00
0 0 1 7 * /archive_data/store1/archives_$PERENIMI/backup_yearly.sh

# Temp - iga 30 minuti järel
*/30 * * * * /archive_data/store1/archives_$PERENIMI/backup_temp.sh

# Logs - iga 5 minuti järel
*/5 * * * * /archive_data/store1/archives_$PERENIMI/backup_logs.sh

# Kõik andmed store2 - iga 3.5 tunni järel (210 minutit)
*/210 * * * * /archive_data/store1/archives_$PERENIMI/backup_all_to_store2.sh
EOF

# Installi uus crontab
sudo -u archive_$PERENIMI crontab "$TEMP_CRON"
rm "$TEMP_CRON"

echo ""
echo "=================================================="
echo "SEADISTUS VALMIS!"
echo "=================================================="
echo ""
echo "Kontrolli tulemust:"
echo "1. Kasutaja: archive_$PERENIMI"
echo "2. Kataloogid /home/archive: ls -la /home/archive"
echo "3. Partitsioonid: df -h | grep store"
echo "4. fstab: cat /etc/fstab | grep store"
echo "5. Kataloogid store kaustades: ls -la /archive_data/store*/"
echo "6. Skriptid: ls -la /archive_data/store1/archives_$PERENIMI/*.sh"
echo "7. Crontab: sudo -u archive_$PERENIMI crontab -l"
echo ""
echo "NB! Kui partitsioonid ei monteerunud automaatselt,"
echo "kontrolli, et ketta nimi on ikka /dev/sdb (võib olla /dev/sdc vms)"
