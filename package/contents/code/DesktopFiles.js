.pragma library
.import "DockItems.js" as DockItems

function acceptsUrls(urls) {
    return urls.length > 0 && urls.every(function (url) {
        return /^file:\/\/(?:localhost)?\/[^?#]+\.desktop$/.test(String(url))
    })
}

function appendApps(current, incoming) {
    var result = current.slice()
    incoming.forEach(function (app) {
        if (!DockItems.hasDuplicate(result, app, -1)) {
            result.push(configuredApp(app, app.name, app.icon))
        }
    })
    return result
}

function shellQuote(value) {
    return "'" + value.replace(/'/g, "'\\''") + "'"
}

function fileUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
}

function configuredApp(desktop, name, icon, original) {
    var result = {
        id: desktop.id, name: name, icon: icon, path: desktop.path,
        desktopName: desktop.name, desktopIcon: desktop.icon,
        customName: name !== desktop.name, customIcon: icon !== desktop.icon
    }
    if (original && original.path === desktop.path) {
        if (name === original.name && original.customName !== undefined) {
            result.customName = original.customName
            result.name = original.customName ? name : desktop.name
        }
        if (icon === original.icon && original.customIcon !== undefined) {
            result.customIcon = original.customIcon
            result.icon = original.customIcon ? icon : desktop.icon
        }
    }
    return result
}

function synchronize(items, desktops) {
    return items.map(function (item) {
        if (DockItems.isSeparator(item))
            return item
        var desktop = desktops.find(function (app) { return app.path === item.path })
        if (!desktop)
            return item
        var result = Object.assign({}, item)
        // Legacy entries have no baseline: preserve differences as custom values.
        result.customName = item.customName !== undefined ? item.customName
            : item.name !== (item.desktopName !== undefined ? item.desktopName : desktop.name)
        result.customIcon = item.customIcon !== undefined ? item.customIcon
            : item.icon !== (item.desktopIcon !== undefined ? item.desktopIcon : desktop.icon)
        if (!result.customName)
            result.name = desktop.name
        if (!result.customIcon)
            result.icon = desktop.icon
        result.desktopName = desktop.name
        result.desktopIcon = desktop.icon
        return result
    })
}
