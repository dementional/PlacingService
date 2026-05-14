local Types = {}

export type Object = BasePart | Model
export type ObjectInfo = {
	Preview: string, 
	CF: CFrame, 
	Scale: number,

	Location: Instance
}

type Rotations = {
	X: number,
	Y: number,
	Z: number
}

export type PlacingHandler = {
	Preview: Object?,

	IsModel: boolean,
	IsPlacing: boolean,
	CanPlace: boolean,

	CurrentScale: number,
	Rotations: Rotations,

	InitiatePreview: (object: Object) -> (),
	CancelPreview: () -> ()
}

export type Settings = {
	CanOverlapWithOtherParts: boolean,
	PreviewSB: Highlight,

	CanPlaceColor: Color3,
	CannotPlaceColor: Color3,

	GridUnit: number,
	ScaleUnit: number,
	RotationUnit: number,

	LerpSpeed: number,

	TimeBetweenRotations: number,
	TimeBetweenScaling: number,

	MaxScale: number,
	MinScale: number,

	LocationToPlacePreviews: Instance,
	LocationToPlaceObjects: Instance,
	ValidObjects: {Instance},

	PreferredInput: Enum.PreferredInput
}

return Types