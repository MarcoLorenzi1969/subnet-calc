#!/usr/bin/env bash
set -euo pipefail

# git_sync.sh — Inizializza repo locale + mantiene aggiornato con GitHub
# Uso:
#   ./git_sync.sh "messaggio commit"
#
# Se il repo non è inizializzato:
#   - fa git init
#   - imposta branch main
#   - chiede URL remoto GitHub (una volta sola)
#   - fa primo commit e push
#
# Se il repo è già esistente:
#   - fa git pull
#   - aggiunge tutti i file
#   - commit con messaggio passato
#   - push su main

# ------------------ controlli ------------------
if [ $# -lt 1 ]; then
  echo "Uso: $0 \"messaggio commit\""
  exit 1
fi

COMMIT_MSG="$1"

# ------------------ inizializzazione ------------------
if [ ! -d .git ]; then
  echo "[INFO] Repo non trovato, inizializzo..."
  git init
  git branch -M main

  read -rp "Inserisci URL remoto GitHub (es. git@github.com:marcolorenzi/subnet-calc.git): " REMOTE
  git remote add origin "$REMOTE"

  git add .
  git commit -m "chore: initial commit"
  git push -u origin main
  echo "[INFO] Inizializzazione completata!"
  exit 0
fi

# ------------------ sync aggiornamento ------------------
echo "[INFO] Aggiorno repo..."
git pull --rebase origin main || true

git add .
git commit -m "$COMMIT_MSG" || echo "[INFO] Nessuna modifica da committare"
git push origin main
echo "[INFO] Repo aggiornato con successo!"
