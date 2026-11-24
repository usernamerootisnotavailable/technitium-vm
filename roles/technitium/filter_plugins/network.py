"""Small IPv4/IPv6 validation filters for the Technitium host role."""

from __future__ import annotations

import ipaddress

from ansible.errors import AnsibleFilterError


def is_network(value: str) -> bool:
    try:
        ipaddress.ip_network(value, strict=False)
        return True
    except (TypeError, ValueError):
        return False


def ip_in_network(address: str, network: str) -> bool:
    try:
        return ipaddress.ip_address(address) in ipaddress.ip_network(network, strict=False)
    except (TypeError, ValueError):
        return False


def is_private_address(address: str) -> bool:
    try:
        return ipaddress.ip_address(address).is_private
    except (TypeError, ValueError):
        return False


class FilterModule:
    def filters(self):
        return {
            "is_network": is_network,
            "ip_in_network": ip_in_network,
            "is_private_address": is_private_address,
        }
