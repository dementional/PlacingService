local RepS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")

export type Trove = {
	Extend: (troveInternal: Trove) -> (Trove),
	Clone: <T>(troveInternal: Trove, instance: T & Instance) -> (T),
	Construct: <T, A...>(troveInternal: Trove, class: Constructable<T, A...>, A...) -> (T),
	Connect: (troveInternal: Trove, signal: SignalLike | RBXScriptSignal, Func: (... any) -> (... any), ... any?) -> (ConnectionLike),
	Once: (troveInternal: Trove, signal: SignalLike | RBXScriptSignal, Func: (... any) -> (... any), ... any?) -> (ConnectionLike),
	BindToRenderStep: (troveInternal: Trove, name: string, priority: number, Func: (deltaTime: number) -> ()) -> (),
	AddPromise: <T>(troveInternal: Trove, promise: T & PromiseLike) -> (T),
	Add: <T>(troveInternal: Trove, object: T & Trackable, cleanupMethod: string?) -> (T),
	Remove: <T>(troveInternal: Trove, object: T & Trackable) -> (boolean),
	Clean: (troveInternal: Trove) -> (),
	AttachToInstance: (troveInternal: Trove, instance: Instance) -> (RBXScriptConnection),
	Destroy: (troveInternal: Trove) -> ()
}

export type Trackable =
Instance
| RBXScriptConnection
| ConnectionLike
| PromiseLike
| thread
| ((... any) -> (... any))
| Destroyable
| Disconnectable
| { Trackable }

const FN_MARKER: any = newproxy()
const THREAD_MARKER: any = newproxy()
const TABLE_MARKER: any = newproxy()

const GENERIC_OBJECT_CLEANUP_METHODS: { string } = table.freeze({
	"Destroy",
	"Disconnect"
})

type TroveInternal = Trove & {
	_Objects: { any },
	_IsCleaning: boolean,
	_FindAndRemoveFromObjects: (troveInternal: TroveInternal, object: Trackable, cleanup: boolean) -> (boolean),
	_CleanupObject: (troveInternal: TroveInternal, object: Trackable, cleanupMethod: string?) -> (),
}

type ConnectionLike = {
	Connected: boolean,
	Disconnect: (connection: ConnectionLike) -> (),
}

type SignalLike = {
	Connect: (signal: SignalLike, Callback: (... any) -> (... any), ... any) -> ConnectionLike,
	Once: (signal: SignalLike, Callback: (... any) -> (... any), ... any) -> ConnectionLike,
}

type PromiseLike = {
	GetStatus: (promise: PromiseLike) -> string,
	Finally: (promise: PromiseLike, Callback: (... any) -> (... any)) -> PromiseLike,
	Cancel: (promise: PromiseLike) -> (),
}

type Constructable<T, A...> = { new: (A...) -> (T) } | (A...) -> (T)
type Destroyable = {
	Destroy: (troveInternal: Destroyable) -> (),
}

type Disconnectable = {
	Disconnect: (troveInternal: Disconnectable) -> (),
}

local Trove = {}
Trove.__index = Trove

local function GetObjectCleanupFunc(object: Trackable, cleanupMethod: string?): string
	local typeOf: string = typeof(object)

	if typeOf == "function" then return FN_MARKER
	elseif typeOf == "thread" then return THREAD_MARKER end

	if cleanupMethod then 
		return cleanupMethod end

	if typeOf == "Instance" then return "Destroy"
	elseif typeOf == "RBXScriptConnection" then return "Disconnect"
	elseif typeOf == "table" then
		for _, genericCleanupMethod: string in GENERIC_OBJECT_CLEANUP_METHODS do			
			if typeof(object[genericCleanupMethod]) == "function" then
				return genericCleanupMethod end
		end
		
		return TABLE_MARKER
	end

	error(`[{script.Name}]: Failed to get cleanup function for object {typeOf} - {object}`, 3)
end

local function AssertPromiseLike(object: Trackable)
	if typeof(object) ~= "table"
		or typeof(object.GetStatus) ~= "function"
		or typeof(object.Finally) ~= "function"
		or typeof(object.Cancel) ~= "function"
	then
		error(`[{script.Name}]: Did not receive a promise as an argument`, 3) end
end

function Trove.new(): Trove
	local trove: Trove = setmetatable({
		_Objects = {},
		_IsCleaning = false
	}, Trove)

	return trove
end

function Trove._FindAndRemoveFromObjects(troveInternal: TroveInternal, object: Trackable, cleanup: boolean): boolean
	local objects: { any } = troveInternal._Objects

	for index: number, otherObject: { any } in objects do
		if otherObject[1] ~= object then continue end

		local lastIndex: number = #objects
		objects[index] = objects[lastIndex]
		objects[lastIndex] = nil

		if cleanup then 
			troveInternal:_CleanupObject(otherObject[1], otherObject[2]) end

		return true
	end

	return false
