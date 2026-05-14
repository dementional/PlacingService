local freeThreads: { thread } = {}

local function RunCallback(Callback: (... any) -> (), thread: thread, ...: any)
	Callback(...)
	table.insert(freeThreads, thread)
end

local function Yielder()
	while true do
		RunCallback(coroutine.yield()) end
end

export type Connection<U...> = {
	Connected: boolean,

	Disconnect: (connection: Connection<U...>) -> (),
	Reconnect: (connection: Connection<U...>) -> ()
}

export type Signal<T...> = {
	RBXScriptConnection: RBXScriptConnection?,

	Connect: <U...>(signal: Signal<T...>, Func: (... any) -> (), U...) -> Connection<U...>,
	Once: <U...>(signal: Signal<T...>, Func: (... any) -> (), U...) -> Connection<U...>,
	Wait: (signal: Signal<T...>) -> T...,
	Fire: (signal: Signal<T...>, T...) -> (),
	DisconnectAll: (signal: Signal<T...>) -> (),
	Destroy: (signal: Signal<T...>) -> ()
}

local Connection = {}
Connection.__index = Connection

local function Disconnect<U...>(connection: Connection<U...>)
	if not connection.Connected then return end
	connection.Connected = false

	local next: Connection<U...>? = connection._Next
	local prev: Connection<U...>? = connection._Prev

	if next then next._Prev = prev end
	if prev then prev._Next = next end

	local signal: Signal<U...> = connection._Signal
	if signal._Head == connection then
		signal._Head = next end
end

local function Reconnect<U...>(connection: Connection<U...>)
	if connection.Connected then return end
	connection.Connected = true

	local signal: Signal<U...> = connection._Signal
	local head: Connection<U...>? = signal._Head
	
	if head then head._Prev = connection end
	signal._Head = connection

	connection._Next = head
	connection._Prev = false
end

Connection.Disconnect = Disconnect
Connection.Reconnect = Reconnect

local Signal = {}
Signal.__index = Signal

local RBXConnect: RBXScriptConnection, RBXDisconnect: RBXScriptConnection do
	if task then
		local bindable: BindableEvent = Instance.new("BindableEvent")
		
		RBXConnect = bindable.Event.Connect
		RBXDisconnect = bindable.Event:Connect(function() end).Disconnect
		
		bindable:Destroy()
	end
end

local function Connect<T..., U...>(signal: Signal<T...>, Func: (... any) -> (), ...: U...): Connection<U...>
	local head: Connection<U...>? = signal._Head
	local connection: Connection<U...> = setmetatable({
		Connected = true,
		_Signal = signal,
		_Func = Func,
		_VarArgs = if not ... then false else {...},
		_Next = head,
		_Prev = false,
	}, Connection)

	if head then head._Prev = connection end
	signal._Head = connection

	return connection
end

local function Once<T..., U...>(signal: Signal<T...>, Func: (... any) -> (), ...: U...): Connection<U...>
	local connection: Connection<U...>
	
	connection = Connect(signal, function(...: any)
		Disconnect(connection); Func(...)
	end, ...)
	
	return connection
end

local Wait: <T...>(signal: Signal<T...>) -> ... any = if task
	then function<T...>(signal: Signal<T...>): ... any
		local thread: thread = coroutine.running()
		local connection: Connection<T...>
		
		connection = Connect(signal, function(...: any)
			Disconnect(connection); task.spawn(thread, ...)
		end)
		
		return coroutine.yield()
	end
	
	else function<T...>(signal: Signal<T...>): ... any
		local thread: thread = coroutine.running()
		local connection: Connection<T...>
		
		connection = Connect(signal, function(...: any)
			Disconnect(connection)
			
			local passed: boolean, message: string = coroutine.resume(thread, ...)
			if not passed then error(message, 0) end
		end)
		
		return coroutine.yield()
	end

local Fire: <T...>(signal: Signal<T...>, ... any) -> () = if task
	then function<T...>(signal: Signal<T...>, ...: any)
		local connection: Connection<T...>? = signal._Head
		
		while connection do
			local thread: thread
			
			if #freeThreads > 0 then thread = freeThreads[#freeThreads]
				freeThreads[#freeThreads] = nil
			else thread = coroutine.create(Yielder)
				coroutine.resume(thread) end

			if not connection._VarArgs then task.spawn(thread, connection._Func, thread, ...)
			else
				local args: { any } = connection._VarArgs
				local len: number = #args
				local count: number = len
				
				for _, value: any in {...} do count += 1
					args[count] = value end
				
				task.spawn(thread, connection._Func, thread, table.unpack(args))

				for index: number = count, len + 1, -1 do 
					args[index] = nil end
			end

			connection = connection._Next
		end
	end

	else function<T...>(signal: Signal<T...>, ...: any)
		local connection: Connection<T...>? = signal._Head
		
		while connection do
			local thread: thread
			
			if #freeThreads > 0 then thread = freeThreads[#freeThreads]; freeThreads[#freeThreads] = nil
			else thread = coroutine.create(Yielder); coroutine.resume(thread) end

			if not connection._VarArgs then
				local passed: boolean, message = coroutine.resume(thread, connection._Func, thread, ...)
				if not passed then print(string.format("%s\nstacktrace:\n%s", message, debug.traceback())) end
			else
				local args: { any } = connection._VarArgs
				local len: number = #args
				local count: number = len
				
				for _, value: any in {...} do count += 1; args[count] = value end

				local passed: boolean, message: string = coroutine.resume(thread, connection._Func, thread, table.unpack(args))
				if not passed then print(string.format("%s\nstacktrace:\n%s", message, debug.traceback())) end

				for index: number = count, len + 1, -1 do args[index] = nil end
			end

			connection = connection._Next
		end
	end

	local function DisconnectAll<T...>(signal: Signal<T...>)
		local connection: Connection<T...>? = signal._Head
		
	while connection do Disconnect(connection); connection = connection._Next end
end
	
local function Destroy<T...>(signal: Signal<T...>)
	DisconnectAll(signal)

	local connection: RBXScriptConnection? = signal.RBXScriptConnection
	if connection then RBXDisconnect(connection)
		signal.RBXScriptConnection = nil end
end

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _Head = false }, Signal)
end

function Signal.Wrap<T...>(signal: RBXScriptSignal): Signal<T...>
	local wrapper: Signal<T...> = setmetatable({ _Head = false }, Signal)
		wrapper.RBXScriptConnection = RBXConnect(signal, function(...) 
			Fire(wrapper, ...) end)
		
	return wrapper
end

Signal.Connect = Connect
Signal.Once = Once
Signal.Wait = Wait
Signal.Fire = Fire
Signal.DisconnectAll = DisconnectAll
Signal.Destroy = Destroy

return {
	new = Signal.new, 
	Wrap = Signal.Wrap
}
