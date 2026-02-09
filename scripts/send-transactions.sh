#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# send-transactions.sh
#
# Send test transactions through the Core Banking API.
# Each transaction is persisted, evaluated via gRPC, AND published
# to Kafka — exercising the full fraud-detection pipeline.
#
# Usage:
#   ./scripts/send-transactions.sh              # 5 normal + 5 fraud
#   ./scripts/send-transactions.sh --normal 20  # 20 normal only
#   ./scripts/send-transactions.sh --fraud  10  # 10 fraud only
#   ./scripts/send-transactions.sh --all    50  # 50 mixed (80/20)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

BANKING_URL="http://localhost:8001"
FRAUD_URL="http://localhost:8000"
USERNAME="admin"
PASSWORD="admin123"

CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

# ── Parse arguments ───────────────────────────────────────────────
MODE="demo"       # demo | normal | fraud | all
COUNT=5

while [[ $# -gt 0 ]]; do
  case $1 in
    --normal) MODE="normal"; COUNT="${2:-10}"; shift 2 ;;
    --fraud)  MODE="fraud";  COUNT="${2:-5}";  shift 2 ;;
    --all)    MODE="all";    COUNT="${2:-50}"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--normal N] [--fraud N] [--all N]"
      echo ""
      echo "  --normal N   Send N normal (low-risk) transactions"
      echo "  --fraud  N   Send N fraud-triggering (high-risk) transactions"
      echo "  --all    N   Send N mixed transactions (80% normal, 20% fraud)"
      echo "  (no args)    Demo mode: 5 normal + 5 fraud-triggering"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Step 1: Authenticate ─────────────────────────────────────────
echo -e "${CYAN}Authenticating as ${USERNAME}...${RESET}"

TOKEN=$(curl -sf "${BANKING_URL}/api/v1/auth/admin/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null) || {
  echo -e "${RED}Failed to authenticate. Is core-banking running on port 8001?${RESET}"
  exit 1
}
echo -e "${GREEN}Authenticated.${RESET}"

# ── Step 2: Fetch a real customer + account ID ───────────────────
echo -e "${CYAN}Fetching customer and account IDs...${RESET}"

CUSTOMER_ID=$(curl -sf "${BANKING_URL}/api/v1/customers?size=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['id'])" 2>/dev/null) || {
  echo -e "${RED}Failed to fetch customers. Run 'make dev.setup' first.${RESET}"
  exit 1
}

ACCOUNT_ID=$(curl -sf "${BANKING_URL}/api/v1/accounts?customer_id=${CUSTOMER_ID}&size=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['id'])" 2>/dev/null) || {
  echo -e "${RED}Failed to fetch accounts for customer ${CUSTOMER_ID}.${RESET}"
  exit 1
}

echo -e "${GREEN}Using customer=${CUSTOMER_ID} account=${ACCOUNT_ID}${RESET}"

# ── Helpers ───────────────────────────────────────────────────────