end

function Trove._CleanupObject(troveInternal: TroveInternal, object: Trackable, cleanupMethod: string?)
	if cleanupMethod == FN_MARKER then task.spawn(object)
	elseif cleanupMethod == THREAD_MARKER then pcall(task.cancel, object)
	elseif cleanupMethod == TABLE_MARKER then
		for _, subObject: Trackable in object do
			local subCleanup: string = GetObjectCleanupFunc(subObject)
			troveInternal:_CleanupObject(subObject, subCleanup)
		end
		
		table.clear(object)
	else object[cleanupMethod](object) end
end

function Trove.Add(troveInternal: TroveInternal, object: Trackable, cleanupMethod: string?): any
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Add() while cleaning`, 2) end

	local cleanup: string = GetObjectCleanupFunc(object, cleanupMethod)
	table.insert(troveInternal._Objects, { object, cleanup })

	return object
end

function Trove.Clone(troveInternal: TroveInternal, instance: Instance): Instance
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Clone() while cleaning`, 2) end

	return troveInternal:Add(instance:Clone())
end

function Trove.Construct<T, A...>(troveInternal: TroveInternal, Class: Constructable<T, A...>, ...: A...): T
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Construct() while cleaning`, 2) end

	local object: Trackable = nil
	local typeOf: string = type(Class)

	if typeOf == "table" then object = Class.new(...)
	elseif typeOf == "function" then object = Class(...) end

	return troveInternal:Add(object)
end

function Trove.Connect(troveInternal: TroveInternal, signal: SignalLike, Func: (... any) -> (... any), ...: any?): Disconnectable
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Connect() while cleaning`, 2) end

	local args: { any } = { ... }
	local Callback: (... any) -> () = if #args > 0 then
		function(...: any)
			Func(table.unpack(args), ...) end
		else Func

	return troveInternal:Add(signal:Connect(Callback))
end

function Trove.Once(troveInternal: TroveInternal, signal: SignalLike, Func: (... any) -> (... any), ...: any?): Disconnectable
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Once() while cleaning`, 2) end

	local args: { any } = { ... }
	local Callback: (... any) -> () = if #args > 0 then
		function(...: any)
			Func(table.unpack(args), ...) end
		else Func

	return troveInternal:Add(signal:Once(Callback))
end

function Trove.BindToRenderStep(troveInternal: TroveInternal, name: string, priority: number, Func: (deltaTime: number) -> ())
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:BindToRenderStep() while cleaning`, 2) end

	RunS:BindToRenderStep(name, priority, Func)
	troveInternal:Add(function() 
		RunS:UnbindFromRenderStep(name) end)
end

function Trove.AddPromise(troveInternal: TroveInternal, promise: PromiseLike): PromiseLike
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:AddPromise() while cleaning`, 2) end
	AssertPromiseLike(promise)

	if promise:GetStatus() == "Started" then
		promise:Finally(function() if troveInternal._IsCleaning then return end
			troveInternal:_FindAndRemoveFromObjects(promise, false) end)

		troveInternal:Add(promise, "Cancel")
	end

	return promise
end

function Trove.Remove(troveInternal: TroveInternal, object: Trackable): boolean
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Remove() while cleaning`, 2) end

	return troveInternal:_FindAndRemoveFromObjects(object, true)
end

function Trove.Extend(troveInternal: TroveInternal): Trove
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:Extend() while cleaning`, 2) end

	return troveInternal:Construct(Trove)
end

function Trove.Clean(troveInternal: TroveInternal)
	if troveInternal._IsCleaning then return end

	troveInternal._IsCleaning = true

	for _, object: { any } in troveInternal._Objects do 
		troveInternal:_CleanupObject(object[1], object[2]) end
	
	table.clear(troveInternal._Objects)
	troveInternal._IsCleaning = false
end

function Trove.WrapClean(troveInternal: TroveInternal): () -> ()
	return function()
		troveInternal:Clean() end
end

function Trove.AttachToInstance(troveInternal: TroveInternal, instance: Instance): Disconnectable
	if troveInternal._IsCleaning then
		error(`[{script.Name}]: Cannot call trove:AttachToInstance() while cleaning`, 2)
	elseif not instance:IsDescendantOf(game) then
		error(`[{script.Name}]: Instance is not a descendant of the game hierarchy`, 2) end

	return troveInternal:Connect(instance.Destroying, troveInternal.Destroy, troveInternal)
end

function Trove.Destroy(troveInternal: TroveInternal)
	troveInternal:Clean()
end

return {
	new = Trove.new
}