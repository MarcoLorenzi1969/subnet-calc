#!/usr/bin/env bash
set -euo pipefail

# subnet_calc.sh — Calcolo subnet IPv4 minima da numero host richiesti
# - Dato H (host previsti), calcola prefisso CIDR minimo, netmask, host usabili, ecc.
# - Supporta margine % di crescita.
# - Se il risultato è un supernet (prefisso < /24) lo evidenzia e mostra quante /24 aggrega.

# ---------------------------- UTIL ----------------------------------

print_help() {
  cat <<'EOF'
Uso:
  subnet_calc.sh -H <host> [-m <margine_percent>] [-b <ip_base>] [-q]
  subnet_calc.sh --help

Opzioni:
  -H, --hosts <n>         Numero di host previsti nella LAN (interi >=1).
  -m, --margin <percent>  Margine di crescita (default 0). Esempio: -m 25
  -b, --base <ip>         IP base (es. 192.168.0.0) per mostrare un esempio di blocco risultante.
  -q, --quiet             Output essenziale (solo risultati chiave).
  -h, --help              Mostra questo aiuto.

Logica (IPv4 standard):
  1) Htot = H + 2  (indirizzo di rete + broadcast)
  2) Trova la più piccola potenza di 2 >= Htot  →  2^h
  3) Prefisso CIDR = 32 - h
  4) Host utilizzabili = 2^h - 2
  Nota: /31 e /32 sono casi speciali (p2p/host singolo) non usati per LAN general-purpose.

Esempi:
  # 50 host (+20% di margine): /26
  subnet_calc.sh -H 50 -m 20

  # 30.000 host (supernet richiesto): /17
  subnet_calc.sh -H 30000

  # Solo output essenziale:
  subnet_calc.sh -H 120 -q

  # Con IP base per mostrare un esempio di blocco
  subnet_calc.sh -H 30000 -b 10.0.0.0
EOF
}

is_ip() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<<"$ip"
  for oct in "$a" "$b" "$c" "$d"; do
    [[ "$oct" -ge 0 && "$oct" -le 255 ]] || return 1
  done
  return 0
}

# Ceil log2 via raddoppio (no dipendenze esterne)
ceil_log2_and_pow2() {
  # input: n; output: h e pow2 (=2^h)
  local n="$1"
  local h=0
  local v=1
  while (( v < n )); do
    v=$(( v << 1 ))
    h=$(( h + 1 ))
  done
  echo "$h $v"
}

prefix_to_netmask() {
  local p="$1"
  local mask=0
  # Costruisci a 32 bit: primi p bit a 1
  if (( p == 0 )); then
    mask=0
  else
    mask=$(( 0xFFFFFFFF << (32 - p) ))
  fi
  # Estrai ottetti
  local o1=$(( (mask >> 24) & 255 ))
  local o2=$(( (mask >> 16) & 255 ))
  local o3=$(( (mask >> 8)  & 255 ))
  local o4=$((  mask        & 255 ))
  echo "${o1}.${o2}.${o3}.${o4}"
}

# Calcola quanti /24 sono aggregati da un prefisso < /24
aggregated_24() {
  local p="$1"
  if (( p < 24 )); then
    # 2^(24 - p)
    local n=$(( 1 << (24 - p) ))
    echo "$n"
  else
    echo "1"
  fi
}

# Applica un prefisso a un IP base (azzera i bit host) per mostrare la rete "esempio"
apply_prefix() {
  local ip="$1" p="$2"
  IFS='.' read -r a b c d <<<"$ip"
  local val=$(( (a<<24) | (b<<16) | (c<<8) | d ))
  local mask=$(( p == 0 ? 0 : 0xFFFFFFFF << (32 - p) ))
  local net=$(( val & mask ))
  local o1=$(( (net >> 24) & 255 ))
  local o2=$(( (net >> 16) & 255 ))
  local o3=$(( (net >> 8)  & 255 ))
  local o4=$((  net        & 255 ))
  echo "${o1}.${o2}.${o3}.${o4}"
}

# ---------------------------- PARSE ---------------------------------

HOSTS=""
MARGIN="0"
BASE_IP=""
QUIET=0

while (( "$#" )); do
  case "$1" in
    -H|--hosts)   HOSTS="${2:-}"; shift 2;;
    -m|--margin)  MARGIN="${2:-}"; shift 2;;
    -b|--base)    BASE_IP="${2:-}"; shift 2;;
    -q|--quiet)   QUIET=1; shift;;
    -h|--help)    print_help; exit 0;;
    *) echo "Argomento sconosciuto: $1" >&2; echo; print_help; exit 1;;
  esac
done