send_txn() {
  local label="$1"
  local payload="$2"

  local response
  local http_code
  http_code=$(curl -s -o /tmp/txn_response.json -w "%{http_code}" \
    "${BANKING_URL}/api/v1/transactions" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${payload}")

  if [[ "${http_code}" == "201" ]]; then
    local ext_id decision score
    ext_id=$(python3 -c "import json; r=json.load(open('/tmp/txn_response.json')); print(r['external_id'])" 2>/dev/null)
    decision=$(python3 -c "import json; r=json.load(open('/tmp/txn_response.json')); f=r.get('fraud_evaluation'); print(f['decision'] if f else 'n/a')" 2>/dev/null)
    score=$(python3 -c "import json; r=json.load(open('/tmp/txn_response.json')); f=r.get('fraud_evaluation'); print(f['risk_score'] if f else 'n/a')" 2>/dev/null)

    if [[ "${decision}" == "approve" ]]; then
      echo -e "  ${GREEN}[APPROVE]${RESET} ${ext_id}  score=${score}  ${label}"
    elif [[ "${decision}" == "review" ]]; then
      echo -e "  ${YELLOW}[REVIEW]${RESET}  ${ext_id}  score=${score}  ${label}"
    elif [[ "${decision}" == "flag" ]]; then
      echo -e "  ${RED}[FLAG]${RESET}    ${ext_id}  score=${score}  ${label}"
    else
      echo -e "  [${decision}]  ${ext_id}  score=${score}  ${label}"
    fi
  else
    echo -e "  ${RED}[HTTP ${http_code}]${RESET} ${label} — $(cat /tmp/txn_response.json 2>/dev/null)"
  fi
}

random_id() {
  python3 -c "import uuid; print(f'TXN-{uuid.uuid4().hex[:8].upper()}')"
}

random_ip() {
  python3 -c "import random; print(f'{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}')"
}

# ── Normal transaction payloads ───────────────────────────────────

send_normal() {
  local ext_id
  ext_id=$(random_id)
  local amounts=(49.99 150.00 299.50 750.00 1200.00 85.30 2500.00 450.00 999.99 3500.00)
  local merchants=("Woolworths" "Checkers" "Pick n Pay" "Takealot" "Shell Garage" "Uber Eats" "Netflix" "Engen" "Mr Price" "Amazon")
  local channels=("pos" "online" "mobile" "atm" "branch")
  local idx=$((RANDOM % ${#amounts[@]}))
  local ch_idx=$((RANDOM % ${#channels[@]}))

  local payload
  payload=$(cat <<EOF
{
  "external_id": "${ext_id}",
  "account_id": "${ACCOUNT_ID}",
  "customer_id": "${CUSTOMER_ID}",
  "type": "purchase",
  "amount": ${amounts[$idx]},
  "currency": "ZAR",
  "merchant_name": "${merchants[$idx]}",
  "merchant_category": "5411",
  "channel": "${channels[$ch_idx]}",
  "country_code": "ZA",
  "ip_address": "$(random_ip)",
  "device_id": "fp_$(openssl rand -hex 6)",
  "description": "Normal purchase at ${merchants[$idx]}"
}
EOF
)
  send_txn "R${amounts[$idx]} ${merchants[$idx]} (${channels[$ch_idx]}, ZA)" "${payload}"
}

# ── Fraud-triggering transaction payloads ─────────────────────────
# These are designed to trigger specific fraud detection rules:
#
#   AMT_001  amount > 50,000              → score +60
#   AMT_002  amount > 100,000             → score +80
#   GEO_001  high-risk country            → score +65
#   GEO_002  sanctioned country           → score +95
#   BEH_001  gambling/crypto merchant     → score +40
#   BEH_002  online + amount > 25,000     → score +55
#   DEV_001  missing device fingerprint   → score +35
#   COMB_001 online + >20K + foreign      → score +70

FRAUD_SCENARIOS=(
  "amt_high"
  "amt_very_high"
  "sanctioned_country"
  "high_risk_country"
  "gambling_online"
  "crypto_no_device"
  "foreign_online_high"
  "combined_max"
)

send_fraud() {
  local scenario_idx=$((RANDOM % ${#FRAUD_SCENARIOS[@]}))
  local scenario="${FRAUD_SCENARIOS[$scenario_idx]}"
  local ext_id
  ext_id=$(random_id)

  case "${scenario}" in
    amt_high)
      # AMT_001 (60) + DEV_001 (35) = 95 → FLAG
      send_txn "R75,000 high-value, no device [AMT_001+DEV_001]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"transfer","amount":75000,"currency":"ZAR","channel":"mobile","country_code":"ZA","ip_address":"$(random_ip)","description":"High value transfer"}
EOF
)" ;;

    amt_very_high)
      # AMT_002 (80) + AMT_001 (60) = 140 → FLAG
      send_txn "R125,000 very-high-value [AMT_001+AMT_002]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"transfer","amount":125000,"currency":"ZAR","channel":"branch","country_code":"ZA","ip_address":"$(random_ip)","device_id":"fp_$(openssl rand -hex 6)","description":"Very high value transfer"}
EOF
)" ;;

    sanctioned_country)
      # GEO_002 (95) → FLAG
      send_txn "R5,000 from Iran [GEO_002]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"purchase","amount":5000,"currency":"ZAR","channel":"online","country_code":"IR","ip_address":"$(random_ip)","device_id":"fp_$(openssl rand -hex 6)","merchant_name":"Tehran Store","merchant_category":"5999","description":"Purchase from sanctioned country"}
EOF
)" ;;

    high_risk_country)
      # GEO_001 (65) + DEV_001 (35) = 100 → FLAG
      send_txn "R8,000 from Nigeria, no device [GEO_001+DEV_001]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"purchase","amount":8000,"currency":"ZAR","channel":"online","country_code":"NG","ip_address":"$(random_ip)","merchant_name":"Lagos Market","merchant_category":"5999","description":"Purchase from high-risk country"}
EOF
)" ;;

    gambling_online)
      # BEH_001 (40) + BEH_002 (55) + DEV_001 (35) = 130 → FLAG
      send_txn "R30,000 online gambling, no device [BEH_001+BEH_002+DEV_001]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"purchase","amount":30000,"currency":"ZAR","channel":"online","country_code":"ZA","ip_address":"$(random_ip)","merchant_name":"Lucky Star Casino","merchant_category":"gambling","description":"Online gambling deposit"}
EOF
)" ;;

    crypto_no_device)
      # BEH_001 (40) + DEV_001 (35) = 75 → REVIEW
      send_txn "R15,000 crypto, no device [BEH_001+DEV_001]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"purchase","amount":15000,"currency":"ZAR","channel":"online","country_code":"ZA","ip_address":"$(random_ip)","merchant_name":"CryptoExchange","merchant_category":"crypto","description":"Crypto purchase without device"}
