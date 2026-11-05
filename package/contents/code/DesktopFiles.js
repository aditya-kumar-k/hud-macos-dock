.pragma library

function acceptsUrls(urls) {
    return urls.length > 0 && urls.every(function (url) {
        return /^file:\/\/(?:localhost)?\/[^?#]+\.desktop$/.test(String(url))
    })
}

function appendApps(current, incoming) {
    var result = current.slice()
    incoming.forEach(function (app) {
        if (!result.some(function (existing) {
            return existing.id === app.id || existing.path === app.path
        })) {
            result.push({ id: app.id, name: app.name, icon: app.icon, path: app.path })
        }
    })
    return result
}

function shellQuote(value) {
    return "'" + value.replace(/'/g, "'\\''") + "'"
}