if [[ -z "$HOSTS" ]]; then
  # Modalità interattiva
  read -rp "Numero host previsti (H): " HOSTS
  read -rp "Margine percentuale (0 se non serve): " MARGIN
  read -rp "IP base (opzionale, es. 192.168.0.0): " BASE_IP
fi

# ---------------------------- VALIDAZIONI ---------------------------

if ! [[ "$HOSTS" =~ ^[0-9]+$ ]] || (( HOSTS < 1 )); then
  echo "Errore: -H/--hosts deve essere un intero >= 1" >&2
  exit 1
fi
if ! [[ "$MARGIN" =~ ^[0-9]+$ ]]; then
  echo "Errore: -m/--margin deve essere una percentuale intera >= 0" >&2
  exit 1
fi
if [[ -n "$BASE_IP" ]] && ! is_ip "$BASE_IP"; then
  echo "Errore: -b/--base deve essere un IPv4 valido (es. 10.0.0.0)" >&2
  exit 1
fi

# ---------------------------- CALCOLI -------------------------------

# Applica margine: H_eff = ceil(H * (1 + margin/100))
# Implementazione solo interi: (H*(100+M)+99)/100 fa il ceil
H="$HOSTS"
M="$MARGIN"
H_EFF=$(( ( H * (100 + M) + 99 ) / 100 ))

# Htot = H_eff + 2 (rete + broadcast)
H_TOT=$(( H_EFF + 2 ))

# Trova h e 2^h
read -r H_BITS POW2 <<<"$(ceil_log2_and_pow2 "$H_TOT")"

# Prefisso
PREFIX=$(( 32 - H_BITS ))

# Limiti
if (( PREFIX < 0 )); then
  echo "Impossibile: richiesti troppi host (>$(( (1<<32) - 2 ))) per IPv4)." >&2
  exit 1
fi

# Host usabili (2^h - 2)
HOST_USABLE=$(( POW2 - 2 ))

# Netmask
NETMASK="$(prefix_to_netmask "$PREFIX")"

# Info supernet
AGG_24="$(aggregated_24 "$PREFIX")"
IS_SUPER="no"
if (( PREFIX < 24 )); then
  IS_SUPER="si"
fi

# Esempio rete da IP base (se fornito)
EX_NET=""
EX_BCAST=""
if [[ -n "$BASE_IP" ]]; then
  EX_NET="$(apply_prefix "$BASE_IP" "$PREFIX")"
  # broadcast = network | ~mask
  IFS='.' read -r a b c d <<<"$EX_NET"
  local_net=$(( (a<<24) | (b<<16) | (c<<8) | d ))
  mask=$(( PREFIX == 0 ? 0 : 0xFFFFFFFF << (32 - PREFIX) ))
  inv_mask=$(( ~mask & 0xFFFFFFFF ))
  bcast=$(( local_net | inv_mask ))
  o1=$(( (bcast >> 24) & 255 ))
  o2=$(( (bcast >> 16) & 255 ))
  o3=$(( (bcast >> 8)  & 255 ))
  o4=$((  bcast        & 255 ))
  EX_BCAST="${o1}.${o2}.${o3}.${o4}"
fi

# ---------------------------- OUTPUT --------------------------------

if (( QUIET == 1 )); then
  echo "Prefisso: /$PREFIX"
  echo "Netmask:  $NETMASK"
  echo "Host utilizzabili: $HOST_USABLE"
  exit 0
fi

cat <<EOF
=== Calcolo Subnet IPv4 ===
Host richiesti (H):               $H
Margine applicato:                ${M}%  → Host con margine: $H_EFF
Htot (H_eff + 2):                 $H_TOT
Potenza di 2 (2^h):               $POW2
Bit host (h):                     $H_BITS
Prefisso (CIDR):                  /$PREFIX
Netmask (dotted):                 $NETMASK
Host utilizzabili effettivi:      $HOST_USABLE

Supernet:                         $IS_SUPER
Aggregazione di /24:              $AGG_24 $( ((PREFIX<24)) && echo "(numero di /24 contenute nel blocco)" )

$( [[ -n "$BASE_IP" ]] && echo "Esempio con IP base:
  IP base:                        $BASE_IP
  Rete risultante:                ${EX_NET}/$PREFIX
  Primo host:                     (dipende da piano IP) tipicamente ${EX_NET%.*}.$(( (${EX_NET##*.}) + 1 ))
  Broadcast:                      $EX_BCAST
")

Note:
- La scelta usa convenzioni IPv4 classiche per LAN: si riservano 2 indirizzi (rete/broadcast).
- /31 e /32 sono per casi speciali (p2p/host singolo).
- Se 'Supernet: si', il blocco è più grande di /24 e aggrega più reti di classe C storiche.
EOF
