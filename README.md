# subnet-calc

Script **Bash** per calcolare subnet **IPv4** e **IPv6** da terminale.

* **IPv4**: dato il numero di host previsti (con margine opzionale), calcola il **prefisso minimo (CIDR)**, la **netmask**, gli **host utilizzabili** e segnala se è un **supernet**.
* **IPv6**: dato un **prefisso base** (es. `/48`) e il numero di **sottoreti richieste** oppure un **prefisso target** (es. `/64`), calcola **quante sottoreti** ottieni/ti servono, con **best practice /64** per le LAN, e stampa **esempi** di sottoreti per i casi più comuni.

---

## Requisiti, dipendenze e pacchetti usati

**Runtime**

* **Bash ≥ 4.0** (Linux/Kali/macOS OK). Nessuna dipendenza esterna: lo script usa solo built‑in di Bash e aritmetica intera.
* Opzionale: terminale che supporta colori ANSI (disattivabili con `--no-color` o variabile `NO_COLOR=1`).

**Sviluppo/CI (opzionale)**

* [`shellcheck`](https://www.shellcheck.net/) per linting.
* [`bats-core`](https://github.com/bats-core/bats-core) per i test.
* [`gh` GitHub CLI](https://cli.github.com/) per creare/pushare rapidamente il repository.
* `make` (per scorciatoie di lint/test se usi il `Makefile`).

> Su macOS: `brew install shellcheck bats-core gh`
> Su Debian/Kali: `sudo apt-get install -y shellcheck bats gh`

---

## Installazione

```bash
# Clona il repository
git clone https://github.com/MarcoLorenzi1969/subnet-calc.git
cd subnet-calc

# Rendi eseguibile lo script
chmod +x subnet_calc.sh
```

Facoltativo: aggiungi alla PATH (ad es. `/usr/local/bin`):

```bash
sudo cp subnet_calc.sh /usr/local/bin/subnet-calc
```

---

## Modalità d’uso

### Sintassi rapida

**IPv4**

```bash
./subnet_calc.sh -H <host> [-m <margine%>] [-b <ip_base>] [-q]
```

**IPv6**

```bash
./subnet_calc.sh -6 -B <prefisso_ipv6> [-N <num_subnet>] [-T <prefisso_target>] [--sample <k>]
```

### Opzioni comuni

* `-h, --help, -help` → mostra help esteso e colorato.
  Disattiva i colori con `--no-color` oppure `NO_COLOR=1`.
* `--no-color` → disabilita colori ANSI nell’output.

### Modalità IPv4

* `-H, --hosts <n>` → numero di host previsti nella LAN (**≥ 1**).
* `-m, --margin <percent>` → margine di crescita (default **0**). Esempio `-m 25`.
* `-b, --base <ip>` → IP base (es. `192.168.0.0`) per mostrare **rete** e **broadcast** d’esempio.
* `-q, --quiet` → output essenziale (prefisso, netmask, host).

**Logica IPv4 (riassunto)**

1. `H_eff = ceil(H * (1 + margine/100))`
2. `H_tot = H_eff + 2` (indirizzi di **rete** e **broadcast**)
3. Trova la più piccola potenza di 2 `2^h ≥ H_tot` → **prefisso** `32 - h`
4. **Host utilizzabili** `= 2^h - 2`

> Note: `/31` e `/32` sono casi speciali (p2p/host singolo) e non si usano per LAN general‑purpose.

### Modalità IPv6

* `-6, --ipv6` → attiva la modalità IPv6.
* `-B, --base6 <prefisso>` → prefisso base (es. `2001:db8:abcd::/48`).
* `-N, --nets <n>` → numero di **sottoreti richieste** (tipicamente **/64** per le LAN/VLAN).
* `-T, --target-prefix <len>` → prefisso target (es. `64` → `/64`, `56` → `/56`).
* `--sample <k>` → stampa (se possibile) i **primi k** sottoprefissi di esempio.

**Best practice IPv6**

* Ogni LAN/VLAN dovrebbe usare **/64** (SLAAC, compatibilità).
* Con un prefisso base `/P` hai **`2^(64 - P)`** sottoreti **/64**.
* Se ti servono più /64 di quelle disponibili, chiedi al provider un **prefisso base più ampio** (non stringere le LAN sotto `/64`, salvo casi speciali).

---

## Esempi d’uso (con output)

> Gli output possono contenere colori ANSI; qui sono mostrati in testo semplice per chiarezza.

### IPv4

**1) 50 host con +20% di margine**

```bash
./subnet_calc.sh -H 50 -m 20
```

Output (estratto):

```
=== Calcolo Subnet IPv4 ===
Richiesta host (H):               50
Margine applicato:                20%  → Host con margine: 60
H_tot (H_eff + 2):                62
2^h (capienza indirizzi):         64
Bit host (h):                     6
Prefisso (CIDR):                  /26
Netmask (dotted):                 255.255.255.192
Host utilizzabili effettivi:      62

Supernet:                         no
Aggregazione di /24:              1
```

**2) 30.000 host + esempio di rete/broadcast da IP base**

```bash
./subnet_calc.sh -H 30000 -b 10.0.0.0
```

Output (estratto):

```
=== Calcolo Subnet IPv4 ===
Richiesta host (H):               30000
Margine applicato:                0%  → Host con margine: 30000
H_tot (H_eff + 2):                30002
2^h (capienza indirizzi):         32768
Bit host (h):                     15
Prefisso (CIDR):                  /17
Netmask (dotted):                 255.255.128.0
Host utilizzabili effettivi:      32766

Supernet:                         si
Aggregazione di /24:              128 (# di /24 contenute)

Esempio con IP base:
  IP base:                        10.0.0.0
  Rete risultante:                10.0.0.0/17
  Broadcast:                      10.0.127.255
```

### IPv6

**3) Ho un `/48`: quante VLAN /64 posso avere? Me ne servono 120.**

