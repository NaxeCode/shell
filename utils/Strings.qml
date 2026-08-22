pragma Singleton

import Quickshell

Singleton {
    property var _regexCache: ({})

    function testRegexList(filterList: list<string>, target: string): bool {
        const regexChecker = /^\^.*\$$/;
        for (const filter of filterList) {
            if (regexChecker.test(filter)) {
                let re = _regexCache[filter];
                if (!re) {
                    re = new RegExp(filter);
                    _regexCache[filter] = re;
                }
                if (re.test(target))
                    return true;
            } else {
                if (filter === target)
                    return true;
            }
        }
        return false;
    }
    function isBluetoothAddressName(name: string, address: string): bool {
        const compactAddress = address.replace(/[^0-9a-f]/gi, "").toLowerCase();
        const compactName = name.replace(/[^0-9a-f]/gi, "").toLowerCase();
        return compactAddress.length === 12 && compactName === compactAddress;
    }

    function bluetoothDeviceName(device): string {
        if (!device)
            return qsTr("Unknown device");

        const address = device.address ?? "";
        const names = [device.name ?? "", device.deviceName ?? ""];
        for (const name of names) {
            const trimmed = name.trim();
            if (trimmed && !isBluetoothAddressName(trimmed, address))
                return trimmed;
        }

        return qsTr("Unknown device");
    }
}