EOF
)" ;;

    foreign_online_high)
      # COMB_001 (70) + GEO_001 (65) + BEH_002 (55) + DEV_001 (35) = 225 → FLAG
      send_txn "R25,000 online from Russia, no device [COMB_001+GEO_001+BEH_002+DEV_001]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"transfer","amount":25000,"currency":"ZAR","channel":"online","country_code":"RU","ip_address":"$(random_ip)","merchant_name":"Moscow Transfer","merchant_category":"6012","description":"Foreign online high-value transfer"}
EOF
)" ;;

    combined_max)
      # AMT_002 (80) + AMT_001 (60) + COMB_001 (70) + GEO_002 (95) + BEH_002 (55) + DEV_001 (35) = 395 → FLAG
      send_txn "R150,000 online from North Korea, no device [MAX RISK]" "$(cat <<EOF
{"external_id":"${ext_id}","account_id":"${ACCOUNT_ID}","customer_id":"${CUSTOMER_ID}","type":"transfer","amount":150000,"currency":"ZAR","channel":"online","country_code":"KP","ip_address":"$(random_ip)","merchant_name":"Pyongyang Transfer","merchant_category":"crypto","description":"Maximum risk transaction"}
EOF
)" ;;
  esac
}

# ── Execute ───────────────────────────────────────────────────────

echo ""
case "${MODE}" in
  demo)
    echo -e "${CYAN}Sending 5 normal transactions...${RESET}"
    for i in $(seq 1 5); do send_normal; done
    echo ""
    echo -e "${CYAN}Sending 5 fraud-triggering transactions...${RESET}"
    for i in $(seq 1 5); do send_fraud; done
    ;;
  normal)
    echo -e "${CYAN}Sending ${COUNT} normal transactions...${RESET}"
    for i in $(seq 1 "${COUNT}"); do send_normal; done
    ;;
  fraud)
    echo -e "${CYAN}Sending ${COUNT} fraud-triggering transactions...${RESET}"
    for i in $(seq 1 "${COUNT}"); do send_fraud; done
    ;;
  all)
    echo -e "${CYAN}Sending ${COUNT} mixed transactions (80% normal, 20% fraud)...${RESET}"
    for i in $(seq 1 "${COUNT}"); do
      if (( RANDOM % 5 == 0 )); then
        send_fraud
      else
        send_normal
      fi
    done
    ;;
esac

echo ""
echo -e "${GREEN}Done! View alerts at: ${FRAUD_URL}/api/v1/alerts${RESET}"
echo -e "${GREEN}Or open the portal:  http://localhost:3000${RESET}"
