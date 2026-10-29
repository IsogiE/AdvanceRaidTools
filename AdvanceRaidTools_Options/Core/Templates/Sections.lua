local E = unpack(ART)
local T = E.Templates

function T:RecordSectionPlacement(parent, widget, y)
    local owner = parent
    while owner do
        local context = owner.artSectionContext
        if context then
            if not context.released then context:Record(parent, widget, y) end
            return
        end
        owner = owner:GetParent()
    end
end

function T:CollapsibleSections(host, opts)
    opts = opts or {}
    local saved = opts.state or {}
    local nodes, nodeOrder, byFrame = {}, {}, {}
    local context = {root = host}
    local serial = 0
    host.artSectionContext = context

    function context:Record(parent, widget, y)
        local node = nodes[parent]
        if not node then
            local depth, ancestor = 0, parent
            while ancestor and ancestor ~= host do depth = depth + 1; ancestor = ancestor:GetParent() end
            node = {parent = parent, records = {}, depth = depth}
            nodes[parent] = node
            nodeOrder[#nodeOrder + 1] = node
        end
        local record = byFrame[widget.frame]
        if not record then
            serial = serial + 1
            record = {widget = widget, frame = widget.frame, serial = serial}
            byFrame[widget.frame] = record
            node.records[#node.records + 1] = record
        end
        record.y, record.height = y, widget.frame:GetHeight()
        record.point = {widget.frame:GetPoint(1)}
        node.layoutDirty = true
    end

    local function prepareNode(node)
        local records, headers = {}, {}
        local manual = false
        for _, record in ipairs(node.records) do
            if record.frame:GetParent() == node.parent then
                records[#records + 1] = record
                if record.widget.isHeader then
                    if record.widget.IsCollapsible() and not record.automatic then manual = true end
                end
            else
                if record.automatic then record.widget.SetCollapseHandler(nil) end
                byFrame[record.frame] = nil
            end
        end
        table.sort(records, function(a, b)
            if a.y == b.y then return a.serial < b.serial end
            return a.y < b.y
        end)
        for index, record in ipairs(records) do
            if record.widget.isHeader then headers[#headers + 1] = {record = record, index = index} end
        end
        node.records, node.manual, node.groups = records, manual, {}
        local height = node.parent:GetHeight()
        if node.layoutDirty or not node.appliedHeight or math.abs(height - node.appliedHeight) > 0.5 then
            node.baseHeight = height
        end
        node.layoutDirty = nil
        if manual then return end
        for index, header in ipairs(headers) do
            local record = header.record
            local first = records[header.index + 1]
            local nextHeader = headers[index + 1]
            local finish = nextHeader and nextHeader.record.y or node.baseHeight
            local title = node.parent == context.root and index == 1
            if not title and first and first.y < finish and first.y > record.y then
                node.groups[#node.groups + 1] = {record = record, start = first.y, finish = finish}
            end
        end
    end

    local function enableHeader(record, key, index)
        record.stateKey = key
        if saved[key] == nil then saved[key] = index > 1 end
        if record.automatic then return end
        record.automatic = true
        record.widget.SetCollapseHandler(function(value)
            saved[record.stateKey] = value
            context:Apply()
            if not context.batch and opts.onChanged then opts.onChanged() end
        end, function() return saved[record.stateKey] end)
    end

    local function setHidden(record, hidden)
        if hidden then
            if not record.hiddenBySection then record.wasShown = record.frame:IsShown() end
            record.hiddenBySection = true
            record.frame:Hide()
        elseif record.hiddenBySection then
            record.hiddenBySection = nil
            record.frame:SetShown(record.wasShown)
        end
    end

    local function applyNode(node)
        if node.manual or #node.records == 0 then return end
        local intervals, removals = {}, {}
        local removed = 0
        for _, group in ipairs(node.groups) do
            if group.record.widget.IsCollapsed() then
                intervals[#intervals + 1] = group
                local amount = group.finish - group.start
                removals[#removals + 1] = {after = group.finish, amount = amount}
                removed = removed + amount
            end
        end
        local function hiddenAt(y)
            for _, interval in ipairs(intervals) do
                if y >= interval.start and y < interval.finish then return true end
            end
            return false
        end
        local rows = {}
        for _, record in ipairs(node.records) do
            if not hiddenAt(record.y) then
                local row = rows[record.y] or {before = 0, after = 0}
                rows[record.y] = row
                row.before = math.max(row.before, record.height)
                row.after = math.max(row.after, record.frame:GetHeight())
            end
        end
        for y, row in pairs(rows) do
            local amount = math.max(0, row.before - row.after)
            if amount > 0 then
                removals[#removals + 1] = {after = y + row.before, amount = amount}
                removed = removed + amount
            end
        end
        for _, record in ipairs(node.records) do
            local offset = 0
            for _, removal in ipairs(removals) do
                if record.y >= removal.after then offset = offset + removal.amount end
            end
            local point = record.point
            if point[1] then
                record.frame:ClearAllPoints()
                record.frame:SetPoint(point[1], point[2], point[3], point[4], point[5] + offset)
            end
            setHidden(record, hiddenAt(record.y))
        end
        node.appliedHeight = math.max(1, node.baseHeight - removed)
        node.parent:SetHeight(node.appliedHeight)
    end

    function context:Apply()
        if not self.ready or self.released or self.applying or self.batch then return end
        self.applying = true
        for index = #nodeOrder, 1, -1 do
            local node = nodeOrder[index]
            local ancestor = node.parent
            while ancestor and ancestor ~= host do ancestor = ancestor:GetParent() end
            if not ancestor then
                for _, record in ipairs(node.records) do
                    if record.automatic then record.widget.SetCollapseHandler(nil) end
                    byFrame[record.frame] = nil
                end
                nodes[node.parent] = nil
                table.remove(nodeOrder, index)
            end
        end
        local headers = {}
        for _, node in ipairs(nodeOrder) do
            prepareNode(node)
            for _, group in ipairs(node.groups) do headers[#headers + 1] = group.record end
        end
        table.sort(headers, function(a, b) return a.serial < b.serial end)
        local keyCounts = {}
        for index, record in ipairs(headers) do
            local text = record.widget.GetText()
            keyCounts[text] = (keyCounts[text] or 0) + 1
            enableHeader(record, text .. ":" .. keyCounts[text], index)
        end
        table.sort(nodeOrder, function(a, b) return a.depth > b.depth end)
        for _, node in ipairs(nodeOrder) do applyNode(node) end
        self.handle.height = self.root:GetHeight()
        self.applying = nil
    end

    function context:HasSections()
        for _, node in ipairs(nodeOrder) do
            for _, record in ipairs(node.records) do
                if record.widget.isHeader and record.widget.IsCollapsible() then return true end
            end
        end
        return false
    end

    function context:SetAll(collapsed)
        self.batch = true
        for _, node in ipairs(nodeOrder) do
            for _, record in ipairs(node.records) do
                if record.widget.isHeader then record.widget.SetCollapsed(collapsed) end
            end
        end
        self.batch = nil
        self:Apply()
        if opts.onChanged then opts.onChanged() end
    end

    function context:Bind(handle)
        self.handle, self.root, self.ready = handle, handle.frame or host, true
        for _, method in ipairs({"Refresh", "_relayout", "SetHeight"}) do
            local original = handle[method]
            if original then
                handle[method] = function(...)
                    local result = original(...)
                    self:Apply()
                    if method == "Refresh" and opts.refreshLayout and opts.onChanged then opts.onChanged() end
                    return result
                end
            end
        end
        local release = handle.Release
        handle.Release = function(...)
            self.released = true
            if host.artSectionContext == self then host.artSectionContext = nil end
            for _, node in ipairs(nodeOrder) do
                for _, record in ipairs(node.records) do
                    if record.automatic then record.widget.SetCollapseHandler(nil) end
                end
            end
            wipe(nodes); wipe(nodeOrder); wipe(byFrame)
            if release then return release(...) end
        end
        self:Apply()
        return handle
    end

    return context
end
