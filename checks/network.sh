# checks/network.sh
check_network() {
  section "Network"

  local eth_count
  eth_count="$(ip -o link show 2>/dev/null | grep -cvE 'lo|docker|veth|br-|virbr' || echo 0)"
  ok "Physical/virtual data interfaces: ${eth_count}"

  if [[ "${MIN_ETH_INTERFACES:-0}" -gt 0 ]]; then
    if [[ "$eth_count" -ge "$MIN_ETH_INTERFACES" ]]; then
      ok "Interface count meets profile minimum (${MIN_ETH_INTERFACES})"
    else
      warn "Expected at least ${MIN_ETH_INTERFACES} interfaces, found ${eth_count}"
    fi
  fi

  ip -o link show 2>/dev/null | grep -E 'enP|enp|eth|wlan' | awk '{print $2}' | tr -d ':' | \
    while read -r iface; do
      local state driver
      state="$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null || echo unknown)"
      driver="$(basename "$(readlink -f "/sys/class/net/${iface}/device/driver" 2>/dev/null)" 2>/dev/null || echo unknown)"
      info "${iface}: operstate=${state}, driver=${driver}"
    done

  if ip link show lo 2>/dev/null | grep -q 'state UNKNOWN\|state UP'; then
    ok "Loopback interface up"
  else
    fail "Loopback interface down"
  fi
}
