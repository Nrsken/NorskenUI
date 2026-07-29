---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Preview Utilities --

local PreviewManager = {
    guiOpen = false,
    anchorsActive = false,
    previewsActive = false,
}
NRSKNUI.PreviewManager = PreviewManager

function PreviewManager:UpdatePreviewState()
    local shouldShowPreviews = self.guiOpen or self.anchorsActive

    if shouldShowPreviews and not self.previewsActive then
        self:StartAllPreviews()
        self.previewsActive = true
    elseif not shouldShowPreviews and self.previewsActive then
        self:StopAllPreviews()
        self.previewsActive = false
    end
end

function PreviewManager:SetGUIOpen(open)
    self.guiOpen = open
    self:UpdatePreviewState()
end

function PreviewManager:SetAnchorsActive(active)
    self.anchorsActive = active
    self:UpdatePreviewState()
end

function PreviewManager:StartAllPreviews()
    if self._startingPreviews then return end
    self._startingPreviews = true
    for _, module in NRSKNUI:IterateModules() do
        if module.ShowPreview and module.db and module.db.Enabled then module:ShowPreview() end
    end
    self._startingPreviews = false
end

function PreviewManager:StopAllPreviews()
    for _, module in NRSKNUI:IterateModules() do
        if module.HidePreview then module:HidePreview() end
    end
end

function PreviewManager:IsPreviewActive()
    return self.previewsActive
end
