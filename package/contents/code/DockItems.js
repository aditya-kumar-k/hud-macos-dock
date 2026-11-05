.pragma library

function isSeparator(item) {
    return item && item.type === "separator"
}

function itemSize(item, iconSize) {
    return isSeparator(item) && item.style === "line" ? iconSize * 0.35 : iconSize
}

function baseLength(items, iconSize, gap) {
    return items.reduce(function (total, item) {
        return total + itemSize(item, iconSize)
    }, Math.max(0, items.length - 1) * gap)
}

function computeLayout(m, factor, items, size, gap, zoom, length) {
    var scales = []
    var widths = []
    var pos = []
    var total = Math.max(0, items.length - 1) * gap
    var cursor = (length - baseLength(items, size, gap)) / 2
    var sigma = size * 0.85
    for (var i = 0; i < items.length; i++) {
        var base = itemSize(items[i], size)
        var d = m - (cursor + base / 2)
        var scale = isSeparator(items[i]) ? 1
            : 1 + (zoom - 1) * Math.exp(-(d * d) / (2 * sigma * sigma)) * factor
        scales.push(scale)
        widths.push(base * scale)
        total += base * scale
        cursor += base + gap
    }
    var p = (length - total) / 2
    for (var j = 0; j < items.length; j++) {
        pos.push(p)
        p += widths[j] + gap
    }
    return { scales: scales, widths: widths, pos: pos, total: total }
}

function indexAt(m, layout, items, gap, includeSeparators) {
    var best = -1
    var bestDist = Infinity
    for (var i = 0; i < layout.pos.length; i++) {
        var width = layout.widths[i]
        var d = Math.abs(m - (layout.pos[i] + width / 2))
        if (d < bestDist && d <= width / 2 + gap / 2) {
            bestDist = d
            best = i
        }
    }
    return best >= 0 && (includeSeparators || !isSeparator(items[best])) ? best : -1
}

function hasDuplicate(items, app, exceptIndex) {
    return items.some(function (item, index) {
        return index !== exceptIndex && !isSeparator(item)
            && (item.id === app.id || item.path === app.path)
    })
}

function move(items, from, to) {
    var result = items.slice()
    if (from >= 0 && from < items.length && to >= 0 && to < items.length)
        result.splice(to, 0, result.splice(from, 1)[0])
    return result
}

function previewPositions(layout, from, to, gap) {
    var order = layout.pos.map(function (position, index) { return index })
    order = move(order, from, to)
    var positions = []
    var cursor = layout.pos.length > 0 ? layout.pos[0] : 0
    order.forEach(function (index) {
        positions[index] = cursor
        cursor += layout.widths[index] + gap
    })
    return positions
}
