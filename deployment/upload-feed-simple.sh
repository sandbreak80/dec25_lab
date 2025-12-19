#!/bin/bash
# Simple SecureApp feed upload for Team 5
# Run this on the VM directly

FEED_FILE="/home/appduser/secapp_data_25.12.18.1765984004.dat"
LOG_FILE="/home/appduser/secureapp-upload-$(date +%Y%m%d-%H%M%S).log"

echo "Starting SecureApp feed upload at $(date)" | tee "$LOG_FILE"
echo "Feed file: $FEED_FILE" | tee -a "$LOG_FILE"
echo "File size: $(ls -lh $FEED_FILE | awk '{print $5}')" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "=== Uploading feed ===" | tee -a "$LOG_FILE"
appdcli run secureapp uploadFeed "$FEED_FILE" 2>&1 | tee -a "$LOG_FILE"

UPLOAD_EXIT=$?
echo "" | tee -a "$LOG_FILE"
echo "Upload exit code: $UPLOAD_EXIT" | tee -a "$LOG_FILE"

if [ $UPLOAD_EXIT -eq 0 ]; then
    echo "✅ Upload succeeded!" | tee -a "$LOG_FILE"
else
    echo "❌ Upload failed!" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Restarting feed processing ===" | tee -a "$LOG_FILE"
appdcli run secureapp restartFeedProcessing 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Waiting 3 minutes for processing..." | tee -a "$LOG_FILE"
sleep 180

echo "" | tee -a "$LOG_FILE"
echo "=== Checking SecureApp health ===" | tee -a "$LOG_FILE"
appdcli run secureapp health 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Checking overall status ===" | tee -a "$LOG_FILE"
appdcli ping | grep SecureApp | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Complete! Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"


