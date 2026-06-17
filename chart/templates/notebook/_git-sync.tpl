{{/*
Shell script to clone notebooks from git into the workbench workspace.
Falls back to chart-embedded notebooks when gitSync.fallbackToEmbedded is true.
Mount the workspace volume at $WORKSPACE_DIR before running.
*/}}
{{- define "ai-taxi-anomaly-detector.gitSyncScript" -}}
set -e
cd "${WORKSPACE_DIR}"
NOTEBOOKS_PATH="{{ .Values.notebook.gitSync.notebooksPath }}"
GIT_OK=0

if [ -d "${NOTEBOOKS_PATH}" ]; then
  echo "Removing existing ${NOTEBOOKS_PATH} folder..."
  rm -rf "${NOTEBOOKS_PATH}"
fi

echo "Cloning repository: {{ .Values.notebook.gitSync.repo }}"
RETRIES=5
COUNT=0
until git clone --depth 1 {{ if .Values.notebook.gitSync.branch }}--branch {{ .Values.notebook.gitSync.branch }}{{ end }} {{ .Values.notebook.gitSync.repo }} /tmp/repo; do
  COUNT=$((COUNT+1))
  if [ $COUNT -ge $RETRIES ]; then
    echo "Failed to clone repository after $RETRIES attempts"
    break
  fi
  echo "Clone failed, retrying in 10 seconds... (attempt $COUNT/$RETRIES)"
  sleep 10
done

if [ -d "/tmp/repo/${NOTEBOOKS_PATH}" ]; then
  cp -rf "/tmp/repo/${NOTEBOOKS_PATH}" .
  echo "Notebooks synced from git:"
  ls -la "${NOTEBOOKS_PATH}/"
  GIT_OK=1
else
  echo "Warning: ${NOTEBOOKS_PATH} not found in git repository"
fi
rm -rf /tmp/repo

if [ "$GIT_OK" -eq 1 ]; then
  echo "Notebook git sync completed successfully"
  exit 0
fi

{{- if .Values.notebook.gitSync.fallbackToEmbedded }}
echo "Falling back to embedded chart notebooks..."
mkdir -p "${NOTEBOOKS_PATH}"
cp -rf /mnt/embedded-notebooks/. "./${NOTEBOOKS_PATH}/"
echo "Notebooks copied from chart bundle:"
ls -la "${NOTEBOOKS_PATH}/"
echo "Notebook sync completed successfully (embedded fallback)"
exit 0
{{- else }}
echo "Error: ${NOTEBOOKS_PATH} directory not found in repository and fallback is disabled"
exit 1
{{- end }}
{{- end }}
