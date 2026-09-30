.pragma library

// Match the existing hypr-scale-toggle accessibility ladder, including exact 5/3.
var steps = [
    {value: 1, argument: "1", label: "100%"},
    {value: 1.25, argument: "1.25", label: "125%"},
    {value: 1.5, argument: "1.5", label: "150%"},
    {value: 5 / 3, argument: "1.666667", label: "167%"},
    {value: 2, argument: "2", label: "200%"}
];

function valid(monitor, scale) {
    return Number.isFinite(scale) && scale > 0 && [monitor?.width, monitor?.height].every(size =>
        Number.isFinite(size) && size > 0 && Math.abs(size / scale - Math.round(size / scale)) < 0.001);
}

function available(monitors, scale) {
    return monitors.length > 0 && monitors.every(monitor => valid(monitor, scale));
}

function selected(monitors, scale) {
    // Hyprland reports 5/3 as 1.67 in monitor JSON.
    return monitors.length > 0 && monitors.every(monitor =>
        Number.isFinite(monitor?.scale) && Math.abs(monitor.scale - scale) < 0.005);
}

function label(scale) {
    return Number.isFinite(scale) && scale > 0 ? Math.round(scale * 100) + "%" : "—";
}
