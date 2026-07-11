---@class NRSKNUI
local NRSKNUI = select(2, ...)

local Mixin = Mixin
local CreateFrame = CreateFrame
local pairs = pairs
local table_insert = table.insert

---@class PublicBackdropMixin : Frame
---@field BackDropBorders table
local PublicBackdropMixin = {}

---Set the color of the background
---@param r number
---@param g number
---@param b number
---@param a? number
function PublicBackdropMixin:SetBackgroundColor(r, g, b, a)
	if self.backdropBackground then
		self.backdropBackground:SetColorTexture(r, g, b, a)
	end
end

---Set the color of the backdrops borders
---@param r number
---@param g number
---@param b number
---@param a? number
function PublicBackdropMixin:SetBorderColor(r, g, b, a)
	if self.BackDropBorders then
		for _, edge in pairs(self.BackDropBorders) do
			edge:SetColorTexture(r, g, b, a)
		end
	end
end

---Helper that can be used by ApplySettings function to update coloring with db values.
---@param db table
function PublicBackdropMixin:UpdateBackdropFromDB(db)
	if self.backdropBackground then
		self.backdropBackground:SetColorTexture(db.BackgroundColor[1], db.BackgroundColor[2], db.BackgroundColor[3], db.BackgroundColor[4])
	end
	if self.BackDropBorders then
		for _, edge in pairs(self.BackDropBorders) do
			edge:SetColorTexture(db.BorderColor[1], db.BorderColor[2], db.BorderColor[3], db.BorderColor[4])
		end
	end
end

---Hide or show the backdrop and borders. Used to toggle the backdrop on/off without destroying it.
---@param show boolean
function PublicBackdropMixin:ToggleBackdrop(show)
	if self.backdropBackground then
		if show then
			self.backdropBackground:Show()
		else
			self.backdropBackground:Hide()
		end
	end
	if self.BackDropBorders then
		for _, edge in pairs(self.BackDropBorders) do
			if show then
				edge:Show()
			else
				edge:Hide()
			end
		end
	end
end

local CreateTextureMixin = CreateFrame("Frame").CreateTexture

---@param frame Frame
function NRSKNUI:CreateBackdrop(frame)
	---@cast frame Frame & PublicBackdropMixin
	Mixin(frame, PublicBackdropMixin)

	frame.BackDropBorders = {}

	local BG = CreateTextureMixin(frame, nil, "BACKGROUND")
	BG:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	BG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.backdropBackground = BG
	NRSKNUI:PixelPerfect(BG)

	local LB = CreateTextureMixin(frame, nil, "BORDER")
	LB:SetPoint("TOPLEFT", frame, 1, -1)
	LB:SetPoint("BOTTOMLEFT", frame, 1, 1)
	table_insert(frame.BackDropBorders, LB)
	NRSKNUI:PixelPerfect(LB)

	local TB = CreateTextureMixin(frame, nil, "BORDER")
	TB:SetPoint("TOPLEFT", frame, 1, -1)
	TB:SetPoint("TOPRIGHT", frame, -1, -1)
	table_insert(frame.BackDropBorders, TB)
	NRSKNUI:PixelPerfect(TB)

	local RB = CreateTextureMixin(frame, nil, "BORDER")
	RB:SetPoint("TOPRIGHT", frame, -1, -1)
	RB:SetPoint("BOTTOMRIGHT", frame, -1, 1)
	table_insert(frame.BackDropBorders, RB)
	NRSKNUI:PixelPerfect(RB)

	local BB = CreateTextureMixin(frame, nil, "BORDER")
	BB:SetPoint("BOTTOMLEFT", frame, 1, 1)
	BB:SetPoint("BOTTOMRIGHT", frame, -1, 1)
	table_insert(frame.BackDropBorders, BB)
	NRSKNUI:PixelPerfect(BB)

	frame:SetBackgroundColor(0, 0, 0, 0.8)
	frame:SetBorderColor(0, 0, 0, 1)
end

---Check if we already added a backdrop to the frame
---@param frame Frame
---@return boolean
function NRSKNUI:BackdropExists(frame)
	return not not frame.BackDropBorders
end