```bash
./subnet_calc.sh -6 -B 2001:db8:abcd::/48 -N 120
```

Output (estratto):

```
=== Calcolo Prefissi IPv6 ===
Prefisso base:                   2001:db8:abcd::/48
Sottoreti richieste (N):         120
Sottoreti /64 disponibili:       65536
Esito /64:                       OK (N ≤ 2^(64-48))
```

**4) Quante /64 ottengo da un `/48`? (con 4 esempi)**

```bash
./subnet_calc.sh -6 -B 2001:db8:abcd::/48 -T 64 --sample 4
```

Output (estratto):

```
=== Calcolo Prefissi IPv6 ===
Prefisso base:                   2001:db8:abcd::/48
Prefisso target richiesto:       /64
Numero sottoreti /64:            65536 (da 2001:db8:abcd::/48)
Esempi prime 4 sottoreti /64:
  2001:db8:abcd:0000::/64
  2001:db8:abcd:0001::/64
  2001:db8:abcd:0002::/64
  2001:db8:abcd:0003::/64
```

**5) Quante /56 ottengo da un `/48`? (con 4 esempi)**

```bash
./subnet_calc.sh -6 -B 2001:db8:abcd::/48 -T 56 --sample 4
```

Output (estratto):

```
=== Calcolo Prefissi IPv6 ===
Prefisso base:                   2001:db8:abcd::/48
Prefisso target richiesto:       /56
Numero sottoreti /56:            256 (da 2001:db8:abcd::/48)
Esempi prime 4 sottoreti /56:
  2001:db8:abcd:0000::/56
  2001:db8:abcd:0100::/56
  2001:db8:abcd:0200::/56
  2001:db8:abcd:0300::/56
```

> Nota: gli esempi dipendono dalla forma del prefisso base (es. compressione `::`). Per elenchi completi di sottoreti IPv6, usa strumenti dedicati.

---

## Suggerimenti

* Per output senza colori: `--no-color` oppure `NO_COLOR=1 ./subnet_calc.sh …`
* Per automatizzare push/commit verso GitHub, puoi usare lo script ausiliario `git_sync.sh`.
* Per link p2p IPv4 usa `/31` (caso speciale): **non** rientra nella logica di calcolo host/broadcast per LAN.

---

## Testing e CI (opzionale)

* Lint: `shellcheck -x subnet_calc.sh`
* Test (se hai `bats`):

  ```bash
  bats tests
  ```
* CI: vedi workflow in `.github/workflows/ci.yml` (lint + test automatici su PR/push).

---

## Licenza

MIT
