.pragma library

function finite(value) {
    return typeof value === "number" && Number.isFinite(value);
}
function reading(value, unit, digits) {
    return finite(value) ? value.toFixed(digits ?? 0) + (unit ?? "") : "—";
}
function range(value, unit) {
    return Array.isArray(value) && value.length === 2 && value.every(finite) && value[0] <= value[1]
        ? `${Math.round(value[0])}–${Math.round(value[1])}${unit ? " " + unit : ""}` : "—";
}
function age(timestamp, now) {
    if (!finite(timestamp) || timestamp <= 0) return null;
    return Math.max(0, Math.floor(now / 1000 - timestamp));
}
function ageLabel(seconds) {
    if (!finite(seconds)) return "No recent reading";
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    return `${Math.floor(seconds / 3600)}h ago`;
}
function profileLabel(name) {
    return ({cool: "Cool", normal: "Normal", gaming: "Gaming"})[name] ?? "Unknown";
}
function object(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}
function validSnapshot(data) {
    return object(data) && data.schema_version === 2 && Number.isFinite(Date.parse(data.sampled_at))
        && [data.cpu, data.gpu, data.heat, data.profile].every(object)
        && (data.room === null || object(data.room)) && Array.isArray(data.fans)
        && Array.isArray(data.warnings) && Array.isArray(data.profile.issues);
}
